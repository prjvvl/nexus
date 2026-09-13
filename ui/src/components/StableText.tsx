/**
 * Renders `active` but reserves box space for the widest of `variants`,
 * so swapping between them (e.g. "Logs" / "Hide logs") never resizes
 * the containing button/label.
 */
export default function StableText({
  variants,
  active,
  className,
}: {
  variants: string[];
  active: string;
  className?: string;
}) {
  const options = Array.from(new Set([...variants, active]));
  return (
    <span className={`inline-grid place-items-center ${className ?? ""}`}>
      {options.map((v) => (
        <span key={v} className={`col-start-1 row-start-1 ${v === active ? "" : "invisible"}`}>
          {v}
        </span>
      ))}
    </span>
  );
}
