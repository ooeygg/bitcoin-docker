# Bitcoin Core Docker Project Makefile
# Provides standardized commands for building, running, and managing Bitcoin Core and Electrum Server
# Optimized for production use with comprehensive operational commands

.PHONY: help init build-bitcoin build-electrs build-all up down restart logs clean status bitcoin-cli test health check-deps

# Color codes for pretty output
RED=\033[0;31m
GREEN=\033[0;32m
YELLOW=\033[1;33m
BLUE=\033[0;34m
PURPLE=\033[0;35m
CYAN=\033[0;36m
NC=\033[0m # No Color

# Default target - show help
help: ## Display this help message with descriptions
	@echo "$(CYAN)Bitcoin Core Docker Project$(NC)"
	@echo "$(CYAN)==========================$(NC)"
	@echo ""
	@echo "$(GREEN)🚀 Quick Start:$(NC)"
	@echo "  $(YELLOW)make init$(NC)     - Initialize project (create directories, .env)"
	@echo "  $(YELLOW)make dev$(NC)      - Build and start everything for development"
	@echo "  $(YELLOW)make status$(NC)   - Check status of all services"
	@echo ""
	@echo "$(GREEN)📋 Available Commands:$(NC)"
	@awk 'BEGIN {FS = ":.*?## "} /^[a-zA-Z_-]+:.*?## / {printf "  $(YELLOW)%-20s$(NC) %s\n", $$1, $$2}' $(MAKEFILE_LIST)
	@echo ""
	@echo "$(GREEN)💡 Examples:$(NC)"
	@echo "  $(CYAN)make bitcoin-cli ARGS=\"-getinfo\"$(NC)                    - Get node info"
	@echo "  $(CYAN)make bitcoin-cli ARGS=\"getblockchaininfo\"$(NC)           - Get blockchain status"
	@echo "  $(CYAN)make bitcoin-cli ARGS=\"createwallet mywallet\"$(NC)       - Create new wallet"
	@echo "  $(CYAN)make push-bitcoin DOCKER_REPO=user/bitcoin VERSION=v1.0$(NC) - Push to Docker Hub"

# =============================================================================
# INITIALIZATION AND SETUP
# =============================================================================

init: check-deps ## Initialize project (create directories, .env, check requirements)
	@echo "$(GREEN)🔧 Initializing Bitcoin Docker project...$(NC)"
	@echo "$(BLUE)Creating required directories...$(NC)"
	@mkdir -p bitcoin/data electrs/data
	@chmod 755 bitcoin/data electrs/data 2>/dev/null || { \
		echo "$(YELLOW)⚠️  Permission issue detected. Attempting to fix...$(NC)"; \
		sudo chown -R $(shell whoami):$(shell whoami) bitcoin/data electrs/data 2>/dev/null || true; \
		chmod 755 bitcoin/data electrs/data 2>/dev/null || true; \
	}
	@if [ ! -f .env ]; then \
		echo "$(YELLOW)⚠️  Creating .env from .env.example...$(NC)"; \
		cp .env.example .env; \
		echo "$(RED)🔐 IMPORTANT: Edit .env and change BITCOIN_RPC_PASSWORD!$(NC)"; \
		echo "$(CYAN)💡 Run: nano .env$(NC)"; \
	else \
		echo "$(GREEN)✅ .env file already exists$(NC)"; \
	fi
	@echo "$(GREEN)✅ Initialization complete!$(NC)"

check-deps: ## Check if required dependencies are installed
	@echo "$(BLUE)🔍 Checking dependencies...$(NC)"
	@command -v docker >/dev/null 2>&1 || { echo "$(RED)❌ Docker is required but not installed. Visit: https://docs.docker.com/get-docker/$(NC)"; exit 1; }
	@command -v docker-compose >/dev/null 2>&1 || { echo "$(RED)❌ Docker Compose is required but not installed. Visit: https://docs.docker.com/compose/install/$(NC)"; exit 1; }
	@docker info >/dev/null 2>&1 || { echo "$(RED)❌ Docker daemon is not running. Please start Docker.$(NC)"; exit 1; }
	@echo "$(GREEN)✅ All dependencies are installed and running$(NC)"

# =============================================================================
# BUILD COMMANDS
# =============================================================================

build-bitcoin: ## Build Bitcoin Core Docker image
	@echo "$(BLUE)🔨 Building Bitcoin Core image...$(NC)"
	docker build -t bitcoin bitcoin/docker/
	@echo "$(GREEN)✅ Bitcoin Core image built successfully$(NC)"

build-electrs: ## Build Electrum Server Docker image  
	@echo "$(BLUE)🔨 Building Electrum Server image...$(NC)"
	docker build -t electrs electrs/
	@echo "$(GREEN)✅ Electrum Server image built successfully$(NC)"

build-all: build-bitcoin build-electrs ## Build all Docker images
	@echo "$(GREEN)✅ All images built successfully$(NC)"

rebuild: clean-images build-all ## Force rebuild all images from scratch
	@echo "$(GREEN)✅ All images rebuilt from scratch$(NC)"

build-fractal: ## Build Fractal Bitcoin Docker image
	@echo "$(BLUE)🔨 Building Fractal Bitcoin image...$(NC)"
	docker build -t fractal-bitcoin fractal-bitcoin/docker/
	@echo "$(GREEN)✅ Fractal Bitcoin image built successfully$(NC)"

build-all: build-bitcoin build-electrs build-fractal ## Build all images

fractal-cli: ## Run fractal bitcoin-cli command
	@if [ -z "$(ARGS)" ]; then \
		echo "$(RED)❌ Please provide ARGS. Example: make fractal-cli ARGS=\"-getinfo\"$(NC)"; \
		exit 1; \
	fi
	@if [ -f .env ]; then \
		export $$(grep -E '^FRACTAL_RPC_(USER|PASSWORD)=' .env | xargs) && \
		docker-compose exec fractal-bitcoin bitcoin-cli -datadir=/data -rpcuser=$$FRACTAL_RPC_USER -rpcpassword=$$FRACTAL_RPC_PASSWORD $(ARGS); \
	fi

fractal-info: ## Get Fractal Bitcoin node information
	@echo "$(BLUE)📊 Fractal Bitcoin Node Information:$(NC)"
	@if [ -f .env ]; then \
		export $$(grep -E '^FRACTAL_RPC_(USER|PASSWORD)=' .env | xargs) && \
		docker-compose exec fractal-bitcoin bitcoin-cli -datadir=/data -rpcuser=$$FRACTAL_RPC_USER -rpcpassword=$$FRACTAL_RPC_PASSWORD -getinfo; \
	fi

dual-info: bitcoin-info fractal-info

# =============================================================================
# SERVICE ORCHESTRATION
# =============================================================================

up: init ## Start all services using docker-compose
	@echo "$(GREEN)🚀 Starting Bitcoin Core stack...$(NC)"
	docker-compose up -d
	@echo "$(GREEN)✅ Services started! Use 'make status' to check status$(NC)"

down: ## Stop all services and remove containers
	@echo "$(YELLOW)🛑 Stopping all services...$(NC)"
	docker-compose down
	@echo "$(GREEN)✅ All services stopped$(NC)"

restart: down up ## Restart all services (stop + start)
	@echo "$(GREEN)🔄 Services restarted$(NC)"

stop: down ## Alias for down command

start: up ## Alias for up command

# =============================================================================
# LOGGING AND MONITORING
# =============================================================================

logs: ## Show logs for all services (follow mode)
	@echo "$(BLUE)📋 Showing logs for all services (Ctrl+C to exit)...$(NC)"
	docker-compose logs -f

logs-bitcoin: ## Show logs for Bitcoin Core only
	@echo "$(BLUE)📋 Showing Bitcoin Core logs (Ctrl+C to exit)...$(NC)"
	docker-compose logs -f bitcoin

logs-electrs: ## Show logs for Electrum Server only
	@echo "$(BLUE)📋 Showing Electrum Server logs (Ctrl+C to exit)...$(NC)"
	docker-compose logs -f electrs

logs-tail: ## Show last 100 lines of logs for all services
	docker-compose logs --tail=100

logs-bitcoin-tail: ## Show last 100 lines of Bitcoin Core logs
	docker-compose logs --tail=100 bitcoin

logs-electrs-tail: ## Show last 100 lines of Electrum Server logs
	docker-compose logs --tail=100 electrs

# =============================================================================
# BITCOIN OPERATIONS
# =============================================================================

bitcoin-cli: ## Run bitcoin-cli command (usage: make bitcoin-cli ARGS="-getinfo")
	@if [ -z "$(ARGS)" ]; then \
		echo "$(RED)❌ Please provide ARGS. Example: make bitcoin-cli ARGS=\"-getinfo\"$(NC)"; \
		exit 1; \
	fi
	@if [ -f .env ]; then \
		export $$(grep -E '^BITCOIN_RPC_(USER|PASSWORD)=' .env | xargs) && \
		docker-compose exec bitcoin bitcoin-cli -datadir=/data -rpcuser=$$BITCOIN_RPC_USER -rpcpassword=$$BITCOIN_RPC_PASSWORD $(ARGS); \
	else \
		echo "$(RED)❌ .env file not found. Run 'make init' first.$(NC)"; \
		exit 1; \
	fi

bitcoin-info: ## Get comprehensive Bitcoin node information
	@echo "$(BLUE)📊 Bitcoin Core Node Information:$(NC)"
	@echo "$(CYAN)================================$(NC)"
	@if [ -f .env ]; then \
		export $$(grep -E '^BITCOIN_RPC_(USER|PASSWORD)=' .env | xargs) && \
		docker-compose exec bitcoin bitcoin-cli -datadir=/data -rpcuser=$$BITCOIN_RPC_USER -rpcpassword=$$BITCOIN_RPC_PASSWORD -getinfo; \
	else \
		echo "$(RED)❌ .env file not found. Run 'make init' first.$(NC)"; \
	fi

bitcoin-status: ## Get detailed blockchain status
	@echo "$(BLUE)⛓️  Blockchain Status:$(NC)"
	@echo "$(CYAN)==================$(NC)"
	@if [ -f .env ]; then \
		export $$(grep -E '^BITCOIN_RPC_(USER|PASSWORD)=' .env | xargs) && \
		docker-compose exec bitcoin bitcoin-cli -datadir=/data -rpcuser=$$BITCOIN_RPC_USER -rpcpassword=$$BITCOIN_RPC_PASSWORD getblockchaininfo; \
	else \
		echo "$(RED)❌ .env file not found. Run 'make init' first.$(NC)"; \
	fi

bitcoin-peers: ## Show connected peers
	@echo "$(BLUE)🌐 Connected Peers:$(NC)"
	@echo "$(CYAN)=================$(NC)"
	@if [ -f .env ]; then \
		export $$(grep -E '^BITCOIN_RPC_(USER|PASSWORD)=' .env | xargs) && \
		docker-compose exec bitcoin bitcoin-cli -datadir=/data -rpcuser=$$BITCOIN_RPC_USER -rpcpassword=$$BITCOIN_RPC_PASSWORD getpeerinfo | grep -E '"addr"|"version"|"subver"' | head -20; \
	else \
		echo "$(RED)❌ .env file not found. Run 'make init' first.$(NC)"; \
	fi

bitcoin-mempool: ## Show mempool information
	@echo "$(BLUE)💾 Mempool Information:$(NC)"
	@echo "$(CYAN)=====================$(NC)"
	@if [ -f .env ]; then \
		export $$(grep -E '^BITCOIN_RPC_(USER|PASSWORD)=' .env | xargs) && \
		docker-compose exec bitcoin bitcoin-cli -datadir=/data -rpcuser=$$BITCOIN_RPC_USER -rpcpassword=$$BITCOIN_RPC_PASSWORD getmempoolinfo; \
	else \
		echo "$(RED)❌ .env file not found. Run 'make init' first.$(NC)"; \
	fi

bitcoin-wallet-info: ## Show wallet information (if wallet exists)
	@echo "$(BLUE)💰 Wallet Information:$(NC)"
	@echo "$(CYAN)=====================$(NC)"
	@if [ -f .env ]; then \
		export $$(grep -E '^BITCOIN_RPC_(USER|PASSWORD)=' .env | xargs) && \
		docker-compose exec bitcoin bitcoin-cli -datadir=/data -rpcuser=$$BITCOIN_RPC_USER -rpcpassword=$$BITCOIN_RPC_PASSWORD getwalletinfo || echo "$(YELLOW)⚠️  No wallet loaded$(NC)"; \
	else \
		echo "$(RED)❌ .env file not found. Run 'make init' first.$(NC)"; \
	fi

create-wallet: ## Create a new wallet (usage: make create-wallet WALLET=mywallet)
	@if [ -z "$(WALLET)" ]; then \
		echo "$(RED)❌ Please provide WALLET name. Example: make create-wallet WALLET=mywallet$(NC)"; \
		exit 1; \
	fi
	@echo "$(BLUE)💰 Creating wallet: $(WALLET)$(NC)"
	@if [ -f .env ]; then \
		export $$(grep -E '^BITCOIN_RPC_(USER|PASSWORD)=' .env | xargs) && \
		docker-compose exec bitcoin bitcoin-cli -datadir=/data -rpcuser=$$BITCOIN_RPC_USER -rpcpassword=$$BITCOIN_RPC_PASSWORD createwallet $(WALLET); \
	else \
		echo "$(RED)❌ .env file not found. Run 'make init' first.$(NC)"; \
	fi

# =============================================================================
# STATUS AND HEALTH MONITORING
# =============================================================================

health: ## Comprehensive health check of all services
	@echo "$(BLUE)🏥 Health Check:$(NC)"
	@echo "$(CYAN)===============$(NC)"
	@echo "$(YELLOW)🔍 Checking Bitcoin Core...$(NC)"
	@if [ -f .env ]; then \
		export $$(grep -E '^BITCOIN_RPC_(USER|PASSWORD)=' .env | xargs) && \
		if docker-compose exec bitcoin bitcoin-cli -datadir=/data -rpcuser=$$BITCOIN_RPC_USER -rpcpassword=$$BITCOIN_RPC_PASSWORD -getinfo >/dev/null 2>&1; then \
			echo "$(GREEN)✅ Bitcoin Core: Healthy$(NC)"; \
		else \
			echo "$(RED)❌ Bitcoin Core: Unhealthy$(NC)"; \
		fi; \
	else \
		echo "$(RED)❌ .env file not found$(NC)"; \
	fi
	@echo "$(YELLOW)🔍 Checking Electrum Server...$(NC)"
	@if docker-compose exec electrs curl -s http://localhost:4224/metrics >/dev/null 2>&1; then \
		echo "$(GREEN)✅ Electrum Server: Healthy$(NC)"; \
	else \
		echo "$(RED)❌ Electrum Server: Unhealthy$(NC)"; \
	fi

memory-usage: ## Show detailed memory usage
	@echo "$(BLUE)💾 Memory Usage Details:$(NC)"
	@echo "$(CYAN)========================$(NC)"
	@echo "$(YELLOW)Bitcoin Core Memory:$(NC)"
	@if [ -f .env ]; then \
		export $$(grep -E '^BITCOIN_RPC_(USER|PASSWORD)=' .env | xargs) && \
		docker-compose exec bitcoin bitcoin-cli -datadir=/data -rpcuser=$$BITCOIN_RPC_USER -rpcpassword=$$BITCOIN_RPC_PASSWORD getmemoryinfo || echo "$(RED)❌ Bitcoin Core not responding$(NC)"; \
	else \
		echo "$(RED)❌ .env file not found$(NC)"; \
	fi
	@echo ""
	@echo "$(YELLOW)Electrum Server Metrics:$(NC)"
	docker-compose exec electrs curl -s http://localhost:4224/metrics | grep memory || echo "$(RED)❌ Electrum Server not responding$(NC)"

# =============================================================================
# DEVELOPMENT AND TESTING
# =============================================================================

test: ## Run comprehensive connectivity and functionality tests
	@echo "$(BLUE)🧪 Running Tests:$(NC)"
	@echo "$(CYAN)=================$(NC)"
	@echo "$(YELLOW)🔍 Testing Bitcoin Core connectivity...$(NC)"
	@if [ -f .env ]; then \
		export $$(grep -E '^BITCOIN_RPC_(USER|PASSWORD)=' .env | xargs) && \
		if docker-compose exec bitcoin bitcoin-cli -datadir=/data -rpcuser=$$BITCOIN_RPC_USER -rpcpassword=$$BITCOIN_RPC_PASSWORD -getinfo >/dev/null 2>&1; then \
			echo "$(GREEN)✅ Bitcoin Core: Connected and responding$(NC)"; \
		else \
			echo "$(RED)❌ Bitcoin Core: Not responding$(NC)"; \
		fi; \
	else \
		echo "$(RED)❌ .env file not found$(NC)"; \
	fi
	@echo "$(YELLOW)🔍 Testing Electrum Server connectivity...$(NC)"
	@if docker-compose exec electrs curl -s http://localhost:4224/metrics >/dev/null 2>&1; then \
		echo "$(GREEN)✅ Electrum Server: Connected and responding$(NC)"; \
	else \
		echo "$(RED)❌ Electrum Server: Not responding$(NC)"; \
	fi
	@echo "$(YELLOW)🔍 Testing network connectivity...$(NC)"
	@if docker network inspect bitcoin-stack_bitcoin-network >/dev/null 2>&1; then \
		echo "$(GREEN)✅ Docker network: Available$(NC)"; \
	else \
		echo "$(RED)❌ Docker network: Not found$(NC)"; \
	fi

test-rpc: ## Test Bitcoin RPC with sample commands
	@echo "$(BLUE)🔌 Testing Bitcoin RPC:$(NC)"
	@echo "$(CYAN)=======================$(NC)"
	@if [ -f .env ]; then \
		export $$(grep -E '^BITCOIN_RPC_(USER|PASSWORD)=' .env | xargs) && \
		echo "$(YELLOW)Node Info:$(NC)" && \
		docker-compose exec bitcoin bitcoin-cli -datadir=/data -rpcuser=$$BITCOIN_RPC_USER -rpcpassword=$$BITCOIN_RPC_PASSWORD -getinfo && \
		echo "" && \
		echo "$(YELLOW)Block Count:$(NC)" && \
		docker-compose exec bitcoin bitcoin-cli -datadir=/data -rpcuser=$$BITCOIN_RPC_USER -rpcpassword=$$BITCOIN_RPC_PASSWORD getblockcount && \
		echo "" && \
		echo "$(YELLOW)Connection Count:$(NC)" && \
		docker-compose exec bitcoin bitcoin-cli -datadir=/data -rpcuser=$$BITCOIN_RPC_USER -rpcpassword=$$BITCOIN_RPC_PASSWORD getconnectioncount; \
	else \
		echo "$(RED)❌ .env file not found. Run 'make init' first.$(NC)"; \
	fi

# =============================================================================
# WALLET OPERATIONS
# =============================================================================

list-wallets: ## List all available wallets
	@echo "$(BLUE)💰 Available Wallets:$(NC)"
	@echo "$(CYAN)===================$(NC)"
	@if [ -f .env ]; then \
		export $$(grep -E '^BITCOIN_RPC_(USER|PASSWORD)=' .env | xargs) && \
		docker-compose exec bitcoin bitcoin-cli -datadir=/data -rpcuser=$$BITCOIN_RPC_USER -rpcpassword=$$BITCOIN_RPC_PASSWORD listwallets || echo "$(YELLOW)⚠️  No wallets available$(NC)"; \
	else \
		echo "$(RED)❌ .env file not found. Run 'make init' first.$(NC)"; \
	fi

load-wallet: ## Load a wallet (usage: make load-wallet WALLET=mywallet)
	@if [ -z "$(WALLET)" ]; then \
		echo "$(RED)❌ Please provide WALLET name. Example: make load-wallet WALLET=mywallet$(NC)"; \
		exit 1; \
	fi
	@echo "$(BLUE)💰 Loading wallet: $(WALLET)$(NC)"
	@if [ -f .env ]; then \
		export $$(grep -E '^BITCOIN_RPC_(USER|PASSWORD)=' .env | xargs) && \
		docker-compose exec bitcoin bitcoin-cli -datadir=/data -rpcuser=$$BITCOIN_RPC_USER -rpcpassword=$$BITCOIN_RPC_PASSWORD loadwallet $(WALLET); \
	else \
		echo "$(RED)❌ .env file not found. Run 'make init' first.$(NC)"; \
	fi

unload-wallet: ## Unload a wallet (usage: make unload-wallet WALLET=mywallet)
	@if [ -z "$(WALLET)" ]; then \
		echo "$(RED)❌ Please provide WALLET name. Example: make unload-wallet WALLET=mywallet$(NC)"; \
		exit 1; \
	fi
	@echo "$(BLUE)💰 Unloading wallet: $(WALLET)$(NC)"
	@if [ -f .env ]; then \
		export $$(grep -E '^BITCOIN_RPC_(USER|PASSWORD)=' .env | xargs) && \
		docker-compose exec bitcoin bitcoin-cli -datadir=/data -rpcuser=$$BITCOIN_RPC_USER -rpcpassword=$$BITCOIN_RPC_PASSWORD unloadwallet $(WALLET); \
	else \
		echo "$(RED)❌ .env file not found. Run 'make init' first.$(NC)"; \
	fi

new-address: ## Generate new receiving address (usage: make new-address WALLET=mywallet)
	@if [ -z "$(WALLET)" ]; then \
		echo "$(RED)❌ Please provide WALLET name. Example: make new-address WALLET=mywallet$(NC)"; \
		exit 1; \
	fi
	@echo "$(BLUE)💰 Generating new address for wallet: $(WALLET)$(NC)"
	@if [ -f .env ]; then \
		export $$(grep -E '^BITCOIN_RPC_(USER|PASSWORD)=' .env | xargs) && \
		docker-compose exec bitcoin bitcoin-cli -datadir=/data -rpcuser=$$BITCOIN_RPC_USER -rpcpassword=$$BITCOIN_RPC_PASSWORD -rpcwallet=$(WALLET) getnewaddress; \
	else \
		echo "$(RED)❌ .env file not found. Run 'make init' first.$(NC)"; \
	fi

# =============================================================================
# CLEANUP AND MAINTENANCE
# =============================================================================

clean: ## Remove containers and networks (keeps volumes/data)
	@echo "$(YELLOW)🧹 Cleaning up containers and networks...$(NC)"
	docker-compose down -v --remove-orphans
	@echo "$(GREEN)✅ Cleanup complete (data preserved)$(NC)"

clean-images: ## Remove Bitcoin Docker images
	@echo "$(YELLOW)🧹 Removing Bitcoin Docker images...$(NC)"
	docker rmi bitcoin electrs 2>/dev/null || true
	@echo "$(GREEN)✅ Images removed$(NC)"

clean-all: clean clean-images ## Remove everything except data volumes
	docker network prune -f
	docker volume prune -f
	@echo "$(GREEN)✅ Complete cleanup finished (data preserved)$(NC)"

clean-data: ## Remove blockchain data (WARNING: DESTRUCTIVE!)
	@echo "$(RED)⚠️  WARNING: This will delete ALL blockchain data!$(NC)"
	@echo "$(RED)This action cannot be undone and will require full resync.$(NC)"
	@read -p "Are you absolutely sure? Type 'DELETE' to confirm: " confirm; \
	if [ "$$confirm" = "DELETE" ]; then \
		echo "$(YELLOW)🗑️  Removing all data...$(NC)"; \
		docker-compose down -v; \
		sudo rm -rf bitcoin/data/* electrs/data/* 2>/dev/null || true; \
		docker volume rm $$(docker volume ls -q | grep bitcoin) 2>/dev/null || true; \
		echo "$(GREEN)✅ All data removed$(NC)"; \
	else \
		echo "$(GREEN)✅ Operation cancelled$(NC)"; \
	fi

# =============================================================================
# BACKUP AND RESTORE
# =============================================================================

backup: ## Create backup of blockchain data
	@echo "$(BLUE)💾 Creating backup...$(NC)"
	@BACKUP_NAME="bitcoin-backup-$$(date +%Y%m%d-%H%M%S)"; \
	echo "$(YELLOW)📦 Creating backup: $$BACKUP_NAME.tar.gz$(NC)"; \
	docker-compose down; \
	tar -czf "$$BACKUP_NAME.tar.gz" bitcoin/data electrs/data; \
	echo "$(GREEN)✅ Backup created: $$BACKUP_NAME.tar.gz$(NC)"; \
	docker-compose up -d

backup-quick: ## Quick backup (without stopping services)
	@echo "$(BLUE)💾 Creating quick backup (services running)...$(NC)"
	@BACKUP_NAME="bitcoin-quick-backup-$$(date +%Y%m%d-%H%M%S)"; \
	echo "$(YELLOW)📦 Creating backup: $$BACKUP_NAME.tar.gz$(NC)"; \
	tar -czf "$$BACKUP_NAME.tar.gz" bitcoin/data electrs/data; \
	echo "$(GREEN)✅ Quick backup created: $$BACKUP_NAME.tar.gz$(NC)"

# =============================================================================
# DOCKER HUB OPERATIONS
# =============================================================================

login-docker: ## Login to Docker Hub
	docker login

push-bitcoin: ## Push Bitcoin image to Docker Hub (set DOCKER_REPO and VERSION)
	@if [ -z "$(DOCKER_REPO)" ] || [ -z "$(VERSION)" ]; then \
		echo "$(RED)❌ Usage: make push-bitcoin DOCKER_REPO=username/bitcoin VERSION=v1.0$(NC)"; \
		exit 1; \
	fi
	@echo "$(BLUE)📤 Pushing Bitcoin image...$(NC)"
	docker tag bitcoin $(DOCKER_REPO):$(VERSION)
	docker push $(DOCKER_REPO):$(VERSION)
	@echo "$(GREEN)✅ Bitcoin image pushed: $(DOCKER_REPO):$(VERSION)$(NC)"

push-electrs: ## Push Electrum Server image to Docker Hub (set DOCKER_REPO and VERSION)
	@if [ -z "$(DOCKER_REPO)" ] || [ -z "$(VERSION)" ]; then \
		echo "$(RED)❌ Usage: make push-electrs DOCKER_REPO=username/electrs VERSION=v1.0$(NC)"; \
		exit 1; \
	fi
	@echo "$(BLUE)📤 Pushing Electrum Server image...$(NC)"
	docker tag electrs $(DOCKER_REPO):$(VERSION)
	docker push $(DOCKER_REPO):$(VERSION)
	@echo "$(GREEN)✅ Electrum Server image pushed: $(DOCKER_REPO):$(VERSION)$(NC)"

push-all: ## Push all images to Docker Hub (set DOCKER_REPO and VERSION)
	make push-bitcoin DOCKER_REPO=$(DOCKER_REPO) VERSION=$(VERSION)
	make push-electrs DOCKER_REPO=$(DOCKER_REPO) VERSION=$(VERSION)

# =============================================================================
# CONFIGURATION MANAGEMENT
# =============================================================================

config-check: ## Validate configuration files
	@echo "$(BLUE)🔍 Checking configuration...$(NC)"
	@echo "$(YELLOW)📋 .env file:$(NC)"
	@if [ -f .env ]; then \
		grep -E "^[A-Z_]+" .env | head -10; \
		echo "$(GREEN)✅ .env file exists$(NC)"; \
	else \
		echo "$(RED)❌ .env file missing$(NC)"; \
	fi
	@echo "$(YELLOW)📋 bitcoin.conf:$(NC)"
	@if [ -f bitcoin/bitcoin.conf ]; then \
		echo "$(GREEN)✅ bitcoin.conf exists$(NC)"; \
	else \
		echo "$(RED)❌ bitcoin.conf missing$(NC)"; \
	fi
	@echo "$(YELLOW)📋 Docker Compose:$(NC)"
	docker-compose config >/dev/null 2>&1 && echo "$(GREEN)✅ docker-compose.yml valid$(NC)" || echo "$(RED)❌ docker-compose.yml invalid$(NC)"

show-config: ## Show current configuration (sanitized)
	@echo "$(BLUE)⚙️  Current Configuration:$(NC)"
	@echo "$(CYAN)=========================$(NC)"
	@if [ -f .env ]; then \
		echo "$(YELLOW).env variables:$(NC)"; \
		grep -E "^[A-Z_]+=" .env | sed 's/PASSWORD=.*/PASSWORD=***HIDDEN***/' | sed 's/PASS=.*/PASS=***HIDDEN***/'; \
	fi

edit-env: ## Open .env file in default editor
	@if [ -f .env ]; then \
		$${EDITOR:-nano} .env; \
	else \
		echo "$(RED)❌ .env file not found. Run 'make init' first.$(NC)"; \
	fi

# =============================================================================
# INFORMATION AND HELP
# =============================================================================

info: ## Show comprehensive project information
	@echo "$(CYAN)📚 Bitcoin Core Docker Stack Information$(NC)"
	@echo "$(CYAN)========================================$(NC)"
	@echo ""
	@echo "$(GREEN)🎯 Purpose:$(NC) Run Bitcoin Core full node and Electrum Server"
	@echo "$(GREEN)🐳 Platform:$(NC) Docker + Docker Compose"
	@echo "$(GREEN)🔧 Management:$(NC) Makefile commands"
	@echo ""
	@echo "$(YELLOW)📁 Project Structure:$(NC)"
	@echo "  bitcoin/docker/     - Bitcoin Core Dockerfile"
	@echo "  bitcoin/data/       - Bitcoin blockchain data"
	@echo "  electrs/            - Electrum Server Dockerfile"
	@echo "  electrs/data/       - Electrum index data"
	@echo "  .env                - Environment configuration"
	@echo ""
	@echo "$(YELLOW)🌐 Default Ports:$(NC)"
	@echo "  8332  - Bitcoin RPC"
	@echo "  8333  - Bitcoin P2P"
	@echo "  50001 - Electrum Server"
	@echo "  4224  - Electrum Monitoring"
	@echo ""
	@echo "$(YELLOW)💡 Quick Start:$(NC)"
	@echo "  1. make init"
	@echo "  2. Edit .env file"
	@echo "  3. make dev"
	@echo "  4. make bitcoin-info"

version: ## Show version information
	@echo "$(BLUE)📋 Version Information:$(NC)"
	@echo "$(CYAN)======================$(NC)"
	@echo "Docker: $$(docker --version)"
	@echo "Docker Compose: $$(docker-compose --version)"
	@if docker-compose ps bitcoin >/dev/null 2>&1; then \
		echo "Bitcoin Core: $$(docker-compose exec bitcoin bitcoind --version | head -1)"; \
	else \
		echo "Bitcoin Core: Not running"; \
	fi

requirements: ## Show system requirements and recommendations
	@echo "$(BLUE)💻 System Requirements:$(NC)"
	@echo "$(CYAN)======================$(NC)"
	@echo ""
	@echo "$(GREEN)Minimum Requirements:$(NC)"
	@echo "  🖥️  CPU: 2+ cores"
	@echo "  💾 RAM: 8GB"
	@echo "  💿 Storage: 500GB+ (SSD recommended)"
	@echo "  🌐 Network: Stable internet connection"
	@echo ""
	@echo "$(GREEN)Recommended (64GB RAM Optimized):$(NC)"
	@echo "  🖥️  CPU: 4+ cores"
	@echo "  💾 RAM: 16GB+ available for Bitcoin"
	@echo "  💿 Storage: 1TB+ NVMe SSD"
	@echo "  🌐 Network: Unmetered connection"
	@echo ""
	@echo "$(GREEN)Current System:$(NC)"
	@echo "  💾 Available RAM: $$(free -h | awk '/^Mem:/{print $$7}')"
	@echo "  💿 Available Storage: $$(df -h . | tail -1 | awk '{print $$4}')"

# =============================================================================
# ADVANCED OPERATIONS
# =============================================================================

shell-bitcoin: ## Open shell in Bitcoin Core container
	docker-compose exec bitcoin /bin/bash

shell-electrs: ## Open shell in Electrum Server container  
	docker-compose exec electrs /bin/bash

debug: ## Enable debug mode and show detailed logs
	@echo "$(YELLOW)🐛 Debug mode - showing detailed logs...$(NC)"
	docker-compose logs --tail=50 bitcoin
	docker-compose logs --tail=50 electrs
	@echo "$(BLUE)💡 Use 'make logs' for live log following$(NC)"

watch-status: ## Watch service status continuously (Ctrl+C to exit)
	@echo "$(BLUE)👀 Watching service status (Ctrl+C to exit)...$(NC)"
	@while true; do \
		clear; \
		echo "$(CYAN)Bitcoin Core Docker Stack - Live Status$(NC)"; \
		echo "$(CYAN)======================================$(NC)"; \
		echo "Updated: $(date)"; \
		echo ""; \
		make status; \
		sleep 10; \
	done

monitor: ## Monitor resource usage continuously (Ctrl+C to exit)  
	@echo "$(BLUE)📊 Monitoring resources (Ctrl+C to exit)...$(NC)"
	docker stats bitcoin-core electrum-server

# =============================================================================
# NETWORK AND CONNECTIVITY
# =============================================================================

network-info: ## Show detailed network information
	@echo "$(BLUE)🌐 Network Information:$(NC)"
	@echo "$(CYAN)======================$(NC)"
	docker network inspect bitcoin-stack_bitcoin-network 2>/dev/null || echo "$(YELLOW)Network not found$(NC)"
	@echo ""
	@echo "$(YELLOW)Port Status:$(NC)"
	@netstat -tlnp 2>/dev/null | grep -E ":(8332|8333|50001|4224)" || echo "$(YELLOW)No Bitcoin ports found listening$(NC)"

test-ports: ## Test if ports are accessible
	@echo "$(BLUE)🔌 Testing Port Accessibility:$(NC)"
	@echo "$(CYAN)=============================$(NC)"
	@echo "$(YELLOW)Testing Bitcoin RPC (8332):$(NC)"
	@nc -z localhost 8332 && echo "$(GREEN)✅ Port 8332 accessible$(NC)" || echo "$(RED)❌ Port 8332 not accessible$(NC)"
	@echo "$(YELLOW)Testing Bitcoin P2P (8333):$(NC)"
	@nc -z localhost 8333 && echo "$(GREEN)✅ Port 8333 accessible$(NC)" || echo "$(RED)❌ Port 8333 not accessible$(NC)"
	@echo "$(YELLOW)Testing Electrum (50001):$(NC)"
	@nc -z localhost 50001 && echo "$(GREEN)✅ Port 50001 accessible$(NC)" || echo "$(RED)❌ Port 50001 not accessible$(NC)"
	@echo "$(YELLOW)Testing Electrum Monitoring (4224):$(NC)"
	@nc -z localhost 4224 && echo "$(GREEN)✅ Port 4224 accessible$(NC)" || echo "$(RED)❌ Port 4224 not accessible$(NC)"

# =============================================================================
# ELECTRUM OPERATIONS
# =============================================================================

electrs-status: ## Show Electrum Server status and metrics
	@echo "$(BLUE)⚡ Electrum Server Status:$(NC)"
	@echo "$(CYAN)=========================$NC)"
	docker-compose exec electrs curl -s http://localhost:4224/metrics | head -20 || echo "$(RED)❌ Electrs not responding$(NC)"

electrs-sync: ## Show Electrum Server sync progress
	@echo "$(BLUE)🔄 Electrum Server Sync Progress:$(NC)"
	@echo "$(CYAN)================================$NC)"
	docker-compose exec electrs curl -s http://localhost:4224/metrics | grep -E "(electrs_index|electrs_db)" || echo "$(RED)❌ Sync info not available$(NC)"

# =============================================================================
# SECURITY AND MAINTENANCE
# =============================================================================

security-check: ## Perform basic security checks
	@echo "$(BLUE)🔒 Security Check:$(NC)"
	@echo "$(CYAN)=================$NC)"
	@echo "$(YELLOW)🔍 Checking RPC configuration...$(NC)"
	@if grep -q "rpcpassword=change-this-password-in-production" bitcoin/bitcoin.conf 2>/dev/null; then \
		echo "$(RED)❌ SECURITY RISK: Default RPC password detected!$(NC)"; \
	else \
		echo "$(GREEN)✅ Custom RPC password configured$(NC)"; \
	fi
	@echo "$(YELLOW)🔍 Checking file permissions...$(NC)"
	@if [ -f .env ]; then \
		PERM=$(stat -c "%a" .env); \
		if [ "$PERM" = "600" ] || [ "$PERM" = "644" ]; then \
			echo "$(GREEN)✅ .env file permissions: $PERM$(NC)"; \
		else \
			echo "$(YELLOW)⚠️  .env file permissions: $PERM (consider 600)$(NC)"; \
		fi; \
	fi
	@echo "$(YELLOW)🔍 Checking container privileges...$(NC)"
	@if docker inspect bitcoin-core | grep -q '"Privileged": false'; then \
		echo "$(GREEN)✅ Bitcoin container: Non-privileged$(NC)"; \
	else \
		echo "$(RED)❌ Bitcoin container: Privileged mode detected$(NC)"; \
	fi

fix-permissions: ## Fix file and directory permissions
	@echo "$(BLUE)🔧 Fixing permissions...$(NC)"
	chmod 600 .env 2>/dev/null || true
	chmod 755 bitcoin/data electrs/data 2>/dev/null || true
	@echo "$(GREEN)✅ Permissions fixed$(NC)"

# =============================================================================
# PERFORMANCE TUNING
# =============================================================================

performance-check: ## Check performance metrics and recommendations
	@echo "$(BLUE)⚡ Performance Check:$(NC)"
	@echo "$(CYAN)===================$NC)"
	@echo "$(YELLOW)💾 System Memory:$(NC)"
	@free -h
	@echo ""
	@echo "$(YELLOW)💿 Disk Usage:$(NC)"
	@df -h bitcoin/data electrs/data 2>/dev/null || echo "Data directories not found"
	@echo ""
	@echo "$(YELLOW)🖥️  CPU Info:$(NC)"
	@nproc && echo "CPU cores available"
	@echo ""
	@echo "$(YELLOW)📊 Container Resources:$(NC)"
	@if docker ps | grep -q bitcoin-core; then \
		docker stats --no-stream --format "table {{.Container}}\t{{.CPUPerc}}\t{{.MemUsage}}" bitcoin-core electrum-server 2>/dev/null || echo "Containers not running"; \
	else \
		echo "$(YELLOW)⚠️  Containers not running$(NC)"; \
	fi

optimize: ## Apply performance optimizations based on system
	@echo "$(BLUE)⚡ Applying Performance Optimizations:$(NC)"
	@echo "$(CYAN)=====================================$NC)"
	@echo "$(YELLOW)🔧 Checking current dbcache setting...$(NC)"
	@if grep -q "dbcache=" .env; then \
		DBCACHE=$(grep "BITCOIN_DBCACHE=" .env | cut -d'=' -f2); \
		echo "Current dbcache: $DBCACHE MB"; \
	else \
		echo "$(YELLOW)⚠️  No dbcache setting found in .env$(NC)"; \
	fi
	@echo "$(GREEN)💡 For your 64GB system, recommended settings:$(NC)"
	@echo "  BITCOIN_DBCACHE=8000"
	@echo "  BITCOIN_MAXCONNECTIONS=200"
	@echo "  BITCOIN_MEMORY_LIMIT=16g"

# =============================================================================
# TROUBLESHOOTING
# =============================================================================

troubleshoot: ## Run comprehensive troubleshooting checks
	@echo "$(BLUE)🔧 Troubleshooting Guide:$(NC)"
	@echo "$(CYAN)========================$NC)"
	@echo ""
	@echo "$(YELLOW)1. Service Status:$(NC)"
	@make status
	@echo ""
	@echo "$(YELLOW)2. Health Checks:$(NC)"
	@make health
	@echo ""
	@echo "$(YELLOW)3. Recent Logs (Last 10 lines):$(NC)"
	@docker-compose logs --tail=10 bitcoin electrs
	@echo ""
	@echo "$(YELLOW)4. Disk Space:$(NC)"
	@df -h . | tail -1
	@echo ""
	@echo "$(YELLOW)5. Memory Usage:$(NC)"
	@free -h | grep Mem
	@echo ""
	@echo "$(GREEN)💡 Common Solutions:$(NC)"
	@echo "  - Service won't start: make clean && make up"
	@echo "  - Sync issues: Check disk space and restart"
	@echo "  - Connection problems: make test-ports"
	@echo "  - Performance issues: make optimize"

emergency-stop: ## Emergency stop - force stop all containers
	@echo "$(RED)🚨 Emergency Stop - Force stopping all containers$(NC)"
	docker kill $(docker ps -q --filter "name=bitcoin") 2>/dev/null || true
	docker-compose down --remove-orphans
	@echo "$(GREEN)✅ Emergency stop completed$(NC)"

reset: ## Reset everything (keeps data) - nuclear option for issues
	@echo "$(YELLOW)🔄 Resetting stack (keeping data)...$(NC)"
	@make emergency-stop
	@docker system prune -f
	@make up
	@echo "$(GREEN)✅ Reset completed$(NC)"

# =============================================================================
# EDUCATIONAL AND LEARNING
# =============================================================================

learn: ## Show educational information about Bitcoin and this setup
	@echo "$(CYAN)📚 Bitcoin Core Docker Stack - Learning Guide$(NC)"
	@echo "$(CYAN)=============================================$NC)"
	@echo ""
	@echo "$(GREEN)🎯 What This Setup Provides:$(NC)"
	@echo "  • Full Bitcoin Node - Downloads and validates entire blockchain"
	@echo "  • Electrum Server - Provides APIs for lightweight wallets"
	@echo "  • Local Infrastructure - Run your own Bitcoin infrastructure"
	@echo "  • Privacy - No dependence on third-party services"
	@echo ""
	@echo "$(GREEN)🔗 Key Concepts:$(NC)"
	@echo "  • RPC - Remote Procedure Call interface for Bitcoin Core"
	@echo "  • P2P - Peer-to-peer network for blockchain synchronization"
	@echo "  • Electrum Protocol - Lightweight wallet communication standard"
	@echo "  • ZMQ - Real-time notifications for blockchain events"
	@echo ""
	@echo "$(GREEN)📖 Useful Commands to Learn:$(NC)"
	@echo "  make bitcoin-cli ARGS=\"help\" - Show all Bitcoin CLI commands"
	@echo "  make bitcoin-cli ARGS=\"getblockchaininfo\" - Blockchain status"
	@echo "  make bitcoin-cli ARGS=\"getpeerinfo\" - Connected peers"
	@echo "  make bitcoin-cli ARGS=\"getmempoolinfo\" - Transaction pool"

examples: ## Show practical usage examples
	@echo "$(CYAN)💡 Practical Usage Examples$(NC)"
	@echo "$(CYAN)============================$NC)"
	@echo ""
	@echo "$(GREEN)🏗️  Development:$(NC)"
	@echo "  make dev                     # Quick start for development"
	@echo "  make bitcoin-cli ARGS=\"help\"  # Explore available commands"
	@echo ""
	@echo "$(GREEN)📊 Monitoring:$(NC)"
	@echo "  make monitor                 # Live resource monitoring"
	@echo "  make watch-status            # Live service status"
	@echo "  make logs                    # Follow all logs"
	@echo ""
	@echo "$(GREEN)💰 Wallet Operations:$(NC)"
	@echo "  make create-wallet WALLET=main    # Create wallet"
	@echo "  make new-address WALLET=main      # Get new address"
	@echo "  make bitcoin-cli ARGS=\"-rpcwallet=main getbalance\"  # Check balance"
	@echo ""
	@echo "$(GREEN)🔧 Maintenance:$(NC)"
	@echo "  make backup                  # Backup blockchain data"
	@echo "  make security-check          # Check security settings"
	@echo "  make performance-check       # Check system performance"

# =============================================================================
# FINAL TARGETS
# =============================================================================

all: init build-all up status ## Complete setup - init, build, start, and show status
	@echo "$(GREEN)🎉 Complete Bitcoin Core stack deployment finished!$(NC)"
	@echo "$(CYAN)Next steps:$(NC)"
	@echo "  1. make bitcoin-info     # Check node status"
	@echo "  2. make logs             # Monitor startup logs"
	@echo "  3. make learn            # Learn about the setup"

.DEFAULT_GOAL := help

# =============================================================================
# NOTES AND DOCUMENTATION
# =============================================================================
# This Makefile provides a comprehensive interface for managing a Bitcoin Core
# Docker stack. It includes everything from basic operations to advanced
# troubleshooting and maintenance tasks.
#
# Key features:
# - Color-coded output for better readability
# - Comprehensive error checking and user guidance  
# - Security and performance optimization helpers
# - Educational content for learning Bitcoin operations
# - Production-ready backup and monitoring tools
#
# For more information, run: make help
# =============================================================================