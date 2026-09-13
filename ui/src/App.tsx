import {
  AlertTriangle,
  Boxes,
  CalendarClock,
  Layers,
  Play,
  PlayCircle,
  RotateCw,
  ScrollText,
  Square,
  Waypoints,
  X,
} from "lucide-react";
import { useEffect, useState } from "react";
import { api, type JobInfo, type ServiceInfo } from "./api";
import Badge from "./components/Badge";
import Card from "./components/Card";
import LogsPanel from "./components/LogsPanel";
import StableText from "./components/StableText";
import Toggle from "./components/Toggle";

const POLL_MS = 5000;

const BUTTON =
  "flex items-center gap-2 rounded bg-base-700 px-3 py-2 text-xs font-medium text-slate-300 transition hover:bg-base-600 disabled:opacity-50 disabled:cursor-not-allowed";

function timeAgo(iso?: string): string {
  if (!iso) return "never";
  const diff = Date.now() - new Date(iso).getTime();
  const mins = Math.round(diff / 60000);
  if (mins < 1) return "just now";
  if (mins < 60) return `${mins}m ago`;
  const hrs = Math.round(mins / 60);
  if (hrs < 24) return `${hrs}h ago`;
  return `${Math.round(hrs / 24)}d ago`;
}

export default function App() {
  const [services, setServices] = useState<ServiceInfo[]>([]);
  const [jobs, setJobs] = useState<JobInfo[]>([]);
  const [busy, setBusy] = useState<Record<string, boolean>>({});
  const [logsOpen, setLogsOpen] = useState<Record<string, boolean>>({});
  const [error, setError] = useState<string | null>(null);
  const [actionError, setActionError] = useState<string | null>(null);

  async function refresh() {
    try {
      const [svc, jb] = await Promise.all([api.services(), api.jobs()]);
      setServices(svc);
      setJobs(jb);
      setError(null);
    } catch (e) {
      setError((e as Error).message ?? "failed to reach Nexus");
    }
  }

  useEffect(() => {
    refresh();
    const id = setInterval(refresh, POLL_MS);
    return () => clearInterval(id);
  }, []);

  async function runAction(key: string, action: () => Promise<unknown>) {
    setBusy((b) => ({ ...b, [key]: true }));
    setActionError(null);
    try {
      await action();
      await refresh();
    } catch (e) {
      setActionError((e as Error).message ?? "action failed");
    } finally {
      setBusy((b) => ({ ...b, [key]: false }));
    }
  }

  function toggleService(s: ServiceInfo) {
    return runAction(s.name, () =>
      s.status === "running" ? api.stopService(s.name) : api.startService(s.name)
    );
  }

  function restartService(s: ServiceInfo) {
    return runAction(s.name, () => api.restartService(s.name));
  }

  function setAutostart(s: ServiceInfo, enabled: boolean) {
    return runAction(`${s.name}:autostart`, () => api.setAutostart(s.name, enabled));
  }

  function runJobNow(j: JobInfo) {
    return runAction(j.name, () => api.runJob(j.name));
  }

  const runningCount = services.filter((s) => s.status === "running").length;
  const errorCount = [...services, ...jobs].filter((s) => s.status === "error").length;

  return (
    <div className="mx-auto max-w-5xl px-6 py-8">
      <header className="mb-8 flex flex-wrap items-center justify-between gap-3">
        <div className="flex items-center gap-3">
          <div className="flex h-10 w-10 items-center justify-center rounded-lg bg-accent-500/15 text-accent-400">
            <Waypoints className="h-5 w-5" aria-hidden="true" />
          </div>
          <div>
            <h1 className="text-2xl font-bold tracking-tight text-white">Nexus</h1>
            <p className="text-sm text-slate-400">Service orchestration dashboard</p>
          </div>
        </div>
        {(error || actionError) && (
          <div
            role="alert"
            className="flex items-center gap-2 rounded bg-rose-500/15 px-3 py-2 text-xs text-rose-400 ring-1 ring-rose-500/30"
          >
            <AlertTriangle className="h-3.5 w-3.5" aria-hidden="true" />
            <span>{error ?? actionError}</span>
            <button
              onClick={() => {
                setError(null);
                setActionError(null);
              }}
              aria-label="Dismiss"
              className="text-rose-400 hover:text-rose-300"
            >
              <X className="h-3.5 w-3.5" aria-hidden="true" />
            </button>
          </div>
        )}
      </header>

      <main>
        <div className="mb-6 grid grid-cols-1 gap-4 sm:grid-cols-3">
          <SummaryTile icon={<Boxes className="h-4 w-4" aria-hidden="true" />} label="Services" value={services.length} />
          <SummaryTile
            icon={<PlayCircle className="h-4 w-4" aria-hidden="true" />}
            label="Running"
            value={runningCount}
            tone="good"
          />
          <SummaryTile
            icon={<AlertTriangle className="h-4 w-4" aria-hidden="true" />}
            label="Errors"
            value={errorCount}
            tone={errorCount > 0 ? "bad" : undefined}
          />
        </div>

        <div className="space-y-6">
          <Card title="Services" icon={<Layers className="h-4 w-4" aria-hidden="true" />}>
            <div className="space-y-3">
              {services.length === 0 && (
                <p className="text-sm text-slate-400">
                  No services defined yet — add one to manifest.yaml and restart Nexus.
                </p>
              )}
              {services.map((s) => (
                <div key={s.name} className="rounded-lg border border-base-700 bg-base-800/60 p-4">
                  <div className="flex flex-wrap items-center justify-between gap-3">
                    <div className="flex items-center gap-3">
                      <span className="font-medium text-slate-200">{s.name}</span>
                      <Badge status={s.status} />
                    </div>
                    <div className="flex flex-wrap items-center gap-3">
                      <Toggle
                        checked={s.desired_state === "running"}
                        onChange={(next) => setAutostart(s, next)}
                        disabled={busy[`${s.name}:autostart`]}
                        label={`Autostart for ${s.name}`}
                      />
                      <span className="text-xs text-slate-400">last run {timeAgo(s.last_run_at)}</span>
                      {s.logs_script && (
                        <button
                          onClick={() => setLogsOpen((o) => ({ ...o, [s.name]: !o[s.name] }))}
                          className={BUTTON}
                        >
                          <ScrollText className="h-3.5 w-3.5" aria-hidden="true" />
                          <StableText
                            variants={["Logs", "Hide logs"]}
                            active={logsOpen[s.name] ? "Hide logs" : "Logs"}
                          />
                        </button>
                      )}
                      <button
                        onClick={() => restartService(s)}
                        disabled={busy[s.name] || !s.stop_script}
                        title={s.stop_script ? undefined : "no stop_script configured"}
                        className={BUTTON}
                      >
                        <RotateCw className="h-3.5 w-3.5" aria-hidden="true" />
                        Restart
                      </button>
                      <button
                        onClick={() => toggleService(s)}
                        disabled={busy[s.name] || (s.status === "running" && !s.stop_script)}
                        title={
                          s.status === "running" && !s.stop_script
                            ? "no stop_script configured"
                            : undefined
                        }
                        className={`flex items-center gap-2 rounded px-3 py-2 text-xs font-medium transition disabled:cursor-not-allowed disabled:opacity-50 ${
                          s.status === "running"
                            ? "bg-rose-500/15 text-rose-400 hover:bg-rose-500/25"
                            : "bg-accent-500/15 text-accent-400 hover:bg-accent-500/25"
                        }`}
                      >
                        {s.status === "running" ? (
                          <Square className="h-3.5 w-3.5" aria-hidden="true" />
                        ) : (
                          <Play className="h-3.5 w-3.5" aria-hidden="true" />
                        )}
                        <StableText
                          variants={["Start", "Stop", "…"]}
                          active={busy[s.name] ? "…" : s.status === "running" ? "Stop" : "Start"}
                        />
                      </button>
                    </div>
                  </div>
                  {!!s.fail_count && (
                    <p className="mt-2 text-xs text-amber-400">
                      {s.fail_count} failed restart{s.fail_count === 1 ? "" : "s"}
                      {s.next_retry_at &&
                        ` · retrying around ${new Date(s.next_retry_at).toLocaleTimeString()}`}
                    </p>
                  )}
                  {logsOpen[s.name] && <LogsPanel name={s.name} />}
                </div>
              ))}
            </div>
          </Card>

          <Card title="Scheduled jobs" icon={<CalendarClock className="h-4 w-4" aria-hidden="true" />}>
            <div className="space-y-3">
              {jobs.length === 0 && (
                <p className="text-sm text-slate-400">
                  No jobs defined yet — add one to manifest.yaml and restart Nexus.
                </p>
              )}
              {jobs.map((j) => (
                <div
                  key={j.name}
                  className="flex flex-wrap items-center justify-between gap-3 rounded-lg border border-base-700 bg-base-800/60 p-4"
                >
                  <div>
                    <div className="flex items-center gap-3">
                      <span className="font-medium text-slate-200">{j.name}</span>
                      <code className="rounded bg-base-700 px-2 py-1 text-xs text-slate-400">
                        {j.schedule}
                      </code>
                    </div>
                    <p className="mt-1 text-xs text-slate-400">
                      last run {timeAgo(j.last_run_at)} · next run{" "}
                      {j.next_run_at ? new Date(j.next_run_at).toLocaleString() : "n/a"}
                    </p>
                  </div>
                  <div className="flex flex-wrap items-center gap-3">
                    {j.status && <Badge status={j.status} />}
                    <button onClick={() => runJobNow(j)} disabled={busy[j.name]} className={BUTTON}>
                      <Play className="h-3.5 w-3.5" aria-hidden="true" />
                      <StableText variants={["Run now", "…"]} active={busy[j.name] ? "…" : "Run now"} />
                    </button>
                  </div>
                </div>
              ))}
            </div>
          </Card>
        </div>
      </main>
    </div>
  );
}

function SummaryTile({
  icon,
  label,
  value,
  tone,
}: {
  icon: React.ReactNode;
  label: string;
  value: number;
  tone?: "good" | "bad";
}) {
  const toneClass =
    tone === "good" ? "text-emerald-400" : tone === "bad" ? "text-rose-400" : "text-white";
  return (
    <div className="rounded-xl border border-base-700 bg-base-900 px-4 py-4">
      <p className="flex items-center gap-2 text-xs uppercase tracking-wide text-slate-400">
        {icon}
        {label}
      </p>
      <p className={`mt-1 text-2xl font-semibold ${toneClass}`}>{value}</p>
    </div>
  );
}
