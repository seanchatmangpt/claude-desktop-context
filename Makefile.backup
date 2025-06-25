# CDCS Makefile - SPR-Enhanced Autonomous Operations
# Core principle: SPR-first, file-second operations for 80%+ efficiency

.PHONY: help
help: ## Show this help message
	@echo "CDCS Autonomous Command Interface"
	@echo "================================="
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "\033[36m%-20s\033[0m %s\n", $$1, $$2}'

# === SPR Management ===
.PHONY: spr-status
spr-status: ## Show active SPR kernels and activation levels
	@echo "Active SPR Kernels:"
	@ls -la spr_kernels/*.spr 2>/dev/null || echo "No SPR kernels found"
	@echo "\nActivation Levels:"
	@cat spr_kernels/.activation_log 2>/dev/null || echo "No activation data"

.PHONY: spr-generate
spr-generate: ## Generate SPR from current session
	@echo "Generating SPR kernels from active session..."
	@./scripts/spr_generator.sh

.PHONY: spr-activate
spr-activate: ## Prime latent space with specific kernel
	@echo "Activating SPR kernel: $(KERNEL)"
	@test -n "$(KERNEL)" || (echo "Error: KERNEL not specified. Use: make spr-activate KERNEL=pattern_recognition" && exit 1)
	@./scripts/activate_spr.sh $(KERNEL)

.PHONY: spr-validate
spr-validate: ## Verify SPR accuracy against files
	@echo "Validating SPR kernels..."
	@./scripts/validate_sprs.sh

.PHONY: spr-evolve
spr-evolve: ## Trigger fitness-based SPR mutations
	@echo "Initiating SPR evolution cycle..."
	@./scripts/evolve_sprs.sh

# === System Intelligence ===
.PHONY: analyze-focus
analyze-focus: ## AI-driven priority detection using SPR graph
	@echo "Analyzing focus areas..."
	@./scripts/analyze_priorities.sh

.PHONY: suggest-work
suggest-work: ## Pattern-based work item generation
	@echo "Generating work suggestions from patterns..."
	@./scripts/suggest_work_items.sh

.PHONY: optimize-tokens
optimize-tokens: ## SPR-guided token allocation
	@echo "Optimizing token allocation..."
	@./scripts/optimize_token_usage.sh

.PHONY: predict-needs
predict-needs: ## Anticipate user requirements from patterns
	@echo "Predicting user needs..."
	@./scripts/predict_requirements.sh

.PHONY: self-improve
self-improve: ## Initiate autonomous enhancement cycle
	@echo "Starting self-improvement cycle..."
	@./scripts/self_improvement.sh

# === Memory & Session ===
.PHONY: session-save
session-save: ## Persist current state (files + SPR)
	@echo "Saving session state..."
	@./scripts/save_session.sh

.PHONY: session-recover
session-recover: ## SPR-first recovery with selective file loading
	@echo "Recovering session..."
	@./scripts/recover_session_spr.sh

.PHONY: memory-compress
memory-compress: ## Apply semantic compression to archives
	@echo "Compressing memory archives..."
	@./scripts/compress_memory.sh

.PHONY: pattern-extract
pattern-extract: ## Convert discoveries to SPR kernels
	@echo "Extracting patterns to SPR..."
	@./scripts/extract_patterns.sh

.PHONY: context-prime
context-prime: ## Activate relevant conceptual anchors
	@echo "Priming context..."
	@./scripts/prime_context.sh

# === Coordination ===
.PHONY: claim-work
claim-work: ## Atomic work claim with SPR context
	@echo "Claiming work item..."
	@./scripts/claim_work_atomic.sh

.PHONY: complete-work
complete-work: ## Update both CDCS patterns and SPR graph
	@echo "Completing work item..."
	@./scripts/complete_work.sh

.PHONY: sync-systems
sync-systems: ## Coordinate CDCS-XAVOS if available
	@echo "Synchronizing systems..."
	@./scripts/sync_cdcs_xavos.sh

.PHONY: agent-spawn
agent-spawn: ## Create specialized agent with SPR priming
	@echo "Spawning agent with SPR context..."
	@./scripts/spawn_agent_spr.sh

.PHONY: coordinate-agents
coordinate-agents: ## Nanosecond-precision multi-agent orchestration
	@echo "Coordinating agents..."
	@./scripts/coordinate_agents_nano.sh

# === Quality Assurance ===
.PHONY: verify-spr
verify-spr: ## Anti-hallucination check against files
	@echo "Verifying SPR accuracy..."
	@./scripts/validate_spr_accuracy.sh

.PHONY: test-patterns
test-patterns: ## Validate pattern graph connections
	@echo "Testing pattern connections..."
	@./scripts/test_pattern_graph.sh

.PHONY: benchmark-efficiency
benchmark-efficiency: ## Measure SPR vs file-only performance
	@echo "Benchmarking efficiency..."
	@./scripts/benchmark_spr_performance.sh

.PHONY: trace-operations
trace-operations: ## OpenTelemetry monitoring
	@echo "Tracing operations..."
	@./scripts/trace_with_otel.sh

.PHONY: health-check
health-check: ## System-wide health with SPR metrics
	@echo "Running health check..."
	@./scripts/health_check_spr.sh

# === Autonomous Operations ===
.PHONY: auto-focus
auto-focus: ## Select focus area using AI analysis
	@make analyze-focus
	@make suggest-work
	@make claim-work

.PHONY: auto-improve
auto-improve: ## Continuous improvement cycle
	@make benchmark-efficiency
	@make spr-evolve
	@make verify-spr

.PHONY: auto-predict
auto-predict: ## Predictive assistance workflow
	@make predict-needs
	@make context-prime
	@make spr-activate KERNEL=predicted_needs

.PHONY: auto-recover
auto-recover: ## Autonomous session recovery
	@make session-recover
	@make context-prime
	@make spr-status

.PHONY: auto-prioritize
auto-prioritize: ## Intelligent work prioritization
	@make analyze-focus
	@make pattern-extract
	@make suggest-work

.PHONY: auto-optimize
auto-optimize: ## Self-optimization cycle
	@make benchmark-efficiency
	@make optimize-tokens
	@make self-improve

# === Emergency Protocols ===
.PHONY: fallback-files
fallback-files: ## Revert to file-based operation
	@echo "WARNING: Falling back to file-only mode"
	@touch .spr_disabled
	@echo "SPR disabled. Remove .spr_disabled to re-enable"

.PHONY: rollback-safe
rollback-safe: ## Revert to last known good state
	@echo "Rolling back to safe state..."
	@./scripts/rollback_to_safe.sh

# === Setup & Initialization ===
.PHONY: setup
setup: ## Initialize CDCS with SPR support
	@echo "Setting up CDCS with SPR enhancement..."
	@mkdir -p spr_kernels memory/sessions/active patterns scripts
	@chmod +x scripts/*.sh 2>/dev/null || true
	@echo "CDCS SPR system initialized"

.PHONY: clean
clean: ## Clean temporary files (preserves SPRs)
	@echo "Cleaning temporary files..."
	@rm -f .activation_log .spr_disabled
	@find . -name "*.tmp" -delete

.PHONY: reset
reset: ## Full reset (WARNING: removes all data)
	@echo "WARNING: This will remove all CDCS data!"
	@echo "Press Ctrl+C to cancel, or wait 5 seconds..."
	@sleep 5
	@rm -rf spr_kernels memory patterns
	@echo "CDCS reset complete"

# === Composite Commands ===
.PHONY: status
status: spr-status health-check ## Show full system status

.PHONY: work
work: auto-prioritize claim-work ## Start working on highest priority

.PHONY: save
save: session-save spr-generate pattern-extract ## Save everything

.PHONY: boot
boot: setup context-prime spr-status ## Boot CDCS system

# Default target
.DEFAULT_GOAL := help