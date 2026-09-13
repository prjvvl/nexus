/** @type {import('tailwindcss').Config} */
export default {
  content: ["./index.html", "./src/**/*.{ts,tsx}"],
  theme: {
    extend: {
      colors: {
        base: {
          950: "#0a0c10",
          900: "#12151b",
          800: "#1a1e26",
          700: "#252a34",
          600: "#343b48",
        },
        accent: {
          500: "#6366f1",
          400: "#818cf8",
        },
      },
    },
  },
  plugins: [],
};
