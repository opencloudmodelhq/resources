package settings_test

import rego.v1

import data.settings

rules(types) := [{"type": t} | some t in types]

good := {
	"repo": {
		"visibility": "public",
		"default_branch": "main",
		"allow_merge_commit": false,
		"delete_branch_on_merge": true,
		"web_commit_signoff_required": true,
		"security_and_analysis": {
			"secret_scanning": {"status": "enabled"},
			"secret_scanning_push_protection": {"status": "enabled"},
			"dependabot_security_updates": {"status": "enabled"},
		},
	},
	"workflow_permissions": {"default_workflow_permissions": "read", "can_approve_pull_request_reviews": false},
	"actions_permissions": {"enabled": true, "allowed_actions": "selected", "sha_pinning_required": true},
	"fork_pr_approval": {"approval_policy": "all_external_contributors"},
	"runners": {"total_count": 0, "runners": []},
	"repo_secrets": {"total_count": 0},
	"private_vulnerability_reporting": {"enabled": true},
	"rulesets": [
		{
			"target": "branch", "enforcement": "active",
			"conditions": {"ref_name": {"include": ["~DEFAULT_BRANCH"]}},
			"rules": rules(["deletion", "non_fast_forward", "required_linear_history", "required_signatures", "pull_request", "required_status_checks"]),
		},
		{"target": "tag", "enforcement": "active", "conditions": {"ref_name": {"include": ["refs/tags/v*"]}}, "rules": rules(["creation", "update", "deletion"])},
	],
}

test_a_locked_down_repository_passes if {
	count(settings.deny) == 0 with input as good
}

test_a_writable_default_token_is_denied if {
	"Actions: default GITHUB_TOKEN permission must be read" in settings.deny with input as object.union(good, {"workflow_permissions": {"default_workflow_permissions": "write"}})
}

test_fork_workflows_without_approval_are_denied if {
	some msg in settings.deny with input as object.union(good, {"fork_pr_approval": {"approval_policy": "first_time_contributors"}})
	contains(msg, "fork pull request")
}

test_a_repository_secret_is_denied if {
	some msg in settings.deny with input as object.union(good, {"repo_secrets": {"total_count": 1}})
	contains(msg, "repository-level secret")
}

test_a_self_hosted_runner_on_a_public_repository_is_denied if {
	some msg in settings.deny with input as object.union(good, {"runners": {"total_count": 1, "runners": [{"name": "laptop"}]}})
	contains(msg, "self-hosted")
}

test_push_protection_off_is_denied if {
	off := {"repo": {"security_and_analysis": {"secret_scanning_push_protection": {"status": "disabled"}}}}
	"Security: secret_scanning_push_protection must be enabled" in settings.deny with input as object.union(good, off)
}

test_a_missing_default_branch_ruleset_is_denied if {
	"Rulesets: no active ruleset protects the default branch" in settings.deny with input as object.union(object.remove(good, ["rulesets"]), {"rulesets": [good.rulesets[1]]})
}

test_a_ruleset_without_signed_commits_is_named if {
	weak := object.union(good.rulesets[0], {"rules": rules(["deletion", "non_fast_forward", "required_linear_history", "pull_request", "required_status_checks"])})
	some msg in settings.deny with input as object.union(object.remove(good, ["rulesets"]), {"rulesets": [weak, good.rulesets[1]]})
	contains(msg, "required_signatures")
}

test_an_evaluate_only_ruleset_does_not_count if {
	evaluate := object.union(good.rulesets[0], {"enforcement": "evaluate"})
	"Rulesets: no active ruleset protects the default branch" in settings.deny with input as object.union(object.remove(good, ["rulesets"]), {"rulesets": [evaluate, good.rulesets[1]]})
}

test_missing_tag_protection_is_denied if {
	"Rulesets: no active ruleset protects release tags" in settings.deny with input as object.union(object.remove(good, ["rulesets"]), {"rulesets": [good.rulesets[0]]})
}

test_an_unreadable_fork_policy_warns if {
	some msg in settings.warn with input as object.union(object.remove(good, ["fork_pr_approval"]), {"fork_pr_approval": {}})
	contains(msg, "check Settings")
}

test_no_ruleset_reports_once if {
	count({m | some m in settings.deny; contains(m, "Rulesets: the default-branch")}) == 0 with input as object.union(object.remove(good, ["rulesets"]), {"rulesets": []})
}

test_an_unreadable_section_fails_closed if {
	every section in ["repo", "workflow_permissions", "actions_permissions", "runners", "repo_secrets", "private_vulnerability_reporting", "rulesets"] {
		broken := object.union(object.remove(good, [section]), {section: null})
		msg := sprintf("Audit: could not read %s; the audit token may lack access", [section])
		msg in settings.deny with input as broken
	}
}

test_every_unreadable_section_is_named if {
	broken := {"repo": null, "workflow_permissions": null, "actions_permissions": null, "runners": null, "repo_secrets": null, "private_vulnerability_reporting": null, "rulesets": null}
	count({m | some m in settings.deny; startswith(m, "Audit: could not read")}) == 7 with input as broken
}
