package workflow_test

import rego.v1

import data.workflow

sha := "3d3c42e5aac5ba805825da76410c181273ba90b1"

good := {
	"on": {"pull_request": {}, "push": {"branches": ["main"]}},
	"permissions": {},
	"jobs": {"test": {
		"runs-on": "ubuntu-latest",
		"timeout-minutes": 10,
		"permissions": {"contents": "read"},
		"steps": [
			{"uses": sprintf("actions/checkout@%s", [sha]), "with": {"persist-credentials": false}},
			{"run": "make check", "env": {"TITLE": "${{ github.event.pull_request.title }}"}},
		],
	}},
}

with_job(field, value) := object.union(good, {"jobs": {"test": object.union(good.jobs.test, {field: value})}})

with_step(step) := with_job("steps", [step])

test_a_sound_workflow_passes if {
	count(workflow.deny) == 0 with input as good
}

test_pull_request_target_is_denied if {
	some msg in workflow.deny with input as object.union(good, {"on": {"pull_request_target": {}}})
	contains(msg, "pull_request_target")
}

test_workflow_run_as_a_list_trigger_is_denied if {
	some msg in workflow.deny with input as object.union(good, {"on": ["workflow_run"]})
	contains(msg, "workflow_run")
}

test_missing_top_level_permissions_is_denied if {
	"workflow must set top-level permissions (use {} and grant per job)" in workflow.deny with input as object.remove(good, ["permissions"])
}

test_write_permission_at_top_level_is_denied if {
	"top-level permissions must be {} or read-only" in workflow.deny with input as object.union(good, {"permissions": {"contents": "write"}})
}

test_a_tag_pin_is_denied if {
	some msg in workflow.deny with input as with_step({"uses": "actions/checkout@v7", "with": {"persist-credentials": false}})
	contains(msg, "not pinned")
}

test_a_local_action_needs_no_pin if {
	count(workflow.deny) == 0 with input as with_step({"uses": "./.github/actions/setup"})
}

test_untrusted_context_in_run_is_denied if {
	some msg in workflow.deny with input as with_step({"run": "echo \"${{ github.event.pull_request.title }}\""})
	contains(msg, "untrusted")
}

test_head_ref_in_run_is_denied if {
	some msg in workflow.deny with input as with_step({"run": "git checkout ${{ github.head_ref }}"})
	contains(msg, "github.head_ref")
}

test_self_hosted_runner_is_denied if {
	some msg in workflow.deny with input as with_job("runs-on", ["self-hosted", "linux"])
	contains(msg, "self-hosted")
}

test_secrets_inherit_is_denied if {
	some msg in workflow.deny with input as object.union(good, {"jobs": {"call": {"uses": sprintf("org/repo/.github/workflows/x.yml@%s", [sha]), "secrets": "inherit"}}})
	contains(msg, "secrets: inherit")
}

test_unsafe_pr_checkout_is_denied if {
	step := {"uses": sprintf("actions/checkout@%s", [sha]), "with": {"persist-credentials": false, "allow-unsafe-pr-checkout": true}}
	some msg in workflow.deny with input as with_step(step)
	contains(msg, "allow-unsafe-pr-checkout")
}

test_checkout_that_keeps_credentials_is_denied if {
	some msg in workflow.deny with input as with_step({"uses": sprintf("actions/checkout@%s", [sha])})
	contains(msg, "persist-credentials")
}

test_a_secret_outside_an_environment_is_denied if {
	some msg in workflow.deny with input as with_step({"run": "make release", "env": {"KEY": "${{ secrets.GPG_PRIVATE_KEY }}"}})
	contains(msg, "outside a protected environment")
}

test_a_secret_inside_an_environment_is_allowed if {
	job := object.union(good.jobs.test, {"environment": "release", "steps": [{"run": "make release", "env": {"KEY": "${{ secrets.GPG_PRIVATE_KEY }}"}}]})
	count(workflow.deny) == 0 with input as object.union(good, {"jobs": {"test": job}})
}

test_the_github_token_needs_no_environment if {
	count(workflow.deny) == 0 with input as with_step({"run": "gh pr view", "env": {"GH_TOKEN": "${{ secrets.GITHUB_TOKEN }}"}})
}

test_id_token_write_outside_an_environment_is_denied if {
	some msg in workflow.deny with input as with_job("permissions", {"id-token": "write"})
	contains(msg, "id-token")
}

test_a_job_without_a_timeout_is_denied if {
	some msg in workflow.deny with input as object.union(object.remove(good, ["jobs"]), {"jobs": {"test": object.remove(good.jobs.test, ["timeout-minutes"])}})
	contains(msg, "timeout-minutes")
}

test_infrastructure_apply_is_denied if {
	some msg in workflow.deny with input as with_step({"run": "tofu apply -auto-approve"})
	contains(msg, "never apply")
}

test_scorecard_may_publish_with_an_oidc_token if {
	step := {"uses": "ossf/scorecard-action@fa7117db83c52d787ae5a89f350999701505d78e"}
	job := object.union(good.jobs.test, {"permissions": {"id-token": "write"}, "steps": [step]})
	count(workflow.deny) == 0 with input as object.union(object.remove(good, ["jobs"]), {"jobs": {"test": job}})
}

test_a_pipe_without_bash_is_denied if {
	some msg in workflow.deny with input as with_step({"run": "conftest test x | tee out.txt"})
	contains(msg, "pipefail")
}

test_a_pipe_with_bash_at_workflow_level_is_allowed if {
	step := {"run": "conftest test x | tee out.txt"}
	count(workflow.deny) == 0 with input as object.union(with_step(step), {"defaults": {"run": {"shell": "bash"}}})
}

test_a_logical_or_is_not_a_pipe if {
	count(workflow.deny) == 0 with input as with_step({"run": "make check || exit 1"})
}

app_token(inputs) := with_step({
	"uses": sprintf("actions/create-github-app-token@%s", [sha]),
	"with": object.union({"app-id": "1", "private-key": "k"}, inputs),
})

test_an_app_token_without_stated_permissions_is_denied if {
	some msg in workflow.deny with input as app_token({})
	contains(msg, "permission-")
}

test_an_app_token_with_stated_permissions_passes if {
	count(workflow.deny) == 0 with input as app_token({"permission-administration": "read"})
}

bash_defaults := {"defaults": {"run": {"shell": "bash"}}}

test_posting_audit_findings_to_an_issue_is_denied if {
	step := {"run": "gh issue create --title drift --body-file findings.txt"}
	some msg in workflow.deny with input as with_step(step)
	contains(msg, "audit findings")
}

test_printing_audit_findings_to_the_log_is_denied if {
	step := {"run": "conftest test --policy policy/settings settings.json | tee findings.txt"}
	some msg in workflow.deny with input as object.union(with_step(step), bash_defaults)
	contains(msg, "audit findings")
}

test_a_notice_without_findings_is_allowed if {
	step := {"run": "gh issue create --title drift --body-file notice.md"}
	count(workflow.deny) == 0 with input as with_step(step)
}
