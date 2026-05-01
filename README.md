# 🚦 Traefik Dev Environment — GitHub Codespaces

[![Open in GitHub Codespaces](https://github.com/codespaces/badge.svg)](https://codespaces.new/lbrenman/traefik-codespace)

A fully working Traefik learning environment with **per-service API key authentication**, routed through Traefik. HTTPS handled automatically by GitHub Codespaces.

---

## 🚀 Quick Start

```bash
docker compose up -d --build
# or
make up
```

Open the **Ports** tab in VS Code to find the forwarded URLs for each port. Make sure all ports are set to **Public**.

---

## 📦 Services

| Service | Port | Path | Auth | Notes |
|---|---|---|---|---|
| **Traefik Dashboard** | 8080 | `/dashboard/` | Basic Auth (admin/admin123) | Router/middleware view |
| **Whoami** | 80 | `/whoami/` | `X-Api-Key` | Echo request headers |
| **Products API** | 80 | `/api1/` | `X-Api-Key` | REST API |
| **Users API** | 80 | `/api2/` | `X-Api-Key` | REST API |
| **Web UI** | 80 | `/web` | None | Static frontend |
| **Grafana** | 80 | `/grafana/` | Own login (admin/admin) | Metrics dashboards |
| **Portainer** | 9000 | `/` | Own login (set on first visit) | Docker management UI |

> In Codespaces: find each port's HTTPS URL in VS Code's **Ports** tab.

### Examples

* Traefik Dashboard - https://congenial-umbrella-7xpp9j5wjwjfxgvx-8080.app.github.dev/dashboard
* Portainer - https://congenial-umbrella-7xpp9j5wjwjfxgvx-9000.app.github.dev/
* Grafana - https://congenial-umbrella-7xpp9j5wjwjfxgvx-80.app.github.dev/grafana
* Web UI - https://congenial-umbrella-7xpp9j5wjwjfxgvx-80.app.github.dev/web

---

## 🔐 Security Model

```
Client
  │
  ▼
Traefik (:80)
  ├── /api1/*   → [forwardAuth] → [rate-limit] → [strip-prefix] → api1:3001
  ├── /api2/*   → [forwardAuth] → [rate-limit] → [strip-prefix] → api2:3002
  ├── /whoami/* → [forwardAuth] → [strip-prefix] → whoami:80
  ├── /grafana/ → grafana:3000  (Grafana handles subpath, no strip-prefix)
  └── /web      → [strip-prefix] → nginx:80

Portainer (:9000) — direct port, no Traefik (CE doesn't support subpath routing)
```

---

## 🔑 API Keys

Auto-generated on first launch, stored in `.env`.

```bash
source .env

# Correct key → 200
curl -H "X-Api-Key: $API_KEY_API1" http://localhost/api1/products
curl -H "X-Api-Key: $API_KEY_API2" http://localhost/api2/users
curl -H "X-Api-Key: $API_KEY_WHOAMI" http://localhost/whoami/

# Wrong key → 401
curl -H "X-Api-Key: $API_KEY_API2" http://localhost/api1/products

# Run full auth test suite
make test-auth
```

### Example Curl Commands

```bash
curl -H "X-Api-Key: e5bef915de9ddfa6a07a902c7d150db8bc301d846be9841f" https://symmetrical-barnacle-6p44gx5wwvrhxv6w-80.app.github.dev/api1/products

curl -H "X-Api-Key: 4d242c390f788a66b6ff1e10eb0538203e1a029e9bae63b2" https://symmetrical-barnacle-6p44gx5wwvrhxv6w-80.app.github.dev/api2/users

curl -H "X-Api-Key: 1f4465c5e3d5e2cc3503eea3d986ac1e430de440d8a37dca" https://symmetrical-barnacle-6p44gx5wwvrhxv6w-80.app.github.dev/whoami
```

---

## 🖥️ UI Services

### Grafana — `/grafana/`
Access via the port 80 Codespaces URL + `/grafana/`. Login: `admin` / `admin`.

Pre-provisioned with Prometheus as a datasource. Go to **Explore** and query `traefik_http_requests_total` to see live Traefik traffic metrics.

**Note:** `GF_SERVER_ROOT_URL` is set automatically to your Codespace URL by `setup.sh`. If you recreate the Codespace, the URL updates automatically.

#### Query

Select and Hit Run query and you'll see daya

traefik_router_requests_total
traefik_router_request_duration_seconds_bucket — response time histogram
traefik_service_requests_total — by service
traefik_entrypoint_requests_total — total traffic through port 80

#### Dashboard

* Click Dashboards in the left sidebar
* Click the New button (top right) → Import
* In the "Find and import dashboards" field, type 17347
* Click Load
* On the next screen, select Prometheus from the datasource dropdown
* Click Import

You'll get a full pre-built dashboard with request rates, response times, error rates, and per-router breakdowns — all using the correct Traefik v3 metric names.

### Portainer — port 9000
Access via the port 9000 Codespaces URL. Set admin password on first visit.

Portainer CE doesn't support subpath routing, so it runs on its own port rather than through Traefik.

---

## 🧠 Key Traefik Concepts

### Why Traefik v3.6?
Docker 29+ raised its minimum API version above what Traefik v3.1-v3.5 supports. Traefik v3.6 added auto-negotiation — this is the minimum version that works with Codespaces.

### ForwardAuth
```yaml
auth-api1:
  forwardAuth:
    address: "http://auth-service:9000/auth?service=api1"
    authRequestHeaders: ["X-Api-Key"]
```
Traefik calls the auth service before every API request. `200` → allow, `401` → block. The auth service is never exposed externally.

### Subpath routing: strip-prefix vs app-configured
- **APIs** use `strip-prefix` — `/api1/products` becomes `/products` at the backend
- **Grafana** does NOT use strip-prefix — `GF_SERVER_SERVE_FROM_SUB_PATH=true` tells Grafana to handle `/grafana/` itself. Strip-prefix causes a redirect loop with Grafana.

### Adding a new protected service
1. Add `API_KEY_NEWSERVICE=<key>` to `.env`
2. Add `auth-newservice` forwardAuth middleware to `config/traefik/dynamic/middlewares.yml`
3. Add labels to the new service in `docker-compose.yml`
4. `docker compose up -d` — Traefik hot-reloads instantly

---

## 📁 Project Structure

```
traefik-codespace/
├── .devcontainer/
│   ├── devcontainer.json       # Forwards ports 80, 8080, 9000
│   └── setup.sh                # Auto-generates .env with API keys + Grafana URL
├── config/
│   ├── traefik/
│   │   ├── traefik.yml         # Static config — unix socket, no network constraint
│   │   └── dynamic/
│   │       └── middlewares.yml # Auth + strip-prefix middlewares (hot-reloaded)
│   ├── prometheus/
│   │   └── prometheus.yml      # Scrapes Traefik metrics
│   └── grafana/
│       └── provisioning/       # Auto-provisions Prometheus datasource
├── services/
│   ├── auth-service/           # ForwardAuth API key validator
│   ├── api1/                   # Products REST API
│   ├── api2/                   # Users REST API
│   └── web/                    # Static frontend
├── .env                        # API keys + Grafana URL — auto-generated, gitignored
├── .env.example
├── docker-compose.yml
├── Makefile
└── README.md
```

---

## 🛠 Make Commands

```bash
make up            # Start everything (generates .env if missing)
make down          # Stop everything
make show-keys     # Print API keys
make test-auth     # Run auth test suite
make examples      # Print curl commands with real keys
make auth-logs     # Live allow/deny decisions
make traefik-logs  # Traefik logs
make ps            # Container status
make scale         # Scale api1 to 3 replicas (load balancing demo)
make rawdata       # Dump Traefik routing config JSON
make clean         # Remove everything including volumes
```

---

## 📚 Resources

- [Traefik Docker Provider](https://doc.traefik.io/traefik/providers/docker/)
- [Traefik ForwardAuth](https://doc.traefik.io/traefik/middlewares/http/forwardauth/)
- [Run Grafana behind a proxy](https://grafana.com/tutorials/run-grafana-behind-a-proxy/)
- [Portainer docs](https://docs.portainer.io/)
