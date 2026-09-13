import { RefreshCw, ScrollText } from "lucide-react";
import { useEffect, useState } from "react";
import { api } from "../api";
import StableText from "./StableText";

export default function LogsPanel({ name }: { name: string }) {
  const [output, setOutput] = useState<string | null>(null);
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState<string | null>(null);

  async function load() {
    setLoading(true);
    setError(null);
    try {
      const res = await api.output(name);
      setOutput(res.output || "(no output)");
    } catch (e) {
      setError((e as Error).message ?? "failed to fetch logs");
    } finally {
      setLoading(false);
    }
  }

  useEffect(() => {
    load();
  }, [name]);

  return (
    <div className="mt-3 rounded-lg border border-base-700 bg-base-950">
      <div className="flex items-center justify-between border-b border-base-700 px-3 py-2">
        <span className="flex items-center gap-2 text-xs font-medium text-slate-400">
          <ScrollText className="h-3.5 w-3.5" aria-hidden="true" />
          Logs
        </span>
        <button
          onClick={load}
          disabled={loading}
          className="flex items-center gap-2 rounded bg-base-700 px-2 py-1 text-xs text-slate-300 hover:bg-base-600 disabled:cursor-not-allowed disabled:opacity-50"
        >
          <RefreshCw className={`h-3 w-3 ${loading ? "animate-spin" : ""}`} aria-hidden="true" />
          <StableText variants={["Refresh", "…"]} active={loading ? "…" : "Refresh"} />
        </button>
      </div>
      <pre className="max-h-64 overflow-auto whitespace-pre-wrap px-3 py-2 text-xs text-slate-400">
        {error ? `error: ${error}` : output ?? "loading…"}
      </pre>
    </div>
  );
}
