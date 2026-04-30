.PHONY: up down restart logs ps scale clean health test-auth examples show-keys rawdata help

-include .env
export

## Start all services (build first)
up:
	docker compose up -d --build
	@echo ""
	@echo "✅ All services started!"
	@echo ""
	@echo "   🔓 Open (no auth required):"
	@echo "      Web App         → http://localhost/web"
	@echo "      Traefik Dash    → http://localhost:8080/dashboard/  (admin/admin123)"
	@echo ""
	@echo "   🔐 Protected APIs (require X-Api-Key header):"
	@echo "      Whoami          → http://localhost/whoami/"
	@echo "      Products API    → http://localhost/api1/products"
	@echo "      Users API       → http://localhost/api2/users"
	@echo ""
	@echo "   🖥️  UI Services (own built-in login):"
	@echo "      Portainer       → http://localhost/portainer/  (set password on first visit)"
	@echo "      Grafana         → http://localhost/grafana/    (admin/admin)"
	@echo ""
	@echo "   Run 'make show-keys' to print the API keys"
	@echo "   Run 'make test-auth' to verify auth is working"

## Stop all services
down:
	docker compose down

## Restart all services
restart:
	docker compose restart

## Tail logs for all services
logs:
	docker compose logs -f

## Tail auth service logs (shows every allow/deny decision)
auth-logs:
	docker compose logs -f auth-service

## Tail Traefik logs only
traefik-logs:
	docker compose logs -f traefik

## Show running containers
ps:
	docker compose ps

## Scale api1 to 3 replicas (load balancing demo)
scale:
	docker compose up -d --scale api1=3 --no-recreate
	@echo "✅ api1 scaled to 3 replicas"

## Remove all containers, networks, volumes
clean:
	docker compose down -v --rmi local

## Print the API keys from .env
show-keys:
	@echo ""
	@echo "🔑 API Keys (from .env):"
	@echo "   api1   (Products) : ${API_KEY_API1}"
	@echo "   api2   (Users)    : ${API_KEY_API2}"
	@echo "   whoami            : ${API_KEY_WHOAMI}"
	@echo ""

## Test: verify all auth is working correctly
test-auth:
	@echo ""
	@echo "============================================"
	@echo " Auth Tests"
	@echo "============================================"
	@echo ""
	@echo "--- ✅ Should return 200 (correct keys) ---"
	@echo ""
	@echo "[api1] GET /api1/health with correct key:"
	@curl -s -o /dev/null -w "  HTTP %{http_code}\n" -H "X-Api-Key: ${API_KEY_API1}" http://localhost/api1/health
	@echo "[api2] GET /api2/health with correct key:"
	@curl -s -o /dev/null -w "  HTTP %{http_code}\n" -H "X-Api-Key: ${API_KEY_API2}" http://localhost/api2/health
	@echo "[whoami] GET /whoami/ with correct key:"
	@curl -s -o /dev/null -w "  HTTP %{http_code}\n" -H "X-Api-Key: ${API_KEY_WHOAMI}" http://localhost/whoami/
	@echo ""
	@echo "--- 🚫 Should return 401 (wrong/missing key) ---"
	@echo ""
	@echo "[api1] GET /api1/health with api2's key (wrong service key):"
	@curl -s -o /dev/null -w "  HTTP %{http_code}\n" -H "X-Api-Key: ${API_KEY_API2}" http://localhost/api1/health
	@echo "[api2] GET /api2/health with no key:"
	@curl -s -o /dev/null -w "  HTTP %{http_code}\n" http://localhost/api2/health
	@echo "[api1] GET /api1/health with garbage key:"
	@curl -s -o /dev/null -w "  HTTP %{http_code}\n" -H "X-Api-Key: notavalidkey" http://localhost/api1/health
	@echo ""
	@echo "--- ✅ UI services and web should return 200 (no API key) ---"
	@echo ""
	@echo "[web] GET /web:"
	@curl -s -o /dev/null -w "  HTTP %{http_code}\n" http://localhost/web
	@echo "[portainer] GET /portainer/:"
	@curl -s -o /dev/null -w "  HTTP %{http_code}\n" http://localhost/portainer/
	@echo "[grafana] GET /grafana/:"
	@curl -s -o /dev/null -w "  HTTP %{http_code}\n" http://localhost/grafana/
	@echo ""

## Print example curl commands with real keys
examples:
	@echo ""
	@echo "📋 Example curl commands:"
	@echo ""
	@echo "  # Products API"
	@echo "  curl -H 'X-Api-Key: ${API_KEY_API1}' http://localhost/api1/products"
	@echo "  curl -H 'X-Api-Key: ${API_KEY_API1}' http://localhost/api1/products/1"
	@echo "  curl -X POST -H 'X-Api-Key: ${API_KEY_API1}' -H 'Content-Type: application/json' \\"
	@echo "       -d '{\"name\":\"Monitor\",\"category\":\"Electronics\",\"price\":399.99}' \\"
	@echo "       http://localhost/api1/products"
	@echo ""
	@echo "  # Users API"
	@echo "  curl -H 'X-Api-Key: ${API_KEY_API2}' http://localhost/api2/users"
	@echo "  curl -H 'X-Api-Key: ${API_KEY_API2}' http://localhost/api2/users/role/admin"
	@echo ""
	@echo "  # Whoami"
	@echo "  curl -H 'X-Api-Key: ${API_KEY_WHOAMI}' http://localhost/whoami/"
	@echo ""
	@echo "  # No auth on web, Portainer, Grafana"
	@echo "  curl http://localhost/web"
	@echo "  open http://localhost/portainer/"
	@echo "  open http://localhost/grafana/"
	@echo ""

## Auth service health check
health:
	@docker exec auth-service wget -qO- http://localhost:9000/health 2>/dev/null | python3 -m json.tool

## Dump raw Traefik routing config
rawdata:
	curl -s http://localhost:8080/api/rawdata | python3 -m json.tool

help:
	@grep -E '^##' Makefile | sed 's/## /  /'
