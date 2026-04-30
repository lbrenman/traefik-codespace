# 🚦 Traefik Dev Environment — GitHub Codespaces

[![Open in GitHub Codespaces](https://github.com/codespaces/badge.svg)](https://codespaces.new/lbrenman/traefik-codespace)

A fully working Traefik learning environment with **per-service API key authentication**, routed through Traefik, with HTTPS handled automatically by GitHub Codespaces.

---

## 🚀 Quick Start

```bash
docker compose up -d --build
# or
make up
```

Then open the **Ports** tab in VS Code to find the forwarded URLs for each port.

---

## 📦 Services & How to Access Them

| Service | Port | Path | Auth | Notes |
|---|---|---|---|---|
| **Traefik Dashboard** | 8080 | `/dashboard/` | Basic Auth (admin/admin123) | Visual router/middleware view |
| **Whoami** | 80 | `/whoami/` | `X-Api-Key` | Echo request headers |
| **Products API** | 80 | `/api1/` | `X-Api-Key` | REST API |
| **Users API** | 80 | `/api2/` | `X-Api-Key` | REST API |
| **Web UI** | 80 | `/web` | None | Static frontend |
| **Grafana** | 80 | `/grafana` | Own login (admin/admin) | Metrics dashboards |
| **Portainer** | 9000 | `/` | Own login (set on first visit) | Docker management UI |

> **Codespaces note:** Each port gets its own `*.app.github.dev` HTTPS URL. Find them in VS Code's **Ports** tab. Port 80 handles Traefik-routed services. Port 9000 is Portainer directly.

---

## 🔐 Security Model

```
Client
  │
  ▼
Traefik (:80)
  ├── /api1/*   → [forwardAuth → auth-service] → [rate-limit] → [strip-prefix] → api1:3001
  ├── /api2/*   → [forwardAuth → auth-service] → [rate-limit] → [strip-prefix] → api2:3002
  ├── /whoami/* → [forwardAuth → auth-service] → [strip-prefix] → whoami:80
  ├── /grafana  → [strip-prefix] → grafana:3000  (Grafana's own login)
  └── /web      → [strip-prefix] → nginx:80       (open)

Portainer (:9000) — direct, no Traefik (Portainer CE doesn't support subpath routing)
```

---

## 🔑 API Keys

Generated automatically on first Codespace launch and stored in `.env`.

```bash
# Show your keys
make show-keys

# Use them
source .env
curl -H "X-Api-Key: $API_KEY_API1" http://localhost/api1/products
curl -H "X-Api-Key: $API_KEY_API2" http://localhost/api2/users
curl -H "X-Api-Key: $API_KEY_WHOAMI" http://localhost/whoami/

# Wrong key → 401
curl -H "X-Api-Key: $API_KEY_API2" http://localhost/api1/products
```

---

## 🖥️ UI Services

### Grafana — `/grafana`
Access via the port 80 Codespaces URL + `/grafana`. Login: `admin` / `admin`.

Pre-provisioned with a Prometheus datasource that scrapes Traefik metrics. Go to **Explore** and query `traefik_http_requests_total` to see live traffic data.

### Portainer — port 9000
Access via the port 9000 Codespaces URL. Set your admin password on first visit.

Portainer CE doesn't support subpath routing reliably, so it runs on its own port rather than through Traefik. It still shares the Docker network and can manage all the running containers.

---

## 🧠 Key Traefik Concepts

### ForwardAuth (API key enforcement)
```yaml
auth-api1:
  forwardAuth:
    address: "http://auth-service:9000/auth?service=api1"
    authRequestHeaders: ["X-Api-Key"]
```
Traefik calls the auth service before every request. `200` → allow, `401` → block.

### Middleware chain (order matters)
```
auth → rate-limit → strip-prefix → backend
```

### Strip Prefix
Removes the routing prefix before forwarding. `/api1/products` → `/products` at the backend.

### Adding a new protected service
1. Add `API_KEY_NEWSERVICE=<key>` to `.env`
2. Add `auth-newservice` forwardAuth middleware to `config/traefik/dynamic/middlewares.yml`
3. Add labels to the service in `docker-compose.yml`
4. `docker compose up -d` — Traefik hot-reloads, no restart needed

---

## 📁 Project Structure

```
traefik-codespace/
├── .devcontainer/
│   ├── devcontainer.json       # Ports 80, 8080, 9000 forwarded
│   └── setup.sh                # Auto-generates .env on first launch
├── config/
│   ├── traefik/
│   │   ├── traefik.yml         # Static config (entry points, providers)
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
├── .env                        # API keys — auto-generated, gitignored
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
make auth-logs     # Live allow/deny decisions from auth service
make traefik-logs  # Traefik logs
make ps            # Container status
make scale         # Scale api1 to 3 replicas (load balancing demo)
make rawdata       # Dump Traefik routing config JSON
make clean         # Remove everything including volumes
```

---

## 📚 Resources

- [Traefik ForwardAuth](https://doc.traefik.io/traefik/middlewares/http/forwardauth/)
- [Traefik Dynamic Config](https://doc.traefik.io/traefik/providers/file/)
- [Run Grafana behind a proxy](https://grafana.com/tutorials/run-grafana-behind-a-proxy/)
- [Portainer docs](https://docs.portainer.io/)
