#!/usr/bin/env bash
#
# Automation scripts for version management and changelog generation.
#

source "$(dirname "$0")/common.sh"

info "Executing the pipe..."

## Required parameters
ACCESS_TOKEN=${ACCESS_TOKEN:?'ACCESS_TOKEN variable missing.'}
BUMP_TYPE=${BUMP_TYPE:?'BUMP_TYPE variable missing.'}
#
## Default parameters
DEBUG=${DEBUG:="false"}

case "$BUMP_TYPE" in
  major)
    make release-major
    ;;
  minor)
    make release-minor
    ;;
  patch)
    make release-patch
    ;;
  *)
    echo "Invalid BUMP_TYPE: $BUMP_TYPE"
    echo "Valid values: major, minor, patch"
    exit 1
    ;;
esac

echo "hardcoded access_token"

git remote set-url origin "https://x-token-auth:${ACCESS_TOKEN}@bitbucket.org/${BITBUCKET_REPO_OWNER}/${BITBUCKET_REPO_SLUG}"
git push origin HEAD:$BITBUCKET_BRANCH
git push origin --tags

if [ "$BITBUCKET_EXIT_CODE" == "0" ]; then
  success "Success!"
else
  fail "Error!"
fi
