#!/bin/bash

set -e

# Cores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Função para exibir mensagens
log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_step() {
    echo -e "${BLUE}[STEP]${NC} $1"
}

# Verifica se o tipo de bump foi fornecido
if [ -z "$1" ]; then
    log_error "Usage: $0 <major|minor|patch>"
    echo ""
    echo "Examples:"
    echo "  $0 major   # 1.2.3 -> 2.0.0"
    echo "  $0 minor   # 1.2.3 -> 1.3.0"
    echo "  $0 patch   # 1.2.3 -> 1.2.4"
    exit 1
fi

BUMP_TYPE="$1"

# Valida o tipo de bump
if [[ ! "$BUMP_TYPE" =~ ^(major|minor|patch)$ ]]; then
    log_error "Invalid bump type: $BUMP_TYPE"
    log_info "Valid types are: major, minor, patch"
    exit 1
fi

log_step "Fetching latest tags from remote..."
git fetch --tags 2>/dev/null || true

log_step "Finding latest version tag..."

# Obtém a tag de maior versão (ignora tags com sufixos como -rc, -beta, etc)
LATEST_TAG=$(git tag --sort=-v:refname | grep -E '^[0-9]+\.[0-9]+\.[0-9]+$' | head -n 1)

if [ -z "$LATEST_TAG" ]; then
    log_warning "No version tags found. Starting from 0.0.0"
    LATEST_TAG="0.0.0"
fi

log_info "Current version: $LATEST_TAG"

# Parse version components
if [[ $LATEST_TAG =~ ^([0-9]+)\.([0-9]+)\.([0-9]+)$ ]]; then
    MAJOR="${BASH_REMATCH[1]}"
    MINOR="${BASH_REMATCH[2]}"
    PATCH="${BASH_REMATCH[3]}"
else
    log_error "Invalid version format: $LATEST_TAG"
    exit 1
fi

# Calculate new version based on bump type
case "$BUMP_TYPE" in
    major)
        NEW_MAJOR=$((MAJOR + 1))
        NEW_MINOR=0
        NEW_PATCH=0
        ;;
    minor)
        NEW_MAJOR=$MAJOR
        NEW_MINOR=$((MINOR + 1))
        NEW_PATCH=0
        ;;
    patch)
        NEW_MAJOR=$MAJOR
        NEW_MINOR=$MINOR
        NEW_PATCH=$((PATCH + 1))
        ;;
esac

NEW_VERSION="${NEW_MAJOR}.${NEW_MINOR}.${NEW_PATCH}"

log_step "Bumping version: $LATEST_TAG -> $NEW_VERSION (${BUMP_TYPE})"

echo ""
log_info "New version will be: ${GREEN}${NEW_VERSION}${NC}"
echo ""

# Output the new version (can be captured by caller)
echo "$NEW_VERSION"
