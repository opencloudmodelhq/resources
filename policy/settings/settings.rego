package settings

import rego.v1

deny contains "Actions: default GITHUB_TOKEN permission must be read" if {
	input.workflow_permissions.default_workflow_permissions != "read"
}

deny contains "Actions: workflows must not create or approve pull requests" if {
	input.workflow_permissions.can_approve_pull_request_reviews
}

deny contains "Actions: allowed actions must be 'selected', not 'all'" if {
	input.actions_permissions.allowed_actions == "all"
}

deny contains "Actions: full-SHA pinning must be required" if {
	not input.actions_permissions.sha_pinning_required
}

deny contains "Actions: fork pull request workflows must need approval for all external contributors" if {
	input.fork_pr_approval.approval_policy != "all_external_contributors"
}

warn contains "Actions: could not read the fork pull request approval policy; check Settings > Actions by hand" if {
	not input.fork_pr_approval.approval_policy
}

deny contains msg if {
	input.repo.visibility == "public"
	count(input.runners.runners) > 0
	msg := sprintf("Actions: %d self-hosted runner(s) registered on a public repository", [count(input.runners.runners)])
}

deny contains msg if {
	input.repo_secrets.total_count > 0
	msg := sprintf("Secrets: %d repository-level secret(s); keep secrets in protected environments", [input.repo_secrets.total_count])
}

deny contains msg if {
	some feature in ["secret_scanning", "secret_scanning_push_protection", "dependabot_security_updates"]
	input.repo.security_and_analysis[feature].status != "enabled"
	msg := sprintf("Security: %s must be enabled", [feature])
}

deny contains "Security: private vulnerability reporting must be enabled" if {
	not input.private_vulnerability_reporting.enabled
}

deny contains "Repository: merge commits must be disabled (linear history)" if {
	input.repo.allow_merge_commit
}

deny contains "Repository: head branches must be deleted on merge" if {
	not input.repo.delete_branch_on_merge
}

deny contains "Repository: web commit sign-off must be required" if {
	not input.repo.web_commit_signoff_required
}

deny contains "Rulesets: no active ruleset protects the default branch" if {
	not default_branch_protected
}

deny contains msg if {
	default_branch_protected
	some rule in required_branch_rules
	not rule in default_branch_rule_types
	msg := sprintf("Rulesets: the default-branch ruleset lacks %q", [rule])
}

deny contains "Rulesets: no active ruleset protects release tags" if {
	not tag_protected
}

required_branch_rules := {
	"deletion", "non_fast_forward", "required_linear_history",
	"required_signatures", "pull_request", "required_status_checks",
}

default_branch_rulesets contains ruleset if {
	some ruleset in input.rulesets
	ruleset.target == "branch"
	ruleset.enforcement == "active"
	some ref in ruleset.conditions.ref_name.include
	ref in {"~DEFAULT_BRANCH", sprintf("refs/heads/%s", [input.repo.default_branch])}
}

default_branch_protected if count(default_branch_rulesets) > 0

default_branch_rule_types contains rule.type if {
	some ruleset in default_branch_rulesets
	some rule in ruleset.rules
}

tag_protected if {
	some ruleset in input.rulesets
	ruleset.target == "tag"
	ruleset.enforcement == "active"
}

sections := ["repo", "workflow_permissions", "actions_permissions", "runners", "repo_secrets", "private_vulnerability_reporting", "rulesets"]

deny contains msg if {
	some section in sections
	not readable(section)
	msg := sprintf("Audit: could not read %s; the audit token may lack access", [section])
}

readable("rulesets") if is_array(input.rulesets)

readable(section) if {
	section != "rulesets"
	is_object(input[section])
}
