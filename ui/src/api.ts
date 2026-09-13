export type RunStatus = "running" | "stopped" | "pending" | "crashed" | "error" | "idle" | "unknown";

export interface ServiceInfo {
  name: string;
  script: string;
  stop_script?: string;
  status_script?: string;
  logs_script?: string;
  args?: string[];
  desired_state: "running" | "stopped";
  status: RunStatus;
  last_action?: string;
  last_run_at?: string;
  fail_count?: number;
  next_retry_at?: string | null;
}

export interface JobInfo {
  name: string;
  script: string;
  schedule: string;
  status?: RunStatus;
  last_action?: string;
  last_run_at?: string;
  next_run_at?: string | null;
}

export interface OutputInfo {
  exit_code: number;
  output: string;
}

async function req<T>(path: string, options?: RequestInit): Promise<T> {
  const res = await fetch(`/api${path}`, options);
  if (!res.ok) throw new Error(`${res.status} ${res.statusText}`);
  return res.json();
}

export const api = {
  services: () => req<ServiceInfo[]>("/services"),
  jobs: () => req<JobInfo[]>("/jobs"),
  output: (name: string, lines = 200) =>
    req<OutputInfo>(`/output/${encodeURIComponent(name)}?lines=${lines}`),
  startService: (name: string) =>
    req(`/services/${encodeURIComponent(name)}/start`, { method: "POST" }),
  stopService: (name: string) =>
    req(`/services/${encodeURIComponent(name)}/stop`, { method: "POST" }),
  restartService: (name: string) =>
    req(`/services/${encodeURIComponent(name)}/restart`, { method: "POST" }),
  setAutostart: (name: string, enabled: boolean) =>
    req(`/services/${encodeURIComponent(name)}/autostart?enabled=${enabled}`, { method: "POST" }),
  runJob: (name: string) => req(`/jobs/${encodeURIComponent(name)}/run`, { method: "POST" }),
};
