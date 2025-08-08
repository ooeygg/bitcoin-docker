# Secure Mining Pool Stack Makefile
# - Works with either `docker compose` or `docker-compose`
# - Locks RPC to internal network; exposes only P2P + TLS frontends via Traefik
# - Adds health checks, TLS/cert helpers, and quick miner tests

# ==============================
# Compose binary autodetect
# ==============================
COMPOSE := $(shell command -v docker-compose >/dev/null 2>&1 && echo docker-compose || echo docker compose)

# ==============================
# Colors
# ==============================
RED=\033[0;31m
GREEN=\033[0;32m
YELLOW=\033[1;33m
BLUE=\033[0;34m
CYAN=\033[0;36m
NC=\033[0m

# ==============================
# Helpers
# ==============================
DOTENV := .env
REQUIRED_ENV := TRAEFIK_ACME_EMAIL POOL_API_DOMAIN POOL_STRATUM_DOMAIN FRACTAL_RPC_USER FRACTAL_RPC_PASSWORD BITCOIN_RPC_USER BITCOIN_RPC_PASSWORD
SHELL := /bin/bash

define check-env
	@missing=""; \
	for v in $(REQUIRED_ENV); do \
		if ! grep -Eq "^$${v}=" $(DOTENV) 2>/dev/null; then missing="$$missing $$v"; fi; \
	done; \
	if [ -n "$$missing" ]; then \
		echo -e "$(RED)❌ Missing required vars in $(DOTENV):$$missing$(NC)"; \
		echo -e "$(YELLOW)Edit .env and set them, then re-run.$(NC)"; \
		exit 1; \
	else \
		echo -e "$(GREEN)✅ .env looks good$(NC)"; \
	fi
endef

# ==============================
# Default
# ==============================
.PHONY: help
help:
	@echo -e "$(CYAN)Secure Mining Pool Stack$(NC)"
	@echo -e "$(CYAN)========================$(NC)"
	@echo -e "$(GREEN)Quick start:$(NC)  make init && make up && make status"
	@echo ""
	@echo -e "$(GREEN)Core:$(NC)"
	@echo "  make init            # create dirs, sanity checks"
	@echo "  make build           # build all images"
	@echo "  make up              # start entire stack"
	@echo "  make down            # stop stack"
	@echo "  make restart         # restart stack"
	@echo "  make status          # container status"
	@echo "  make logs            # follow all logs"
	@echo ""
	@echo -e "$(GREEN)Health & Info:$(NC)"
	@echo "  make health          # daemon & pool health probes"
	@echo "  make bitcoin-info    # bitcoin -getinfo"
	@echo "  make fractal-info    # fractal -getinfo"
	@echo "  make zmq-check       # show ZMQ notifications"
	@echo ""
	@echo -e "$(GREEN)TLS & DNS:$(NC)"
	@echo "  make dns-check       # confirm DNS A records"
	@echo "  make api-check       # HTTPS API probe via Traefik"
	@echo "  make stratum-check   # TLS handshake test on 3335"
	@echo "  make cert-dump       # show issued certs (acme.json)"
	@echo ""
	@echo -e "$(GREEN)Troubleshooting:$(NC)"
	@echo "  make logs-pool       # public-pool logs"
	@echo "  make logs-traefik    # traefik logs"
	@echo "  make shell-bitcoin   # bash into bitcoin container"
	@echo "  make shell-fractal   # bash into fractal container"
	@echo "  make shell-pool      # sh into pool container"

# ==============================
# Init & Build
# ==============================
.PHONY: init
init:
	@echo -e "$(BLUE)🔧 Initializing project...$(NC)"
	@mkdir -p bitcoin/data fractal-bitcoin/data
	@chmod 755 bitcoin/data fractal-bitcoin/data 2>/dev/null || true
	@if [ ! -f $(DOTENV) ]; then \
		echo -e "$(YELLOW)⚠️  Creating .env from .env.example (if present)$(NC)"; \
		[ -f .env.example ] && cp .env.example .env || touch .env; \
	fi
	$(call check-env)
	@echo -e "$(GREEN)✅ Init complete$(NC)"

.PHONY: build
build:
	$(COMPOSE) build

.PHONY: rebuild
rebuild:
	$(COMPOSE) build --no-cache

# ==============================
# Orchestration
# ==============================
.PHONY: up down restart status logs
up: init
	$(COMPOSE) up -d

down:
	$(COMPOSE) down

restart:
	$(COMPOSE) down
	$(COMPOSE) up -d

status:
	$(COMPOSE) ps

logs:
	$(COMPOSE) logs -f

# ==============================
# Service-specific logs & shells
# ==============================
.PHONY: logs-bitcoin logs-fractal logs-pool logs-traefik shell-bitcoin shell-fractal shell-pool
logs-bitcoin: ; $(COMPOSE) logs -f bitcoin
logs-fractal: ; $(COMPOSE) logs -f fractal-bitcoin
logs-pool:    ; $(COMPOSE) logs -f public-pool-fb
logs-traefik: ; $(COMPOSE) logs -f traefik

shell-bitcoin: ; $(COMPOSE) exec bitcoin /bin/bash
shell-fractal: ; $(COMPOSE) exec fractal-bitcoin /bin/bash
shell-pool:    ; $(COMPOSE) exec public-pool-fb sh

# ==============================
# Node Info / Health
# ==============================
.PHONY: bitcoin-info fractal-info zmq-check health getblockcount-fractal
bitcoin-info:
	@echo -e "$(BLUE)📊 Bitcoin Core -getinfo$(NC)"
	@export $$(grep -E '^BITCOIN_RPC_(USER|PASSWORD)=' .env | xargs); \
	$(COMPOSE) exec bitcoin bitcoin-cli -datadir=/data -rpcuser="$$BITCOIN_RPC_USER" -rpcpassword="$$BITCOIN_RPC_PASSWORD" -getinfo

fractal-info:
	@echo -e "$(BLUE)📊 Fractal Bitcoin -getinfo$(NC)"
	@export $$(grep -E '^FRACTAL_RPC_(USER|PASSWORD)=' .env | xargs); \
	$(COMPOSE) exec fractal-bitcoin bitcoin-cli -datadir=/data -rpcport=8434 -rpcuser="$$FRACTAL_RPC_USER" -rpcpassword="$$FRACTAL_RPC_PASSWORD" -getinfo

getblockcount-fractal:
	@export $$(grep -E '^FRACTAL_RPC_(USER|PASSWORD)=' .env | xargs); \
	$(COMPOSE) exec fractal-bitcoin bitcoin-cli -datadir=/data -rpcport=8434 -rpcuser="$$FRACTAL_RPC_USER" -rpcpassword="$$FRACTAL_RPC_PASSWORD" getblockcount

zmq-check:
	@export $$(grep -E '^FRACTAL_RPC_(USER|PASSWORD)=' .env | xargs); \
	$(COMPOSE) exec fractal-bitcoin sh -lc 'bitcoin-cli -datadir=/data -rpcport=8434 -rpcuser=$$FRACTAL_RPC_USER -rpcpassword=$$FRACTAL_RPC_PASSWORD getzmqnotifications'

health:
	@echo -e "$(BLUE)🏥 Health Checks$(NC)"
	@echo -e "$(YELLOW)• Fractal RPC$(NC)"
	@export $$(grep -E '^FRACTAL_RPC_(USER|PASSWORD)=' .env | xargs); \
	$(COMPOSE) exec fractal-bitcoin sh -lc 'bitcoin-cli -datadir=/data -rpcport=8434 -rpcuser=$$FRACTAL_RPC_USER -rpcpassword=$$FRACTAL_RPC_PASSWORD getrpcinfo >/dev/null && echo "$(GREEN)OK$(NC)" || echo "$(RED)FAIL$(NC)"'
	@echo -e "$(YELLOW)• Public-Pool process$(NC)"
	@$(COMPOSE) exec public-pool-fb sh -lc 'ps aux | grep -v grep | grep -q node && echo "$(GREEN)OK$(NC)" || echo "$(RED)FAIL$(NC)"'
	@echo -e "$(YELLOW)• Traefik up$(NC)"
	@$(COMPOSE) ps traefik 2>/dev/null | grep -q Up && echo "$(GREEN)OK$(NC)" || echo "$(RED)FAIL$(NC)"

# ==============================
# TLS / DNS / Connectivity
# ==============================
.PHONY: dns-check api-check stratum-check cert-dump
dns-check:
	@echo -e "$(BLUE)🌐 DNS check$(NC)"
	@set -e; \
	source ./.env; \
	{ command -v dig >/dev/null 2>&1 && dig +short $$POOL_API_DOMAIN; } || getent hosts $$POOL_API_DOMAIN | awk '{print $$1}'; \
	{ command -v dig >/dev/null 2>&1 && dig +short $$POOL_STRATUM_DOMAIN; } || getent hosts $$POOL_STRATUM_DOMAIN | awk '{print $$1}'

api-check:
	@echo -e "$(BLUE)🔒 HTTPS API probe$(NC)"
	@source ./.env; \
	curl -sSIk https://$$POOL_API_DOMAIN/ | sed -n '1,10p'

stratum-check:
	@echo -e "$(BLUE)🔒 Stratum TLS handshake (3335)$(NC)"
	@source ./.env; \
	( echo | openssl s_client -connect $$POOL_STRATUM_DOMAIN:3335 -servername $$POOL_STRATUM_DOMAIN ) 2>/dev/null | \
	grep -E 'subject=|issuer=|Verify return code' || true

cert-dump:
	@echo -e "$(BLUE)📜 Dumping ACME cert metadata (traefik)$(NC)"
	@$(COMPOSE) exec traefik sh -lc 'apk add --no-cache jq >/dev/null 2>&1 || true; [ -f /letsencrypt/acme.json ] && jq ". | {Accounts: .accounts | length, Certs: (.certificates | length)}" /letsencrypt/acme.json || echo "acme.json not ready yet"'

# ==============================
# Security helpers
# ==============================
.PHONY: security-check show-config
security-check:
	@echo -e "$(BLUE)🔒 Security review$(NC)"
	@grep -E "^BITCOIN_RPC_PASSWORD=|^FRACTAL_RPC_PASSWORD=" .env >/dev/null 2>&1 && echo -e "$(GREEN)✅ RPC passwords set$(NC)" || echo -e "$(RED)❌ RPC passwords missing$(NC)"
	@echo -e "$(YELLOW)• Ensure router forwards ONLY: 80, 443, 3335, 8333, 8435$(NC)"
	@echo -e "$(YELLOW)• Keep 8332/8434 closed to internet$(NC)"

show-config:
	@echo -e "$(BLUE)⚙️  Sanitized env$(NC)"
	@sed -E 's/(PASSWORD=).*/\1***HIDDEN***/; s/(TOKEN=).*/\1***HIDDEN***/' .env | grep -E "^[A-Z0-9_]+=.*" | sort

# ==============================
# Miner convenience
# ==============================
.PHONY: miner-url
miner-url:
	@source ./.env; \
	echo -e "$(GREEN)Use this in your miner UI:$(NC)  stratum+ssl://$$POOL_STRATUM_DOMAIN:3335"
	@echo "Worker/Username: <FB_ADDRESS>.rig1"
	@echo "Password: x"

# ==============================
# Cleanup
# ==============================
.PHONY: clean clean-data
clean:
	@echo -e "$(YELLOW)🧹 Cleaning containers & networks (data preserved)$(NC)"
	$(COMPOSE) down -v --remove-orphans || true

clean-data:
	@echo -e "$(RED)⚠️  This will DELETE blockchain data (full resync required)!$(NC)"
	@read -p "Type DELETE to confirm: " c; \
	if [ "$$c" = "DELETE" ]; then \
		$(COMPOSE) down -v; \
		sudo rm -rf bitcoin/data/* fractal-bitcoin/data/* || true; \
		echo -e "$(GREEN)✅ Data removed$(NC)"; \
	else \
		echo -e "$(GREEN)✅ Cancelled$(NC)"; \
	fi
