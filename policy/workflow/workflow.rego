package workflow

import rego.v1

privileged_triggers := {"pull_request_target", "workflow_run", "issue_comment"}

untrusted_contexts := [
	"github.event.pull_request.title",
	"github.event.pull_request.body",
	"github.event.pull_request.head.ref",
	"github.event.pull_request.head.label",
	"github.event.issue.title",
	"github.event.issue.body",
	"github.event.comment.body",
	"github.event.review.body",
	"github.event.review_comment.body",
	"github.event.head_commit.message",
	"github.event.head_commit.author",
	"github.event.commits",
	"github.event.discussion.title",
	"github.event.discussion.body",
	"github.head_ref",
]

triggers contains name if {
	is_string(input.on)
	name := input.on
}

triggers contains name if {
	is_array(input.on)
	some name in input.on
}

triggers contains name if {
	is_object(input.on)
	some name, _ in input.on
}

steps contains [job_id, step] if {
	some job_id, job in input.jobs
	some step in job.steps
}

deny contains msg if {
	some name in triggers
	name in privileged_triggers
	msg := sprintf("trigger %q runs with base-repository privileges; use pull_request instead", [name])
}

deny contains "workflow must set top-level permissions (use {} and grant per job)" if {
	not "permissions" in object.keys(input)
}

deny contains "top-level permissions must be {} or read-only" if {
	is_object(input.permissions)
	some _, level in input.permissions
	level == "write"
}

deny contains "top-level permissions must not be write-all" if {
	input.permissions == "write-all"
}

deny contains msg if {
	some [job_id, step] in steps
	uses := step.uses
	not local_or_docker(uses)
	not pinned(uses)
	msg := sprintf("job %q: %q is not pinned to a full commit SHA", [job_id, uses])
}

deny contains msg if {
	some job_id, job in input.jobs
	uses := job.uses
	not local_or_docker(uses)
	not pinned(uses)
	msg := sprintf("job %q: reusable workflow %q is not pinned to a full commit SHA", [job_id, uses])
}

deny contains msg if {
	some [job_id, step] in steps
	some context in untrusted_contexts
	contains(step.run, context)
	msg := sprintf("job %q: run step interpolates untrusted %q; pass it through env instead", [job_id, context])
}

deny contains msg if {
	some job_id, job in input.jobs
	self_hosted(job["runs-on"])
	msg := sprintf("job %q: self-hosted runners are not allowed on public repositories", [job_id])
}

deny contains msg if {
	some job_id, job in input.jobs
	job.secrets == "inherit"
	msg := sprintf("job %q: secrets: inherit passes every secret; name the ones needed", [job_id])
}

deny contains msg if {
	some [job_id, step] in steps
	step["with"]["allow-unsafe-pr-checkout"]
	msg := sprintf("job %q: allow-unsafe-pr-checkout checks out untrusted code", [job_id])
}

deny contains msg if {
	some [job_id, step] in steps
	startswith(step.uses, "actions/checkout@")
	not step["with"]["persist-credentials"] == false
	msg := sprintf("job %q: actions/checkout must set persist-credentials: false", [job_id])
}

deny contains msg if {
	some job_id, job in input.jobs
	uses_secret(job)
	not job.environment
	msg := sprintf("job %q: uses a secret outside a protected environment", [job_id])
}

deny contains msg if {
	some job_id, job in input.jobs
	job.permissions["id-token"] == "write"
	not job.environment
	not oidc_publisher(job)
	msg := sprintf("job %q: id-token: write is only allowed in a job with a protected environment", [job_id])
}

deny contains msg if {
	some job_id, job in input.jobs
	not job["timeout-minutes"]
	not job.uses
	msg := sprintf("job %q: set timeout-minutes", [job_id])
}

deny contains msg if {
	some [job_id, step] in steps
	regex.match(`\b(terraform|tofu)\s+apply\b`, step.run)
	msg := sprintf("job %q: workflows must never apply infrastructure", [job_id])
}

pinned(uses) if regex.match(`@[0-9a-f]{40}$`, uses)

local_or_docker(uses) if startswith(uses, "./")

local_or_docker(uses) if startswith(uses, "docker://")

self_hosted(runs_on) if runs_on == "self-hosted"

self_hosted(runs_on) if {
	is_array(runs_on)
	"self-hosted" in runs_on
}

uses_secret(job) if {
	some value in walk_strings(job)
	regex.match(`\$\{\{\s*secrets\.(?:[A-Za-z_][A-Za-z0-9_]*)\s*\}\}`, value)
	not regex.match(`^\s*\$\{\{\s*secrets\.GITHUB_TOKEN\s*\}\}\s*$`, value)
}

walk_strings(value) := [s | walk(value, [_, s]); is_string(s)]

oidc_publisher(job) if {
	some step in job.steps
	startswith(step.uses, "ossf/scorecard-action@")
}

deny contains msg if {
	some job_id, job in input.jobs
	some step in job.steps
	regex.match(`(^|[^|])\|([^|]|$)`, step.run)
	not bash_shell(job, step)
	msg := sprintf("job %q: a piped run step needs shell: bash so pipefail stops on failure", [job_id])
}

bash_shell(_, step) if step.shell == "bash"

bash_shell(job, _) if job.defaults.run.shell == "bash"

bash_shell(_, _) if input.defaults.run.shell == "bash"

deny contains msg if {
	some [job_id, step] in steps
	startswith(step.uses, "actions/create-github-app-token@")
	stated := [name | some name, _ in object.get(step, "with", {}); startswith(name, "permission-")]
	count(stated) == 0
	msg := sprintf("job %q: an App token must state its permissions with permission-<name> inputs", [job_id])
}

deny contains msg if {
	some [job_id, step] in steps
	publishes_findings(step.run)
	msg := sprintf("job %q: settings audit findings must not be posted to an issue or printed to the log", [job_id])
}

publishes_findings(run) if regex.match(`--body-file\s+findings`, run)

publishes_findings(run) if {
	contains(run, "settings.json")
	regex.match(`\|\s*tee\b`, run)
}
