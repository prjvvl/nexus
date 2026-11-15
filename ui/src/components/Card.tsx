import type { ReactNode } from "react";

export default function Card({
  title,
  icon,
  children,
}: {
  title: string;
  icon?: ReactNode;
  children: ReactNode;
}) {
  return (
    <div className="rounded-xl border border-base-700 bg-base-900">
      <div className="flex items-center gap-2 border-b border-base-700 px-4 py-4">
        <h2 className="font-display flex items-center gap-2 text-sm font-semibold tracking-wide text-slate-300">
          {icon}
          {title}
        </h2>
      </div>
      <div className="p-4">{children}</div>
    </div>
  );
}
