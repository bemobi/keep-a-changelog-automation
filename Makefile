.PHONY: help version-major version-minor version-patch changelog-update changelog-unreleased release-major release-minor release-patch

# Colors
GREEN  := \033[0;32m
YELLOW := \033[1;33m
BLUE   := \033[0;34m
NC     := \033[0m # No Color

help: ## Show this help message
	@echo "$(BLUE)Available targets:$(NC)"
	@echo ""
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | awk 'BEGIN {FS = ":.*?## "}; {printf "  $(GREEN)%-20s$(NC) %s\n", $$1, $$2}'
	@echo ""
	@echo "$(YELLOW)Examples:$(NC)"
	@echo "  make release-patch    # Bump patch version, update changelog, commit and tag"
	@echo "  make release-minor    # Bump minor version, update changelog, commit and tag"
	@echo "  make release-major    # Bump major version, update changelog, commit and tag"
	@echo "  make changelog-unreleased  # Update [Unreleased] section only"

version-major: ## Calculate next major version
	@./scripts/bump-version.sh major

version-minor: ## Calculate next minor version
	@./scripts/bump-version.sh minor

version-patch: ## Calculate next patch version
	@./scripts/bump-version.sh patch

changelog-update: ## Update changelog with specific version (requires VERSION env var)
	@if [ -z "$(VERSION)" ]; then \
		echo "[ERROR] VERSION variable is required"; \
		echo "Usage: make changelog-update VERSION=1.2.3"; \
		exit 1; \
	fi
	@./scripts/update-changelog.sh $(VERSION)

changelog-unreleased: ## Update [Unreleased] section with current branch commits
	@echo "[INFO] Updating [Unreleased] section..."
	@./scripts/update-changelog.sh

release-major: ## Bump MAJOR version and update changelog (X.0.0)
	@echo "========================================"
	@echo "  MAJOR Release (X.0.0)"
	@echo "========================================"
	@echo ""
	@NEW_VERSION=$$(./scripts/bump-version.sh major | tail -1); \
	echo "[INFO] New version: $$NEW_VERSION"; \
	echo ""; \
	echo "[STEP 1/3] Updating CHANGELOG.md..."; \
	./scripts/update-changelog.sh $$NEW_VERSION; \
	echo ""; \
	echo "[STEP 2/3] Committing changes..."; \
	git add CHANGELOG.md; \
	git commit -m "chore: release version $$NEW_VERSION [skip ci]" || echo "[WARNING] No changes to commit"; \
	echo ""; \
	echo "[STEP 3/3] Creating tag..."; \
	git tag -a $$NEW_VERSION -m "Release version $$NEW_VERSION"; \
	echo ""; \
	echo "✓ Release $$NEW_VERSION created successfully!"; \
	echo ""; \
	echo "Next steps:"; \
	echo "  git push origin $$(git rev-parse --abbrev-ref HEAD)"; \
	echo "  git push origin $$NEW_VERSION"

release-minor: ## Bump MINOR version and update changelog (x.Y.0)
	@echo "========================================"
	@echo "  MINOR Release (x.Y.0)"
	@echo "========================================"
	@echo ""
	@NEW_VERSION=$$(./scripts/bump-version.sh minor | tail -1); \
	echo "[INFO] New version: $$NEW_VERSION"; \
	echo ""; \
	echo "[STEP 1/3] Updating CHANGELOG.md..."; \
	./scripts/update-changelog.sh $$NEW_VERSION; \
	echo ""; \
	echo "[STEP 2/3] Committing changes..."; \
	git add CHANGELOG.md; \
	git commit -m "chore: release version $$NEW_VERSION [skip ci]" || echo "[WARNING] No changes to commit"; \
	echo ""; \
	echo "[STEP 3/3] Creating tag..."; \
	git tag -a $$NEW_VERSION -m "Release version $$NEW_VERSION"; \
	echo ""; \
	echo "✓ Release $$NEW_VERSION created successfully!"; \
	echo ""; \
	echo "Next steps:"; \
	echo "  git push origin $$(git rev-parse --abbrev-ref HEAD)"; \
	echo "  git push origin $$NEW_VERSION"

release-patch: ## Bump PATCH version and update changelog (x.y.Z)
	@echo "========================================"
	@echo "  PATCH Release (x.y.Z)"
	@echo "========================================"
	@echo ""
	@NEW_VERSION=$$(./scripts/bump-version.sh patch | tail -1); \
	echo "[INFO] New version: $$NEW_VERSION"; \
	echo ""; \
	echo "[STEP 1/3] Updating CHANGELOG.md..."; \
	./scripts/update-changelog.sh $$NEW_VERSION; \
	echo ""; \
	echo "[STEP 2/3] Committing changes..."; \
	git add CHANGELOG.md; \
	git commit -m "chore: release version $$NEW_VERSION [skip ci]" || echo "[WARNING] No changes to commit"; \
	echo ""; \
	echo "[STEP 3/3] Creating tag..."; \
	git tag -a $$NEW_VERSION -m "Release version $$NEW_VERSION"; \
	echo ""; \
	echo "✓ Release $$NEW_VERSION created successfully!"; \
	echo ""; \
	echo "Next steps:"; \
	echo "  git push origin $$(git rev-parse --abbrev-ref HEAD)"; \
	echo "  git push origin $$NEW_VERSION"
