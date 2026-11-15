/**
 * Palette/fonts mirror the docs site's tokens (site/src/styles/global.css's
 * @theme block) so the dashboard and the public site read as one product
 * instead of two differently-themed apps. Keep these in sync if the site's
 * tokens change - there's no shared source between a Tailwind v3 JS config
 * (here) and the site's Tailwind v4 CSS-first @theme.
 */
/** @type {import('tailwindcss').Config} */
export default {
  content: ["./index.html", "./src/**/*.{ts,tsx}"],
  theme: {
    extend: {
      colors: {
        base: {
          950: "hsl(222 47% 6%)",
          900: "hsl(222 40% 10%)",
          800: "hsl(222 35% 15%)",
          700: "hsl(222 30% 18%)",
          600: "hsl(222 25% 28%)",
        },
        brand: {
          50: "hsl(235 85% 96%)",
          100: "hsl(235 85% 91%)",
          200: "hsl(235 80% 83%)",
          300: "hsl(235 78% 72%)",
          400: "hsl(235 75% 62%)",
          500: "hsl(235 72% 54%)",
          600: "hsl(235 70% 46%)",
          700: "hsl(235 68% 38%)",
          800: "hsl(236 65% 30%)",
          900: "hsl(236 60% 22%)",
        },
        success: "hsl(152 55% 55%)",
        warning: "hsl(38 85% 60%)",
        error: "hsl(0 70% 65%)",
      },
      fontFamily: {
        sans: ["Inter Variable", "ui-sans-serif", "system-ui", "sans-serif"],
        display: ["Space Grotesk Variable", "Inter Variable", "ui-sans-serif", "sans-serif"],
      },
    },
  },
  plugins: [],
};
