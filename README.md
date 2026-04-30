# 🚦 Traefik Dev Environment — GitHub Codespaces

[![Open in GitHub Codespaces](https://github.com/codespaces/badge.svg)](https://codespaces.new/lbrenman/traefik-codespace)

A fully working Traefik learning environment with **per-service API key authentication** and **UI services** — all routed through Traefik, HTTPS handled automatically by GitHub Codespaces.

---

## 🔐 Security Model

```
Client Request
     │
     ▼
 Traefik (:80)
     │
     ├── API routes ──► [forwardAuth] ──► auth-service:9000/auth?service=api1
     │                                        checks X-Api-Key header
     │                                        ◄── 200 OK  (key valid)
     │                                        ◄── 401     (key missing/wrong)
     │
     ├── UI routes ───► [strip-prefix] ──► Portainer / Grafana
     │                                        (own built-in login)
     │
     └── web ─────────► [strip-prefix] ──► Static frontend (open)
```

API services are protected by per-service API keys enforced at the Traefik layer. UI services use their own built-in authentication. HTTPS is provided automatically by GitHub Codespaces for all forwarded ports.

---

## 📦 Services

| Service | Route | Auth | Description |
|---|---|---|---|
| **Traefik** | `:8080/dashboard/` | Basic Auth (admin/admin123) | Reverse proxy + dashboard |
| **auth-service** | internal only | — | ForwardAuth API key validator |
| **whoami** | `/whoami/` | `X-Api-Key` (WHOAMI key) | Echo request headers |
| **api1** | `/api1/` | `X-Api-Key` (API1 key) | Products REST API |
| **api2** | `/api2/` | `X-Api-Key` (API2 key) | Users REST API |
| **web** | `/web` | None | Static frontend UI |
| **Portainer** | `/portainer/` | Own login (set on first visit) | Docker container management UI |
| **prometheus** | internal only | — | Metrics scraper (feeds Grafana) |
| **Grafana** | `/grafana/` | Own login (admin/admin) | Metrics dashboards UI |

---

## 🚀 Quick Start

```bash
# Start everything
docker compose up -d --build
# or
make up

# See the API keys
make show-keys

# Run auth tests (correct keys → 200, wrong/missing → 401)
make test-auth

# See example curl commands with real keys filled in
make examples
```

---

## 🖥️ UI Services

### Portainer — Docker Management UI
Route: `http://localhost/portainer/`

Portainer gives you a full visual interface for managing your Docker containers, images, volumes, and networks — everything running in this environment. On first visit you'll be prompted to set an admin password.

Behind the scenes, Traefik routes `/portainer/` → Portainer's internal port 9000 using a `strip-prefix` middleware. Portainer is a good example of routing a complex UI app (with WebSocket connections for live log streaming) through Traefik.

### Grafana — Metrics Dashboards
Route: `http://localhost/grafana/` — login with `admin` / `admin`

Grafana is pre-configured with a Prometheus datasource that automatically scrapes metrics from Traefik. You can explore request rates, response times, and router-level traffic data out of the box.

The key config detail: Grafana must be told it's served under a subpath so its internal asset URLs are correct:
```yaml
environment:
  - GF_SERVER_ROOT_URL=%(protocol)s://%(domain)s/grafana/
  - GF_SERVER_SERVE_FROM_SUB_PATH=true
```
This is a common real-world challenge with any UI app behind a reverse proxy subpath.

### Prometheus — Metrics Scraper (internal)
Prometheus is not exposed via Traefik — it's internal only, reachable by Grafana at `http://prometheus:9090`. It scrapes Traefik's built-in `/metrics` endpoint every 15 seconds.

---

## 🔑 API Keys

Keys are generated at setup and stored in `.env`. Each service has its own key.

```bash
# .env
API_KEY_API1=<48-char hex key for Products API>
API_KEY_API2=<48-char hex key for Users API>
API_KEY_WHOAMI=<48-char hex key for Whoami>
```

### Using the APIs

```bash
# Load keys from .env
source .env

# Products API (api1)
curl -H "X-Api-Key: $API_KEY_API1" http://localhost/api1/products
curl -H "X-Api-Key: $API_KEY_API1" http://localhost/api1/products/1
curl -X POST \
     -H "X-Api-Key: $API_KEY_API1" \
     -H "Content-Type: application/json" \
     -d '{"name":"Monitor","category":"Electronics","price":399.99}' \
     http://localhost/api1/products

# Users API (api2)
curl -H "X-Api-Key: $API_KEY_API2" http://localhost/api2/users
curl -H "X-Api-Key: $API_KEY_API2" http://localhost/api2/users/role/admin

# Whoami
curl -H "X-Api-Key: $API_KEY_WHOAMI" http://localhost/whoami/
```

### Expected failures

```bash
# No key → 401
curl http://localhost/api1/products

# Wrong key (api2's key on api1) → 401
curl -H "X-Api-Key: $API_KEY_API2" http://localhost/api1/products

# Garbage key → 401
curl -H "X-Api-Key: notvalid" http://localhost/api1/products
```

---

## 🧠 Traefik Concepts Illustrated

### ForwardAuth (API services)
```yaml
auth-api1:
  forwardAuth:
    address: "http://auth-service:9000/auth?service=api1"
    authRequestHeaders: ["X-Api-Key"]
    authResponseHeaders: ["X-Authenticated-Service"]
```

### Strip Prefix (UI services)
```yaml
strip-prefix-grafana:
  stripPrefix:
    prefixes: ["/grafana"]
```

### Middleware chains (order matters)
```
# API route:  auth → rate-limit → strip-prefix → backend
# UI route:   strip-prefix → backend
# Web route:  strip-prefix → backend
```

### Adding a New Protected Service
1. Add `API_KEY_MYNEWSERVICE=<key>` to `.env`
2. Add middleware in `config/traefik/dynamic/middlewares.yml`:
   ```yaml
   auth-mynewservice:
     forwardAuth:
       address: "http://auth-service:9000/auth?service=mynewservice"
       authRequestHeaders: ["X-Api-Key"]
   ```
3. Add Docker labels to the service in `docker-compose.yml`
4. `docker compose up -d` — Traefik hot-reloads, no restart needed

---

## 📁 Project Structure

```
traefik-codespace/
├── .devcontainer/
│   ├── devcontainer.json
│   └── setup.sh
├── config/
│   ├── traefik/
│   │   ├── traefik.yml               # Static config (entry points, providers)
│   │   └── dynamic/
│   │       └── middlewares.yml       # All middlewares — hot-reloaded
│   ├── prometheus/
│   │   └── prometheus.yml            # Scrape config (Traefik metrics)
│   └── grafana/
│       └── provisioning/
│           ├── datasources/          # Auto-provisions Prometheus datasource
│           └── dashboards/           # Dashboard provider config
├── services/
│   ├── auth-service/                 # ForwardAuth API key validator
│   ├── api1/                         # Products REST API
│   ├── api2/                         # Users REST API
│   └── web/                          # Static frontend
├── .env                              # API keys (never commit this!)
├── .env.example                      # Template
├── docker-compose.yml
├── docker-compose.scale.yml
├── Makefile
└── README.md
```

---

## 🛠 All Make Commands

```bash
make up            # Build and start everything
make down          # Stop everything
make show-keys     # Print API keys from .env
make test-auth     # Run full auth test suite (200s and 401s)
make examples      # Print curl commands with real keys
make auth-logs     # Tail auth service logs (live allow/deny decisions)
make traefik-logs  # Tail Traefik logs
make ps            # Show running containers
make scale         # Scale api1 to 3 replicas (load balancing demo)
make health        # Auth service health check
make rawdata       # Dump Traefik routing config JSON
make clean         # Remove everything (containers + volumes)
```

---

## 📚 Resources

- [Traefik ForwardAuth](https://doc.traefik.io/traefik/middlewares/http/forwardauth/)
- [Traefik BasicAuth](https://doc.traefik.io/traefik/middlewares/http/basicauth/)
- [Middleware Chaining](https://doc.traefik.io/traefik/routing/routers/#middlewares)
- [Dynamic Configuration](https://doc.traefik.io/traefik/providers/file/)
- [Portainer](https://docs.portainer.io/)
- [Grafana](https://grafana.com/docs/)
- [Prometheus](https://prometheus.io/docs/)
