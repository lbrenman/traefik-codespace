.PHONY: up down restart logs ps scale clean health test-auth test-denied rawdata help

# Load API keys from .env for use in make targets
-include .env
export

## Start all services (build first)
up:
	docker compose up -d --build
	@echo ""
	@echo "✅ All services started!"
	@echo ""
	@echo "   🔓 Open (no auth):"
	@echo "      Web App         → http://localhost/web"
	@echo "      Traefik Dash    → http://localhost:8080/dashboard/  (admin/admin123)"
	@echo ""
	@echo "   🔐 Protected (require X-Api-Key header):"
	@echo "      Whoami          → http://localhost/whoami/"
	@echo "      Products API    → http://localhost/api1/products"
	@echo "      Users API       → http://localhost/api2/users"
	@echo ""
	@echo "   Run 'make show-keys' to print the API keys"
	@echo "   Run 'make test-auth' to verify auth is working"

## Stop all services
down:
	docker compose down

## Restart all services
restart:
	docker compose restart

## Tail logs (all services)
logs:
	docker compose logs -f

## Tail auth service logs only (shows every allow/deny decision)
auth-logs:
	docker compose logs -f auth-service

## Tail Traefik logs only
traefik-logs:
	docker compose logs -f traefik

## Show running containers and status
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
	@echo ""
	@echo "[api2] GET /api2/health with correct key:"
	@curl -s -o /dev/null -w "  HTTP %{http_code}\n" -H "X-Api-Key: ${API_KEY_API2}" http://localhost/api2/health
	@echo ""
	@echo "[whoami] GET /whoami/ with correct key:"
	@curl -s -o /dev/null -w "  HTTP %{http_code}\n" -H "X-Api-Key: ${API_KEY_WHOAMI}" http://localhost/whoami/
	@echo ""
	@echo "--- 🚫 Should return 401 (wrong key) ---"
	@echo ""
	@echo "[api1] GET /api1/health with api2's key (wrong):"
	@curl -s -o /dev/null -w "  HTTP %{http_code}\n" -H "X-Api-Key: ${API_KEY_API2}" http://localhost/api1/health
	@echo ""
	@echo "[api2] GET /api2/health with no key:"
	@curl -s -o /dev/null -w "  HTTP %{http_code}\n" http://localhost/api2/health
	@echo ""
	@echo "[api1] GET /api1/health with garbage key:"
	@curl -s -o /dev/null -w "  HTTP %{http_code}\n" -H "X-Api-Key: notavalidkey" http://localhost/api1/health
	@echo ""
	@echo "--- ✅ Web should return 200 (no auth needed) ---"
	@echo ""
	@echo "[web] GET /web (no key):"
	@curl -s -o /dev/null -w "  HTTP %{http_code}\n" http://localhost/web
	@echo ""

## Quick health check of auth service itself
health:
	@curl -s http://localhost:9000/health 2>/dev/null | python3 -m json.tool || \
	 echo "(auth-service not directly exposed — check via docker exec)"
	@docker exec auth-service wget -qO- http://localhost:9000/health 2>/dev/null | python3 -m json.tool

## Print example curl commands with the real keys
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
	@echo "  # No auth on web"
	@echo "  curl http://localhost/web"
	@echo ""

## Dump raw Traefik routing config
rawdata:
	curl -s http://localhost:8080/api/rawdata | python3 -m json.tool

help:
	@grep -E '^##' Makefile | sed 's/## /  /'
