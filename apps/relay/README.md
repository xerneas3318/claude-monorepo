# ClaudePlanner Relay

A small Fastify HTTPS service you run on your Hetzner box. The iOS app
authenticates with Firebase, then calls this relay; the relay verifies the
Firebase ID token, calls Anthropic's API with tool use, and executes tools
against Firestore on your behalf. Your Anthropic key lives only on the server.

```
iPhone ── POST /talk (bearer Firebase ID token) ──► Hetzner relay (port 8787)
                                                          │
                                                          ├── verifies token (Firebase Admin SDK)
                                                          ├── calls api.anthropic.com (tool-use loop)
                                                          └── reads/writes Firestore for the user
```

## Local sanity check (on your laptop, before deploying)

```sh
cd relay
npm install
cp .env.example .env       # fill in ANTHROPIC_API_KEY and a path to service-account.json
export $(grep -v '^#' .env | xargs)
node src/index.js
# then in another shell:
curl http://127.0.0.1:8787/healthz
```

The `/talk` endpoint requires a real Firebase ID token in the Authorization
header, so easiest end-to-end test is from the iOS app.

## Deploy to Hetzner (Ubuntu/Debian + systemd + Caddy for TLS)

Assumes a fresh Hetzner Cloud VM and a domain like `relay.yourname.com`
pointed at the box's public IP via your DNS provider.

### 1. Install Node 20 and Caddy

```sh
ssh root@<your-hetzner-ip>
apt update && apt install -y curl
curl -fsSL https://deb.nodesource.com/setup_20.x | bash -
apt install -y nodejs caddy
```

### 2. Drop the code on the box

Easiest: `git clone` the ClaudePlanner repo to `/opt/claudeplanner`, then
`cd /opt/claudeplanner/relay && npm ci --omit=dev`.

Or `rsync -a relay/ root@<ip>:/opt/claudeplanner-relay/` and install deps.

### 3. Place secrets

```sh
mkdir -p /etc/claudeplanner-relay
chmod 700 /etc/claudeplanner-relay
```

Copy in:
- `service-account.json` — same file the laptop daemon uses
  (`~/.config/brain-sync/service-account.json`). `chmod 600`.
- `.env` — based on `.env.example`. Fill in `ANTHROPIC_API_KEY`,
  set `ALLOWED_UIDS=<your Firebase UID>` (recommended for a single-user app).
  `chmod 600`.

### 4. systemd unit

Save as `/etc/systemd/system/claudeplanner-relay.service`:

```ini
[Unit]
Description=ClaudePlanner relay (Anthropic + Firestore)
After=network.target

[Service]
Type=simple
EnvironmentFile=/etc/claudeplanner-relay/.env
WorkingDirectory=/opt/claudeplanner/relay
ExecStart=/usr/bin/node src/index.js
Restart=on-failure
RestartSec=5s
User=www-data
Group=www-data
NoNewPrivileges=true
ProtectSystem=strict
ProtectHome=true
PrivateTmp=true
ReadOnlyPaths=/etc/claudeplanner-relay

[Install]
WantedBy=multi-user.target
```

Then:

```sh
chown -R www-data:www-data /etc/claudeplanner-relay /opt/claudeplanner/relay
systemctl daemon-reload
systemctl enable --now claudeplanner-relay
systemctl status claudeplanner-relay
journalctl -u claudeplanner-relay -f
```

### 5. Caddy reverse proxy (auto TLS)

Edit `/etc/caddy/Caddyfile`:

```
relay.yourname.com {
    reverse_proxy 127.0.0.1:8787
}
```

Then:

```sh
systemctl reload caddy
```

Caddy fetches a Let's Encrypt cert automatically the first time the domain is
hit. Test:

```sh
curl https://relay.yourname.com/healthz
# {"ok":true}
```

### 6. Point the iOS app at the relay

Edit `ios-app/ClaudePlanner/Talk/ClaudeClient.swift`:

```swift
enum RelayConfig {
    static let baseURL = URL(string: "https://relay.yourname.com")!
}
```

Rebuild on phone, tap the mic icon, speak.

## Updating

```sh
ssh root@<ip>
cd /opt/claudeplanner && git pull
cd relay && npm ci --omit=dev
systemctl restart claudeplanner-relay
```

## Cost ballpark

- Hetzner: whatever box you already have ($4–6/mo CX11 is plenty).
- Anthropic: pennies per message. Single-user planner with a few dozen
  messages a day is under $5/month at typical opus/haiku rates. Swap
  `ANTHROPIC_MODEL=claude-haiku-4-5` in `.env` for ~10× cheaper.
- Google: $0 (only the free Firestore tier is used).
