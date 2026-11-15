# Nexus

A manifest-driven service and job orchestrator for your own machine.

Nexus runs as one systemd-managed process. It reads `manifest.yaml`, starts
and stops your services and scheduled jobs through plain bash scripts,
restarts anything that crashes (with backoff), and gives you a dashboard and
a REST API to watch and control all of it.

- [Install](install.md)
- [Getting started](getting-started.md)
- [Concepts](concepts.md)
- [Guides](guides/dashboard.md)
- [Reference](reference/manifest.md)
- [Security](security.md)
