import type { RunStatus } from "../api";

const STYLES: Record<RunStatus, string> = {
  running: "bg-success/15 text-success ring-success/30",
  idle: "bg-success/15 text-success ring-success/30",
  stopped: "bg-slate-500/15 text-slate-400 ring-slate-500/30",
  pending: "bg-warning/15 text-warning ring-warning/30",
  crashed: "bg-warning/15 text-warning ring-warning/30",
  error: "bg-error/15 text-error ring-error/30",
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
