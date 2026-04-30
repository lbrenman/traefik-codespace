#!/bin/bash
set -e

echo "==========================================="
echo "  Traefik Dev Environment - Setup Script"
echo "==========================================="

# Install docker-compose v2 if not present
if ! docker compose version &>/dev/null; then
  echo "Installing docker-compose plugin..."
  DOCKER_CONFIG=${DOCKER_CONFIG:-$HOME/.docker}
  mkdir -p $DOCKER_CONFIG/cli-plugins
  curl -SL https://github.com/docker/compose/releases/download/v2.24.5/docker-compose-linux-x86_64 \
    -o $DOCKER_CONFIG/cli-plugins/docker-compose
  chmod +x $DOCKER_CONFIG/cli-plugins/docker-compose
fi

echo ""
echo "✅ Setup complete!"
echo ""
echo "👉 To start Traefik + all services, run:"
echo "   docker compose up -d"
echo ""
echo "👉 Then open the Traefik dashboard at:"
echo "   http://localhost:8080/dashboard/"
echo ""
echo "👉 Access services via Traefik at:"
echo "   http://localhost/whoami"
echo "   http://localhost/api1"
echo "   http://localhost/api2"
echo "   http://localhost/web"
echo ""
