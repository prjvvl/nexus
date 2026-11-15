import StableText from "./StableText";

export default function Toggle({
  checked,
  onChange,
  disabled,
  label,
}: {
  checked: boolean;
  onChange: (next: boolean) => void;
  disabled?: boolean;
  label: string;
}) {
  return (
    <button
      type="button"
      role="switch"
      aria-checked={checked}
      aria-label={label}
      disabled={disabled}
      onClick={() => onChange(!checked)}
      className="group flex items-center gap-3 disabled:cursor-not-allowed disabled:opacity-50"
    >
      <span
        className={`relative h-5 w-9 rounded-full transition-colors ${
          checked ? "bg-brand-600" : "bg-base-600"
        }`}
      >
        <span
          className={`absolute top-0.5 h-4 w-4 rounded-full bg-white transition-[left] ${
            checked ? "left-[18px]" : "left-0.5"
          }`}
        />
      </span>
      <StableText
        variants={["Autostart on", "Autostart off"]}
        active={checked ? "Autostart on" : "Autostart off"}
        className="text-xs text-slate-400 group-hover:text-slate-300"
      />
    </button>
  );
}
