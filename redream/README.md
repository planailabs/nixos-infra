# redream

[redream](https://git.plan.ai/plan-ai/redream): web console for the Dell iDRACs
(power, KVM over VNC, Ctrl-Alt-Del), behind Google login restricted to plan.ai.

- **Hostname:** `redream` (LXC container on atlas)
- **Address:** `2a01:4f9:1a:90eb::a:d4ea` (incus `eth0` `ipv6.address` override), AAAA `redream.plan.ai`
- **Base:** modelled on `logos` (common + container modules, yggdrasil, nginx + ACME from `acme.plan.ai`)

## iDRAC network

The iDRACs (10.88.0.112 main, 10.88.0.113 build) are only reachable through the
MikroTik at `router.oliver-koss.at`. The container dials it over WireGuard
(`idrac0`, 10.89.0.4) as peer `redream` on the router's `vpn0`. The private key
is in `private/redream.nix`; the public key is noted there too.

## Secrets (`private/redream.nix`)

`/etc/redream.env`: `IDRAC_PASSWORD`, `COOKIE_SECRET`, `GOOGLE_CLIENT_ID`,
`GOOGLE_CLIENT_SECRET`. The Google client is a placeholder until a real one is
created with the redirect URI `https://redream.plan.ai/auth/google/callback`.

## Deploy

First install: `./incus-image.sh redream root@atlas.plan.ai`, then
`incus config device override redream eth0 ipv6.address=2a01:4f9:1a:90eb::a:d4ea`
and `incus start redream`. Afterwards: `./redream.sh`.
