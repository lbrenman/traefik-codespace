# 🚦 Traefik Dev Environment — GitHub Codespaces

A fully working Traefik learning environment with **per-service API key authentication** enforced entirely at the gateway layer — no changes needed to backend services.

---

## 🔐 Security Model

```
Client Request
     │
     ▼
 Traefik (:80)
     │
     │  [forwardAuth middleware]
     ├──────────────────────────────► auth-service:9000/auth?service=api1
     │                                   checks X-Api-Key header
     │                                   ◄── 200 OK  (key valid)
     │                                   ◄── 401     (key missing/wrong)
     │
     │  [strip-prefix middleware]
     │  [rate-limit middleware]
     │
     ▼
 Backend Service (api1 / api2 / whoami)
```

Each service has a **different API key**. Using api2's key on api1 returns 401. The auth-service is **never exposed externally** — it only receives requests from Traefik inside the Docker network.

---

## 📦 Services

| Service | Route | Auth | Description |
|---|---|---|---|
| **Traefik** | `:8080/dashboard/` | Basic Auth (admin/admin123) | Reverse proxy + dashboard |
| **auth-service** | internal only | — | ForwardAuth API key validator |
| **whoami** | `/whoami/` | `X-Api-Key` (WHOAMI key) | Echo request headers |
| **api1** | `/api1/` | `X-Api-Key` (API1 key) | Products REST API |
| **api2** | `/api2/` | `X-Api-Key` (API2 key) | Users REST API |
| **web** | `/web` | None (intentionally open) | Frontend UI |

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

# Web app — no auth required
curl http://localhost/web
```

### Expected failures

```bash
# No key → 401
curl http://localhost/api1/products

# Wrong key (api2's key used on api1) → 401
curl -H "X-Api-Key: $API_KEY_API2" http://localhost/api1/products

# Garbage key → 401
curl -H "X-Api-Key: notvalid" http://localhost/api1/products
```

---

## 🧠 How the Auth Works (Traefik Concepts)

### ForwardAuth Middleware
Defined in `config/traefik/dynamic/middlewares.yml`:

```yaml
auth-api1:
  forwardAuth:
    address: "http://auth-service:9000/auth?service=api1"
    authRequestHeaders:
      - "X-Api-Key"           # forward client's key to auth service
    authResponseHeaders:
      - "X-Authenticated-Service"  # pass validated service name downstream
```

Applied on the router via Docker label:
```yaml
labels:
  - "traefik.http.routers.api1.middlewares=auth-api1@file,rate-limit@file,strip-prefix-api1@file"
```

### Middleware Chain (order matters)
```
auth-api1  →  rate-limit  →  strip-prefix-api1  →  backend
  (check)      (throttle)     (remove /api1)        (api1:3001)
```

### Adding a New Protected Service
1. Add `API_KEY_MYNEWSERVICE=<key>` to `.env`
2. Add a middleware in `middlewares.yml`:
   ```yaml
   auth-mynewservice:
     forwardAuth:
       address: "http://auth-service:9000/auth?service=mynewservice"
       authRequestHeaders: ["X-Api-Key"]
   ```
3. Add labels to the new service in `docker-compose.yml`:
   ```yaml
   labels:
     - "traefik.http.routers.mynew.middlewares=auth-mynewservice@file,strip-prefix-mynew@file"
   ```
4. `docker compose up -d` — Traefik hot-reloads instantly.

---

## 🔬 Auth Experiments to Try

### Watch auth decisions in real time
```bash
make auth-logs
# then in another terminal: make test-auth
```

### Rotate a key without downtime
1. Update `API_KEY_API1` in `.env`
2. `docker compose up -d auth-service` — only restarts auth-service
3. Old key immediately rejected, new key accepted

### See what Traefik sees
```bash
# Raw router/middleware config
make rawdata
# Check the api1 router middlewares array
```

### Intentionally break auth (then fix it)
```bash
# Set a bad auth service address (simulate outage)
# Edit middlewares.yml → address: "http://auth-service:9999/auth?service=api1"
# All api1 requests will return 500 (fail-closed) ← this is the safe behavior
# Restore the correct address → auto hot-reloaded
```

---

## 📁 Project Structure

```
traefik-codespace/
├── .devcontainer/
│   ├── devcontainer.json
│   └── setup.sh
├── config/traefik/
│   ├── traefik.yml                  # Static config
│   └── dynamic/
│       └── middlewares.yml          # Auth + other middlewares (hot-reloaded)
├── services/
│   ├── auth-service/                # ForwardAuth API key validator
│   │   ├── index.js                 # GET /auth?service=<name>
│   │   ├── package.json
│   │   └── Dockerfile
│   ├── api1/                        # Products API
│   ├── api2/                        # Users API
│   └── web/                         # Frontend
├── .env                             # API keys (gitignore this in production!)
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
make scale         # Scale api1 to 3 replicas
make health        # Auth service health check
make rawdata       # Dump Traefik routing config JSON
make clean         # Remove everything
```

---

## 📚 Resources

- [Traefik ForwardAuth](https://doc.traefik.io/traefik/middlewares/http/forwardauth/)
- [Traefik BasicAuth](https://doc.traefik.io/traefik/middlewares/http/basicauth/)
- [Middleware Chaining](https://doc.traefik.io/traefik/routing/routers/#middlewares)
- [Dynamic Configuration](https://doc.traefik.io/traefik/providers/file/)
