.PHONY: help build test clean run docker-build docker-up docker-down lint fmt

# Variables
GO := go
DOCKER := docker
DOCKER_COMPOSE := docker-compose
API_IMAGE := agentguard/api:latest
DASHBOARD_IMAGE := agentguard/dashboard:latest

help: ## Show this help message
	@echo 'Usage: make [target]'
	@echo ''
	@echo 'Targets:'
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "  %-20s %s\n", $$1, $$2}'

# Development
dev: ## Run all services in development mode
	$(DOCKER_COMPOSE) up -d

dev-logs: ## View logs from all services
	$(DOCKER_COMPOSE) logs -f

dev-down: ## Stop all development services
	$(DOCKER_COMPOSE) down

dev-clean: ## Stop all services and remove volumes
	$(DOCKER_COMPOSE) down -v

# Backend
build: ## Build the API binary
	$(GO) build -o bin/api ./cmd/api

run: ## Run the API server
	$(GO) run ./cmd/api/main.go

test: ## Run all tests
	$(GO) test -v -cover ./...

test-watch: ## Run tests in watch mode
	$(GO) test -v -cover ./... -run TestAll

lint: ## Run linter
	$(GO) fmt ./...
	$(GO) vet ./...

fmt: ## Format code
	$(GO) fmt ./...
	$(GO) mod tidy

# Frontend
dashboard-install: ## Install dashboard dependencies
	cd dashboard && npm install

dashboard-dev: ## Run dashboard in development mode
	cd dashboard && npm run dev

dashboard-build: ## Build dashboard for production
	cd dashboard && npm run build

dashboard-test: ## Run dashboard tests
	cd dashboard && npm test

dashboard-lint: ## Lint dashboard code
	cd dashboard && npm run lint

# Docker
docker-build: ## Build Docker images
	$(DOCKER) build -f Dockerfile.api -t $(API_IMAGE) .
	$(DOCKER) build -f Dockerfile.dashboard -t $(DASHBOARD_IMAGE) .

docker-build-api: ## Build API Docker image
	$(DOCKER) build -f Dockerfile.api -t $(API_IMAGE) .

docker-build-dashboard: ## Build dashboard Docker image
	$(DOCKER) build -f Dockerfile.dashboard -t $(DASHBOARD_IMAGE) .

docker-push: ## Push Docker images to registry
	$(DOCKER) push $(API_IMAGE)
	$(DOCKER) push $(DASHBOARD_IMAGE)

# Kubernetes
k8s-install: ## Install AgentGuard in Kubernetes
	kubectl apply -f k8s/crd-agentpolicy.yaml
	kubectl apply -f k8s/crd-agentapproval.yaml
	kubectl apply -f k8s/crd-agentbudget.yaml
	kubectl apply -f k8s/deployment-api.yaml
	kubectl apply -f k8s/deployment-dashboard.yaml

k8s-uninstall: ## Uninstall AgentGuard from Kubernetes
	kubectl delete -f k8s/deployment-api.yaml
	kubectl delete -f k8s/deployment-dashboard.yaml
	kubectl delete -f k8s/crd-agentpolicy.yaml
	kubectl delete -f k8s/crd-agentapproval.yaml
	kubectl delete -f k8s/crd-agentbudget.yaml

k8s-logs: ## View Kubernetes logs
	kubectl logs -n agentguard-system -f deployment/agentguard-api

k8s-dashboard-port-forward: ## Port forward to dashboard
	kubectl port-forward -n agentguard-system svc/agentguard-dashboard 3000:3000

# Cleanup
clean: ## Clean build artifacts
	rm -rf bin/
	$(GO) clean

clean-all: ## Clean everything including Docker volumes
	$(DOCKER_COMPOSE) down -v
	rm -rf bin/
	$(GO) clean

# Code generation
generate: ## Generate code
	$(GO) generate ./...

# Database
db-migrate: ## Run database migrations
	$(GO) run ./cmd/migrate/main.go

db-seed: ## Seed database with test data
	$(GO) run ./cmd/seed/main.go

# Utilities
version: ## Show version information
	$(GO) version
	$(DOCKER) version
	node --version

check: fmt lint test ## Run fmt, lint, and tests

all: clean build test docker-build ## Clean, build, test, and create Docker images