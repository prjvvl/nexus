# Security

Nexus has no authentication and no access control. This is a deliberate,
documented tradeoff for a single-user tool on a trusted LAN — not an
oversight — but it means you need to know exactly what it implies.

## What's actually exposed

The API (`nexus/api.py`) listens on `0.0.0.0:8787` — every interface, not
just loopback — with CORS wide open (`allow_origins=["*"]`). Anyone who can
reach that port can, with no login:

- Start, stop, or restart any service.
- Toggle any service's autostart (a persistent `manifest.yaml` edit).
- Run any scheduled job on demand.
- Read the tail of any service's logs or recent run output.

There's no read-only mode and no per-service scoping — one level of access,
for everyone who can reach the port.

## When this is fine

On a home LAN behind a router doing NAT, with no port forwarded, this is
reasonably low-risk: reaching port 8787 already requires being on the same
network as a trusted set of devices.

## When it isn't

- The host ever gets a public IP, or 8787 gets port-forwarded.
- The LAN has untrusted devices on it (guest wifi, IoT devices, anyone
  else's laptop).
- A service Nexus manages matters enough that an unauthenticated stop/start
  is a real incident, not an inconvenience.

In any of those cases, don't expose 8787 beyond `127.0.0.1` without putting
something in front of it — an SSH tunnel, a reverse proxy with its own
auth, or a VPN (Tailscale, WireGuard) — until Nexus has its own auth.

## Not security issues, just worth knowing

- `manifest.yaml` and `state.db` are plain files on disk, readable by
  whatever user Nexus runs as — don't put secrets directly in `args`.
- Nexus runs scripts as its own systemd unit's user. A script you point it
  at runs with that user's full permissions — Nexus adds no sandboxing.
