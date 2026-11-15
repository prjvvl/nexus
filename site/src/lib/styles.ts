/**
 * Shared Tailwind class strings for patterns that need to look identical in
 * both Astro components and React islands - importing these avoids
 * copy-pasting a class string a second time, where the two copies can
 * silently drift apart.
 */
const buttonBaseClass =
  "hover-elevate inline-flex min-h-11 items-center justify-center gap-2 rounded-card px-5 py-2.5 text-sm font-medium";

export const buttonVariantClass = {
  primary: `${buttonBaseClass} bg-brand text-brand-fg hover:bg-brand-700`,
  secondary: `${buttonBaseClass} border border-border text-fg hover:border-brand-300 hover:bg-surface`,
} as const;
