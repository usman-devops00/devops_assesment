.PHONY: help up down logs test setup clean status health build

# Detect Docker Compose command
DOCKER_COMPOSE := $(shell which docker-compose 2>/dev/null)
ifeq ($(DOCKER_COMPOSE),)
    DOCKER_COMPOSE := docker compose
endif

# Default target
help: ## Show this help message
	@echo "DevOps assesment Infrastructure Management"
	@echo "========================================="
	@echo ""
	@echo "Available commands:"
	@awk 'BEGIN {FS = ":.*?## "} /^[a-zA-Z_-]+:.*?## / {printf "  \033[36m%-15s\033[0m %s\n", $$1, $$2}' $(MAKEFILE_LIST)

# Infrastructure commands
up: ## Start all services
	@echo "🚀 Starting DevOps assesment infrastructure..."
	@docker network create traefik-network 2>/dev/null || true
	@mkdir -p vault-init/output traefik certs init-db
	@chmod +x vault-init/init-vault.sh
	@$(DOCKER_COMPOSE) up -d --build
	@echo "⏳ Waiting for services to be ready..."
	@sleep 10
	@$(MAKE) setup
	@echo "✅ Infrastructure is ready!"
	@echo ""
	@echo "🌐 Access points:"
	@echo "  - Backend API: http://localhost:8443/api"
	@echo "  - Traefik Dashboard: http://localhost:8080"
	@echo "  - Vault UI: http://localhost:8200"
	@echo "  - PostgreSQL: localhost:5432"

down: ## Stop all services
	@echo "🛑 Stopping all services..."
	@$(DOCKER_COMPOSE) down
	@echo "✅ All services stopped"

logs: ## View service logs
	@$(DOCKER_COMPOSE) logs -f

setup: ## Run Ansible setup playbook
	@echo "🔧 Running Ansible setup..."
	@test -f venv/bin/activate || (echo "❌ Virtual environment not found. Run 'python3 -m venv venv && pip install -r requirements.txt'" && exit 1)
	@. venv/bin/activate && \
	pip install -r requirements.txt && \
	ansible-galaxy install -r requirements.yml && \
	ansible-playbook setup.yml -v || echo "⚠️  Ansible not available, using Vault init script"
	@echo "✅ Setup completed"


# Service management
restart: ## Restart all services
	@echo "🔄 Restarting services..."
	@$(DOCKER_COMPOSE) restart
	@echo "✅ Services restarted"

status: ## Show service status
	@echo "📊 Service Status:"
	@echo "=================="
	@$(DOCKER_COMPOSE) ps

health: ## Check service health
	@echo "🏥 Health Check:"
	@echo "================"
	@echo -n "Backend API: "
	@curl -s -o /dev/null -w "%{http_code}" http://localhost:8443/api/health || echo "❌ Failed"
	@echo ""
	@echo -n "Vault: "
	@curl -s -o /dev/null -w "%{http_code}" http://localhost:8200/v1/sys/health || echo "❌ Failed"
	@echo ""
	@echo -n "Traefik: "
	@curl -s -o /dev/null -w "%{http_code}" http://localhost:8080/api/overview || echo "❌ Failed"
	@echo ""

# Development commands
build: ## Build backend image
	@echo "🔨 Building backend image..."
	@$(DOCKER_COMPOSE) build backend
	@echo "✅ Backend image built"

test: ## Run API tests
	@echo "🧪 Running API tests..."
	@echo ""
	@echo "Testing health endpoint..."
	@curl -s http://localhost:8443/api/health | jq . || echo "❌ Health check failed"
	@echo ""
	@echo "Testing users endpoint..."
	@curl -s http://localhost:8443/api/users | jq . || echo "❌ Users endpoint failed"
	@echo ""
	@echo "Creating test user..."
	@curl -s -X POST http://localhost:8443/api/users \
		-H "Content-Type: application/json" \
		-d '{"username":"testuser","email":"test@example.com"}' | jq . || echo "❌ User creation failed"
	@echo ""
	@echo "✅ API tests completed"

# Cleanup commands
clean: ## Clean up containers, volumes, and networks
	@echo "🧹 Cleaning up..."
	@$(DOCKER_COMPOSE) down -v --remove-orphans
	@docker network rm traefik-network 2>/dev/null || true
	@docker volume prune -f
	@docker image prune -f
	@echo "✅ Cleanup completed"

clean-all: ## Complete cleanup including images
	@echo "🧹 Complete cleanup..."
	@$(DOCKER_COMPOSE) down -v --remove-orphans --rmi all
	@docker network rm traefik-network 2>/dev/null || true
	@docker system prune -af --volumes
	@echo "✅ Complete cleanup finished"

# Utility commands
shell-backend: ## Access backend container shell
	@docker exec -it backend sh

shell-vault: ## Access vault container shell
	@docker exec -it vault sh

shell-postgres: ## Access postgres container shell
	@docker exec -it postgres psql -U postgres -d devops_assesment

# Monitoring commands
monitor: ## Monitor resource usage
	@echo "📈 Resource Monitor:"
	@echo "==================="
	@docker stats --no-stream

backup: ## Backup database
	@echo "💾 Creating database backup..."
	@mkdir -p backups
	@docker exec postgres pg_dump -U postgres devops_assesment > backups/backup-$(shell date +%Y%m%d-%H%M%S).sql
	@echo "✅ Database backup created"

# Quick development cycle
dev: ## Quick development setup
	@$(MAKE) down
	@$(MAKE) build
	@$(MAKE) up
	@$(MAKE) test

# Check Docker installation
check-docker: ## Check Docker and Docker Compose installation
	@echo "🔍 Checking Docker installation..."
	@docker --version || (echo "❌ Docker not found. Please install Docker." && exit 1)
	@echo "🔍 Checking Docker Compose..."
	@$(DOCKER_COMPOSE) version || (echo "❌ Docker Compose not found. Please install Docker Compose." && exit 1)
	@echo "✅ Docker and Docker Compose are available"