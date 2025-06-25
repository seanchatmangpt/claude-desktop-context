# CDCS Makefile v3.0 - SPR-Enhanced with 80/20 Focus
# Combines comprehensive functionality with ease of use

.DEFAULT_GOAL := help
SHELL := /bin/bash -o pipefail
.ONESHELL:

# Configuration
-include .env
CDCS_HOME ?= /Users/sac/claude-desktop-context
TIMESTAMP := $(shell date +%Y%m%d_%H%M%S)

# === DAILY ESSENTIALS (80/20 - Most Used) ===
.PHONY: help
help: ## Show this help message
	@echo "CDCS Command Interface - Essential Commands"
	@echo "=========================================="
	@echo "Quick commands:"
	@echo "  make         - Show this help"
	@echo "  make status  - Full system status"
	@echo "  make work    - Get AI work suggestions"
	@echo "  make dev     - Start development servers"
	@echo "  make save    - Save current session"
	@echo ""
	@echo "All commands:"
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "\033[36m%-20s\033[0m %s\n", $$1, $$2}'

.PHONY: status
status: ## Full system status check
	@echo "=== CDCS System Status ==="
	@./scripts/health_check_spr.sh 2>/dev/null || echo "Health check not available"
	@echo ""
	@echo "=== Active Session ==="
	@ls -la memory/sessions/current.link 2>/dev/null || echo "No active session"
	@echo ""
	@echo "=== SPR Kernels ==="
	@ls -la spr_kernels/*.spr 2>/dev/null | tail -5 || echo "No SPR kernels found"
	@echo ""
	@echo "=== Web UIs ==="
	@ps aux | grep -E "pnpm dev|nuxt" | grep -v grep || echo "No dev servers running"

.PHONY: work
work: ## Get AI work suggestions
	@./scripts/suggest_work_items_simple.sh 2>/dev/null || ./scripts/suggest_work_items.sh

.PHONY: save
save: ## Save current session (SPR + files)
	@echo "Saving session..."
	@./scripts/save_session.sh 2>/dev/null || echo "Session save not available"
	@./scripts/spr_generator.sh 2>/dev/null || echo "SPR generation not available"
	@echo "Session saved with timestamp: $(TIMESTAMP)"

# === DEVELOPMENT ===
.PHONY: dev
dev: ## Start all development servers
	@echo "Starting development servers..."
	@if [ -d "web-ui" ]; then cd web-ui && pnpm dev & fi
	@if [ -d "semantic-chat-ui" ]; then cd semantic-chat-ui && pnpm dev & fi
	@echo "Dev servers starting (check ports 3000, 3001)"

.PHONY: test
test: ## Run all tests
	@echo "Running tests..."
	@./scripts/test-cdcs-basic.sh 2>/dev/null || echo "Basic tests not available"
	@if [ -d "web-ui" ]; then cd web-ui && pnpm test 2>/dev/null || true; fi
	@if [ -d "semantic-chat-ui" ]; then cd semantic-chat-ui && pnpm test 2>/dev/null || true; fi

.PHONY: build
build: ## Build for production
	@echo "Building for production..."
	@if [ -d "web-ui" ]; then cd web-ui && pnpm build; fi
	@if [ -d "semantic-chat-ui" ]; then cd semantic-chat-ui && pnpm build; fi

.PHONY: lint
lint: ## Run linters
	@echo "Running linters..."
	@if [ -d "web-ui" ]; then cd web-ui && pnpm lint 2>/dev/null || true; fi
	@if [ -d "semantic-chat-ui" ]; then cd semantic-chat-ui && pnpm lint 2>/dev/null || true; fi

# === SPR MANAGEMENT ===
.PHONY: spr
spr: spr-generate spr-validate ## Full SPR cycle

.PHONY: spr-status
spr-status: ## Show SPR kernel status
	@echo "Active SPR Kernels:"
	@ls -la spr_kernels/*.spr 2>/dev/null || echo "No SPR kernels found"
	@echo "\nActivation Levels:"
	@cat spr_kernels/.activation_log 2>/dev/null || echo "No activation data"

.PHONY: spr-generate
spr-generate: ## Generate SPR from current session
	@echo "Generating SPR kernels..."
	@./scripts/spr_generator.sh 2>/dev/null || echo "SPR generator not available"

.PHONY: spr-validate
spr-validate: ## Verify SPR accuracy
	@echo "Validating SPR kernels..."
	@./scripts/validate_spr_accuracy.sh 2>/dev/null || echo "SPR validator not available"

.PHONY: spr-activate
spr-activate: ## Activate specific kernel (use KERNEL=name)
	@test -n "$(KERNEL)" || (echo "Error: KERNEL not specified. Use: make spr-activate KERNEL=pattern_recognition" && exit 1)
	@./scripts/activate_spr.sh $(KERNEL) 2>/dev/null || echo "SPR activation not available"

# === SYSTEM INTELLIGENCE ===
.PHONY: analyze
analyze: ## Analyze priorities
	@./scripts/analyze_priorities.sh 2>/dev/null || echo "Priority analysis not available"

.PHONY: predict
predict: ## Predict requirements
	@./scripts/predict_requirements.sh 2>/dev/null || echo "Prediction not available"

.PHONY: optimize
optimize: ## Optimize token usage
	@./scripts/optimize_token_usage.sh 2>/dev/null || echo "Optimization not available"

# === AUTOMATION ===
.PHONY: auto
auto: ## Start autonomous loop
	@echo "Starting autonomous operations..."
	@./automation/autonomous_loop.sh 2>/dev/null || echo "Autonomous loop not available"

.PHONY: cron
cron: ## Setup automation cron
	@./automation/setup_cron.sh 2>/dev/null || echo "Cron setup not available"

.PHONY: cron-stop
cron-stop: ## Stop automation cron
	@./automation/disable_cron.sh 2>/dev/null || echo "Cron disable not available"

# === MEMORY & SESSION ===
.PHONY: recover
recover: ## Recover last session
	@echo "Recovering session..."
	@./scripts/recover_session_spr.sh 2>/dev/null || echo "Session recovery not available"

.PHONY: compress
compress: ## Compress memory archives
	@./scripts/compress_memory.sh 2>/dev/null || echo "Memory compression not available"

.PHONY: extract
extract: ## Extract patterns to SPR
	@./scripts/extract_patterns.sh 2>/dev/null || echo "Pattern extraction not available"

# === MONITORING ===
.PHONY: trace
trace: ## Start trace monitoring (continuous)
	@echo "Starting continuous trace monitor (Ctrl+C to stop)..."
	@./telemetry/trace_monitor.sh 2>/dev/null || echo "Trace monitor not available"

.PHONY: dashboard
dashboard: ## Open metrics dashboard
	@./telemetry/claude_dashboard.sh 2>/dev/null || echo "Dashboard not available"

.PHONY: bench
bench: ## Benchmark SPR performance
	@./scripts/benchmark_spr_performance.sh 2>/dev/null || echo "Benchmark not available"

# === SYSTEM MANAGEMENT ===
.PHONY: setup
setup: ## Initial system setup
	@echo "Setting up CDCS..."
	@mkdir -p spr_kernels memory/sessions/active patterns scripts telemetry automation
	@chmod +x scripts/*.sh 2>/dev/null || true
	@chmod +x automation/*.sh 2>/dev/null || true
	@chmod +x telemetry/*.sh 2>/dev/null || true
	@./setup_unified_system.sh 2>/dev/null || echo "Unified setup not available"
	@echo "CDCS setup complete"

.PHONY: update
update: ## Update all dependencies
	@echo "Updating dependencies..."
	@if [ -d "web-ui" ]; then cd web-ui && pnpm update; fi
	@if [ -d "semantic-chat-ui" ]; then cd semantic-chat-ui && pnpm update; fi
	@if [ -f "automation/requirements.txt" ]; then cd automation && pip install -r requirements.txt --upgrade; fi

.PHONY: clean
clean: ## Clean build artifacts
	@echo "Cleaning build artifacts..."
	@rm -rf web-ui/dist web-ui/.nuxt semantic-chat-ui/dist semantic-chat-ui/.nuxt
	@find . -name "*.pyc" -delete
	@find . -name "__pycache__" -delete
	@find . -name "*.tmp" -delete
	@echo "Clean complete"

.PHONY: reset
reset: ## Reset to clean state (preserves code)
	@echo "Resetting system state..."
	@rm -f memory/sessions/current.link
	@rm -f spr_kernels/.activation_log
	@echo "System reset complete"

# === COMPOSITE COMMANDS (One-word actions) ===
.PHONY: morning
morning: status work ## Morning startup routine

.PHONY: evening
evening: save spr trace ## Evening shutdown routine

.PHONY: refresh
refresh: save recover status ## Quick refresh cycle

.PHONY: think
think: analyze predict work ## AI thinking pipeline

.PHONY: focus
focus: spr analyze optimize ## Focus using SPR

.PHONY: check
check: ## Health check with metrics
	@make -s status
	@echo ""
	@./telemetry/trace_monitor_quick.sh 2>/dev/null || echo "Quick trace not available"
	@echo ""
	@./scripts/benchmark_spr_performance.sh 2>/dev/null || echo "Benchmark not available"

.PHONY: start
start: setup dev auto trace ## Start everything

.PHONY: stop
stop: save cron-stop ## Stop and save everything

# === QUICK FIXES ===
.PHONY: fix
fix: ## Auto-fix common issues
	@echo "Checking and fixing common issues..."
	@./scripts/restore-otelcol.sh 2>/dev/null || true
	@./scripts/git-push-readiness-check.sh 2>/dev/null || true
	@chmod +x scripts/*.sh 2>/dev/null || true
	@echo "Common issues checked"

.PHONY: fix-perms
fix-perms: ## Fix file permissions
	@find scripts -name "*.sh" -exec chmod +x {} \;
	@find automation -name "*.sh" -exec chmod +x {} \;
	@find telemetry -name "*.sh" -exec chmod +x {} \;
	@echo "Permissions fixed"

# === COORDINATION ===
.PHONY: bridge
bridge: ## Start CDCS-XAVOS bridge
	@./cdcs_xavos_bridge.sh 2>/dev/null || echo "Bridge not available"

.PHONY: coord
coord: ## Coordinate systems
	@./coordination_helper_v3.sh 2>/dev/null || echo "Coordination not available"

# === ADVANCED ===
.PHONY: evolve
evolve: ## Trigger SPR evolution
	@./scripts/evolve_sprs.sh 2>/dev/null || echo "Evolution not available"

.PHONY: self-improve
self-improve: ## Self-improvement cycle
	@./scripts/self_improvement.sh 2>/dev/null || echo "Self-improvement not available"

# === GAP FILLING (D-99 BLIND SPOT COMPENSATION) ===
.PHONY: gap-setup
gap-setup: ## Setup automated blind spot compensation
	@echo "Setting up D-99 blind spot compensation..."
	@./automation/setup_gap_filling.sh

.PHONY: gap-status
gap-status: ## Check gap-filling system status
	@echo "🛡️ Gap-Filling Status"
	@echo "===================="
	@echo -n "Detail Guardian: "
	@test -f automation/detail_guardian.db && echo "✅ Active" || echo "❌ Not initialized"
	@echo -n "Perspective Seeker: "
	@test -f automation/perspectives.db && echo "✅ Active" || echo "❌ Not initialized"
	@echo -n "Boundary Keeper: "
	@test -f automation/boundaries.db && echo "✅ Active" || echo "❌ Not initialized"
	@echo -n "Process Capturer: "
	@test -f automation/processes.db && echo "✅ Active" || echo "❌ Not initialized"
	@echo -n "Relationship Nurser: "
	@test -f automation/relationships.db && echo "✅ Active" || echo "❌ Not initialized"

.PHONY: gap-run
gap-run: ## Run all gap-filling agents now
	@echo "Running all gap-filling agents..."
	@python3 automation/agents/gap_fillers/detail_guardian.py &
	@python3 automation/agents/gap_fillers/perspective_seeker.py &
	@python3 automation/agents/gap_fillers/boundary_keeper.py &
	@python3 automation/agents/gap_fillers/process_capturer.py &
	@python3 automation/agents/gap_fillers/relationship_nurser.py &
	@wait
	@echo "✅ All agents completed"

.PHONY: gap-dash
gap-dash: ## Open all gap-filling dashboards
	@open automation/detail_dashboard.html 2>/dev/null || echo "Run 'make gap-run' first"
	@open automation/boundary_dashboard.html 2>/dev/null || true
	@open automation/relationship_dashboard.html 2>/dev/null || true
	@open automation/process_library.html 2>/dev/null || true

.PHONY: detail
detail: ## Check for missed details
	@python3 automation/agents/gap_fillers/detail_guardian.py

.PHONY: perspective
perspective: ## Analyze decisions from multiple viewpoints
	@python3 automation/agents/gap_fillers/perspective_seeker.py

.PHONY: boundary
boundary: ## Check authority boundaries
	@python3 automation/agents/gap_fillers/boundary_keeper.py

.PHONY: process
process: ## Auto-document recent processes
	@python3 automation/agents/gap_fillers/process_capturer.py

.PHONY: relate
relate: ## Check relationship health
	@python3 automation/agents/gap_fillers/relationship_nurser.py

# === INFO ===
.PHONY: version
version: ## Show version info
	@cat manifest.yaml | grep version || echo "v3.0.0"

.PHONY: which
which: ## Show which scripts exist
	@echo "Available scripts:"
	@ls scripts/*.sh 2>/dev/null | wc -l | xargs echo "  Shell scripts:"
	@ls automation/*.py 2>/dev/null | wc -l | xargs echo "  Python scripts:"
	@ls telemetry/*.sh 2>/dev/null | wc -l | xargs echo "  Telemetry scripts:"

# === EMERGENCY ===
.PHONY: panic
panic: ## Emergency save and shutdown
	@echo "EMERGENCY SHUTDOWN"
	@make save
	@make stop
	@echo "Emergency shutdown complete"

.PHONY: recover-panic
recover-panic: ## Recover from panic
	@echo "Recovering from emergency..."
	@make fix
	@make recover
	@make status

# === CONCURRENT OPERATIONS ===
.PHONY: turbo
turbo: ## Maximum parallel execution
	@echo "🚀 Turbo mode - Maximum concurrency"
	@$(MAKE) -j8 turbo-analyze turbo-optimize turbo-validate turbo-bench

.PHONY: turbo-analyze
turbo-analyze:
	@./scripts/analyze_priorities.sh 2>/dev/null &
	@./scripts/predict_requirements.sh 2>/dev/null &
	@./scripts/suggest_work_items_simple.sh 2>/dev/null &
	@wait

.PHONY: turbo-optimize
turbo-optimize:
	@./scripts/optimize_token_usage.sh 2>/dev/null &
	@./scripts/spr_generator.sh 2>/dev/null &
	@./scripts/extract_patterns.sh 2>/dev/null &
	@wait

.PHONY: turbo-validate
turbo-validate:
	@./scripts/validate_spr_accuracy.sh 2>/dev/null &
	@./scripts/health_check_spr.sh 2>/dev/null &
	@./scripts/test-cdcs-basic.sh 2>/dev/null &
	@wait

.PHONY: turbo-bench
turbo-bench:
	@./scripts/benchmark_spr_performance.sh 2>/dev/null &
	@./telemetry/trace_monitor_quick.sh 2>/dev/null &
	@wait

.PHONY: parallel-test
parallel-test: ## Run all tests in parallel
	@echo "Running parallel tests..."
	@$(MAKE) -j4 test-spr test-patterns test-memory test-telemetry

.PHONY: test-spr
test-spr:
	@echo "Testing SPR..." && ./scripts/validate_spr_accuracy.sh 2>/dev/null || true

.PHONY: test-patterns  
test-patterns:
	@echo "Testing patterns..." && ls patterns/catalog/*.yaml 2>/dev/null | wc -l | xargs echo "Pattern files:"

.PHONY: test-memory
test-memory:
	@echo "Testing memory..." && ls memory/sessions/active/*.md 2>/dev/null | wc -l | xargs echo "Active sessions:"

.PHONY: test-telemetry
test-telemetry:
	@echo "Testing telemetry..." && pgrep -f otelcol > /dev/null && echo "✅ OTel running" || echo "❌ OTel not running"

# Prevent parallel execution for critical targets
.NOTPARALLEL: save recover reset panic