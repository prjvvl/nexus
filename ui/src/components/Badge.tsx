import type { RunStatus } from "../api";

const STYLES: Record<RunStatus, string> = {
  running: "bg-emerald-500/15 text-emerald-400 ring-emerald-500/30",
  idle: "bg-emerald-500/15 text-emerald-400 ring-emerald-500/30",
  stopped: "bg-slate-500/15 text-slate-400 ring-slate-500/30",
  pending: "bg-amber-500/15 text-amber-400 ring-amber-500/30",
  crashed: "bg-amber-500/15 text-amber-400 ring-amber-500/30",
  error: "bg-rose-500/15 text-rose-400 ring-rose-500/30",
  unknown: "bg-slate-500/15 text-slate-400 ring-slate-500/30",
};

export default function Badge({ status }: { status: RunStatus }) {
  return (
    <span
      className={`inline-flex items-center gap-2 rounded-full px-3 py-1 text-xs font-medium ring-1 ring-inset ${STYLES[status] ?? STYLES.unknown}`}
    >
      <span className="h-1.5 w-1.5 rounded-full bg-current" />
      {status}
    </span>
  );
}
