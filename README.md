# Nexus

A manifest-driven service and job orchestrator for your own machine.

Nexus runs as one systemd-managed process. It reads `manifest.yaml`, starts
and stops your services and scheduled jobs through plain bash scripts,
restarts anything that crashes (with backoff), and gives you a dashboard
and a REST API to watch and control all of it.

Status: in daily use on one machine. There's no packaged binary — it
installs from source (and builds its own dashboard) every time.

## Install

```sh
curl -fsSL https://raw.githubusercontent.com/prjvvl/nexus/main/install.sh | sh
```

or clone it first:

```sh
git clone https://github.com/prjvvl/nexus.git && cd nexus && ./install.sh
```

See [docs/install.md](docs/install.md) for requirements, upgrading, and
uninstalling.

## Docs

- [Getting started](docs/getting-started.md)
- [Concepts](docs/concepts.md)
- [Manifest reference](docs/reference/manifest.md)
- [API reference](docs/reference/api.md)
- [Scripts](docs/guides/scripts.md) · [Dashboard](docs/guides/dashboard.md)
- [Deploy](docs/deploy.md) · [Security](docs/security.md) · [Troubleshooting](docs/troubleshooting.md)

A built docs site (`site/`, an Astro app reading the same `docs/` files) is
in the repo but not deployed yet — run it locally with
`cd site && npm install && npm run dev`.
