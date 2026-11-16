#!/usr/bin/env bash
# Usage: export-settings.sh OWNER/REPO > settings.json
# Read-only. Needs a token with administration:read on the repository (gh auth or GH_TOKEN).
# A section that cannot be read is exported as null, and the settings policy fails on it.
set -euo pipefail

repo="${1:?usage: export-settings.sh OWNER/REPO}"

get() {
  local body
  if body=$(gh api -H "Accept: application/vnd.github+json" -H "X-GitHub-Api-Version: 2022-11-28" "$1" 2>/dev/null); then
    printf '%s' "${body}"
  else
    printf '%s' "${2:-null}"
  fi
}

rulesets() {
  local ids
  local listing
  listing=$(get "repos/${repo}/rulesets?includes_parents=true&per_page=100")
  if [[ "${listing}" == "null" ]]; then
    printf 'null'
    return
  fi
  ids=$(jq -r '.[].id' <<<"${listing}")
  printf '['
  local first=1
  for id in ${ids}; do
    [[ ${first} -eq 1 ]] || printf ','
    first=0
    get "repos/${repo}/rulesets/${id}"
  done
  printf ']'
}

jq -n \
  --argjson repo "$(get "repos/${repo}")" \
  --argjson actions_permissions "$(get "repos/${repo}/actions/permissions")" \
  --argjson workflow_permissions "$(get "repos/${repo}/actions/permissions/workflow")" \
  --argjson fork_pr_approval "$(get "repos/${repo}/actions/permissions/fork-pr-contributor-approval" '{}')" \
  --argjson runners "$(get "repos/${repo}/actions/runners")" \
  --argjson repo_secrets "$(get "repos/${repo}/actions/secrets")" \
  --argjson private_vulnerability_reporting "$(get "repos/${repo}/private-vulnerability-reporting")" \
  --argjson rulesets "$(rulesets)" \
  '$ARGS.named'
