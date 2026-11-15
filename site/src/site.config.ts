/**
 * Single source of truth for site metadata and navigation.
 * Brand colors and fonts live in src/styles/global.css (the @theme block).
 * Tailwind v4's config is CSS-first, so tokens stay there, not here.
 */
export const siteConfig = {
  name: "Nexus",
  description: "A manifest-driven service and job orchestrator for your own machine.",

  /** Set this to a custom domain (e.g. "example.com") to enable one; it is
   *  written to dist/CNAME on every build. Empty: served at `url`. */
  domain: "",

  url: "https://prjvvl.github.io/nexus",

  repo: "https://github.com/prjvvl/nexus",

  social: {
    github: "https://github.com/prjvvl/nexus",
  },

  /** Header links. `icon` names an entry in src/lib/icons.ts; `match` lists
   *  the route prefixes that mark the item as the current section. */
  nav: [
    { label: "Install", href: "/install/", icon: "install", match: ["/install/"] },
    { label: "Get started", href: "/getting-started/", icon: "start", match: ["/getting-started/"] },
    {
      label: "Guides",
      href: "/guides/dashboard/",
      icon: "guides",
      match: ["/guides/", "/deploy/", "/troubleshooting/"],
    },
    {
      label: "Reference",
      href: "/reference/manifest/",
      icon: "reference",
      match: ["/reference/", "/concepts/", "/security/"],
    },
  ],

  /** The docs sidebar. Pages are files in the repository's docs/ directory,
   *  addressed by their path without `.md`. */
  sidebar: [
    { group: "Start here", icon: "start", pages: ["install", "getting-started"] },
    {
      group: "How-to guides",
      icon: "guides",
      pages: ["guides/dashboard", "guides/scripts", "deploy", "troubleshooting"],
    },
    { group: "Reference", icon: "reference", pages: ["reference/manifest", "reference/api"] },
    { group: "Explanation", icon: "explanation", pages: ["concepts", "security"] },
  ],
} as const;
