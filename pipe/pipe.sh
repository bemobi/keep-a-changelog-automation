#!/usr/bin/env bash
#
# Automation scripts for version management and changelog generation.
#

source "$(dirname "$0")/common.sh"

info "Executing the pipe..."

## Required parameters
CLIENT_KEY=${CLIENT_KEY:?'CLIENT_KEY variable missing.'}
SECRET_KEY=${SECRET_KEY:?'SECRET_KEY variable missing.'}
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

#export access_token=$(curl -s -X POST -u "${CLIENT_ID}:${CLIENT_SECRET}" \
#  https://bitbucket.org/site/oauth2/access_token \
#  -d grant_type=client_credentials -d scopes="repository"| jq --raw-output '.access_token')
#git remote set-url origin "https://x-token-auth:${access_token}@bitbucket.org/${BITBUCKET_REPO_OWNER}/${BITBUCKET_REPO_SLUG}"
#git push origin HEAD:$BITBUCKET_BRANCH
#git push origin --tags

if [[ "${status}" == "0" ]]; then
  success "Success!"
else
  fail "Error!"
fi
