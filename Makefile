# Bitcoin Core Docker Project Makefile
# Provides standardized commands for building, running, and managing Bitcoin Core and Electrum Server

.PHONY: help build-bitcoin build-electrs build-all up down restart logs clean status bitcoin-cli test health check-deps

# Default target
help: ## Display this help message
	@echo "Bitcoin Core Docker Project"
	@echo "=========================="
	@echo ""
	@echo "Available commands:"
	@awk 'BEGIN {FS = ":.*?## "} /^[a-zA-Z_-]+:.*?## / {printf "  %-20s %s\n", $$1, $$2}' $(MAKEFILE_LIST)

# Build targets
build-bitcoin: ## Build Bitcoin Core Docker image
	docker build -t bitcoin bitcoin/docker/

build-electrs: ## Build Electrum Server Docker image
	docker build -t electrs electrs/

build-all: build-bitcoin build-electrs ## Build all Docker images

# Service orchestration
up: ## Start all services using docker-compose
	docker-compose up -d

down: ## Stop all services and remove containers
	docker-compose down

restart: down up ## Restart all services

logs: ## Show logs for all services
	docker-compose logs -f

logs-bitcoin: ## Show logs for Bitcoin Core only
	docker-compose logs -f bitcoin

logs-electrs: ## Show logs for Electrum Server only
	docker-compose logs -f electrs

# Bitcoin CLI operations
bitcoin-cli: ## Run bitcoin-cli command (usage: make bitcoin-cli ARGS="-getinfo")
	docker-compose exec bitcoin bitcoin-cli $(ARGS)

bitcoin-info: ## Get Bitcoin node info
	docker-compose exec bitcoin bitcoin-cli -getinfo

bitcoin-status: ## Get Bitcoin blockchain status
	docker-compose exec bitcoin bitcoin-cli getblockchaininfo

# Maintenance and monitoring
status: ## Show status of all services
	docker-compose ps

health: ## Check health of all services
	docker-compose exec bitcoin bitcoin-cli -getinfo || echo "Bitcoin Core not responding"
	docker-compose exec electrs curl -s http://localhost:4224/metrics > /dev/null && echo "Electrum Server healthy" || echo "Electrum Server not responding"

clean: ## Remove all containers, images, and volumes
	docker-compose down -v --remove-orphans
	docker rmi bitcoin electrs 2>/dev/null || true
	docker volume prune -f

clean-data: ## Remove blockchain data (WARNING: This will delete all blockchain data)
	@echo "WARNING: This will delete all blockchain data!"
	@read -p "Are you sure? (y/N): " confirm && [ "$$confirm" = "y" ] || exit 1
	docker-compose down -v
	docker volume rm $$(docker volume ls -q | grep bitcoin) 2>/dev/null || true

# Development and testing
test: ## Run basic connectivity tests
	@echo "Testing Bitcoin Core connectivity..."
	docker-compose exec bitcoin bitcoin-cli -getinfo > /dev/null && echo "✓ Bitcoin Core responding" || echo "✗ Bitcoin Core not responding"
	@echo "Testing Electrum Server connectivity..."
	docker-compose exec electrs curl -s http://localhost:4224/metrics > /dev/null && echo "✓ Electrum Server responding" || echo "✗ Electrum Server not responding"

check-deps: ## Check if required dependencies are installed
	@command -v docker >/dev/null 2>&1 || { echo "Docker is required but not installed"; exit 1; }
	@command -v docker-compose >/dev/null 2>&1 || { echo "Docker Compose is required but not installed"; exit 1; }
	@echo "✓ All dependencies are installed"

# Docker Hub operations
push-bitcoin: ## Push Bitcoin image to Docker Hub (set DOCKER_REPO and VERSION)
	@if [ -z "$(DOCKER_REPO)" ] || [ -z "$(VERSION)" ]; then \
		echo "Usage: make push-bitcoin DOCKER_REPO=username/bitcoin VERSION=v1.0"; \
		exit 1; \
	fi
	docker tag bitcoin $(DOCKER_REPO):$(VERSION)
	docker push $(DOCKER_REPO):$(VERSION)

push-electrs: ## Push Electrum Server image to Docker Hub (set DOCKER_REPO and VERSION)
	@if [ -z "$(DOCKER_REPO)" ] || [ -z "$(VERSION)" ]; then \
		echo "Usage: make push-electrs DOCKER_REPO=username/electrs VERSION=v1.0"; \
		exit 1; \
	fi
	docker tag electrs $(DOCKER_REPO):$(VERSION)
	docker push $(DOCKER_REPO):$(VERSION)

# Development shortcuts
dev: build-all up ## Build and start all services for development
	@echo "Services started. Use 'make logs' to view logs or 'make bitcoin-info' to check Bitcoin status"

stop: down ## Alias for down command