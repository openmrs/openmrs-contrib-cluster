---
name: pr-review
description: Review any pull request in openmrs-contrib-cluster — Helm charts, Kubernetes manifests, Terraform/HCL, GitHub Actions, shell scripts, dependency/version bumps, and docs — with empirical verification and clearly-labeled review comments, then either post them inline on GitHub or stage them as a pending draft review the user finishes in the GitHub UI. Reviews each PR on its own terms: version upgrades, gateway/routing changes, new charts, infra changes, CI changes, whatever the work is. Use when asked to review a PR, post review findings, or stage them for approval. Trigger phrases include "@claude review", "review PR", "review this pull request", "post review comments", "stage review comments".
argument-hint: <pr-number-or-url> [--post|--stage]
version: 1.0.0
---

# PR review — verified, infra-aware findings for openmrs-contrib-cluster

Arguments: `$ARGUMENTS` — a PR number or URL (if omitted, run `gh pr list` and ask which one), plus optionally one of `--post` (publish the review to the PR after composing it) or `--stage` (create it on GitHub as a **pending draft review** — nothing reaches the author until the user submits it from the GitHub UI). With neither flag, present the full review in conversation and offer to post or stage. If both are passed, stage — it's the reversible reading of an ambiguous ask. **In the CI `@claude review` path there is no interactive user to finish a draft, so CI always posts inline (never stages); `--stage` is for interactive/local runs only.** Step 4 owns the semantics and mechanics.

This repo is Kubernetes infrastructure-as-code: Helm charts (`helm/`), Terraform (`terraform/`), GitHub Actions (`.github/workflows/`), and shell scripts. A PR here can be almost anything — a subchart or image **version bump**, a **gateway/routing** change, a **new chart**, a **Terraform** change, a **CI** change, a script fix, a values tweak, or docs. Review each on its own terms: first work out *what kind of change this is*, then apply the matching lens, and always trace outward — in infra the failure usually lands in a resource the diff never touched. Your job is to find the real problems and post them as inline review comments, the way a careful senior engineer would.

Be a generalist. The concrete checklists below name failures known to matter in this repo; they are a **floor, not a ceiling**. When a PR touches something not listed, apply the same discipline — read the whole file, `git grep` outward, verify external behavior against authoritative source — rather than concluding "not on the list, so it's fine."

## CI runtime constraints

This skill usually runs in CI via a reusable workflow defined outside this repo (`openmrs/openmrs-contrib-gha-workflows`), so don't trust a hardcoded description of what's installed — **check at the start of every review**:

```
for t in helm terraform kubectl kubeconform yq yamllint jq; do command -v "$t" >/dev/null 2>&1 && echo "$t: present" || echo "$t: absent"; done
```

As of this writing that reusable workflow grants `Bash, Read, Grep, Glob, mcp__github_inline_comment__create_inline_comment`, denies `Write, Edit` (you cannot modify files), sets `GH_TOKEN` so `gh api` works, and runs with `contents: read`. If a tool call you expect (e.g. the inline-comment MCP tool) isn't available, fall back to the `gh api` payload method in Step 4 rather than stalling.

- **Read-only in spirit regardless of what's installed:** never execute the repository's own code — no `make`, no `helm install`, no running any script or binary from the tree, even if it happens to be available. Your own read-only tooling (git, gh, curl, python, and `helm template`/`helm lint`/`terraform validate`/`terraform plan` specifically because they're read-only) is fine.

## Step 1 — Gather

- `gh pr view <n> --json title,body,author,baseRefName,headRefName,state,isDraft,additions,deletions,changedFiles,mergeable,mergeStateStatus,statusCheckRollup,url,createdAt`
- `gh pr diff <n>` for the full diff.
- Fetch the branch locally: `git fetch origin <base> 'pull/<n>/head:pr-<n>'` then `git diff origin/<base>...pr-<n> --stat`.
- Check for branch drift: `git diff origin/<base> pr-<n> --stat` vs the three-dot form — if they differ, the branch is behind base; note it and review the merged result.
- **Understand the intent, and classify the change.** Read the title and body. In one sentence (for you, never posted), state what the PR is trying to do. Then note which change-types it is — often several: version bump, routing, new chart, Terraform, CI, script, values, docs. That classification selects the lenses in Step 2.
- **Draft PRs:** if `isDraft: true`, treat findings as preliminary — frame as "worth addressing before marking ready" rather than "must fix before merge," but don't withhold real findings.
- **Read the existing review conversation first** — `gh api repos/<owner>/<repo>/pulls/<n>/comments --paginate` and `gh api repos/<owner>/<repo>/pulls/<n>/reviews --paginate`. A PR is often mid-conversation. For each candidate finding, check it against those threads — if it's already open, **reply in that thread** rather than posting a fresh top-level comment. Duplicating a live thread is exactly the noise that makes review a bottleneck.
- **Check for a pending review before you start** — `gh api repos/<owner>/<repo>/pulls/<n>/reviews --paginate --jq '.[] | select(.state == "PENDING")'`. GitHub allows only one pending review per user per PR, and any new review create (posted or staged) 422s while one exists. If it isn't yours, surface it and ask before posting. If it **is** yours (a prior `--stage` round the user never submitted, or a review they hand-started in the UI), its draft comments are invisible to `/pulls/<n>/comments` — read them via `.../reviews/<id>/comments --paginate` — and their fate is the user's call, made **before** you compose: they submit it in the UI (then treat those drafts as a published prior round — reply in-thread or stay silent per the bullets above) or ask you to discard it (the DELETE in Step 4), after which you re-raise in your own round whatever still holds.
- **Verify claimed fixes against the head — "fixed" is a claim, not evidence.** When a thread is marked resolved or the author replied "done," read the current code rather than trusting the reply. Authors routinely fix the headline of a comment while leaving a sub-point untouched. If the fix is real, **leave the thread closed and post nothing** — silence is the confirmation. Only reply when a sub-point survives, carrying only the surviving sub-point.
- **A comment is filed against a commit, not the head — check that commit before calling it stale or a false positive.** Compare the comment's `commit_id`/`original_commit_id` to the head; if they differ, diff those commits for that file and reproduce what the commenter saw. A quiet followup commit can resolve a real finding, which then reads as a false positive if you only look at the head. A valid catch the author already fixed is not a false positive — it earns silence, not a "good catch, fixed" reply.

## Step 2 — Verify, don't just read

Findings must be grounded in evidence, scaled to what the PR touches.

### General discipline

- Read the full files being changed (not just the hunks), and `git grep` the whole tree for symbols, keys, labels, and variables the PR renames, removes, or adds — silent breakage hides outside the diff.
- A zero-hit search is evidence only after a positive control: before trusting "no matches," prove the same pipeline finds a string you know is present. Never add `2>/dev/null` to evidence-gathering commands.
- When the one experiment that could falsify a finding can't run (no `helm`/`terraform` in CI), the finding ships as a `question:`, not a fact. "Post nothing" applies only to a genuinely clean PR, never to "I couldn't run the tool."

### Dual-mode verification

**If `helm`/`terraform` are present** (local run): use `helm template`, `helm lint`, `terraform validate`, `terraform plan -refresh=false` (read-only; never `apply`). Render before/after with the PR's own values and diff the manifests.

**If absent** (CI, the normal case): trace `{{ .Values.* }}` / variable usage by hand across templates and modules, and state the verification was source-based.

### Dimensions to sweep

Cover each, scaled to what the PR touches — an unnamed dimension is one you'll silently skip:

- **Correctness** — does the rendered manifest / planned resource do what it claims?
- **Cross-resource coherence** — does the thing this resource references actually exist and match? (The core habit for this repo.)
- **State and lifecycle** — will this replace a stateful resource, or mutate an immutable field?
- **Security** — secrets in diffs or CI logs, hardcoded credentials, missing/over-broad RBAC or IAM, permissive security contexts, unpinned images/actions.
- **Failure mode and rollout** — does it fail loudly or silently? What happens during a rolling upgrade?
- **Conventions** — does the change read like the surrounding code? (But don't re-flag what CI formatters/linters already enforce.)

### Apply the matching lens for the change-type

Most PRs are one or two of these. Apply the lenses that fit *in addition to* the general discipline and the coupling checklist — they are the durable questions a senior reviewer asks per kind of change, not a substitute for reading the code.

- **Dependency & version bumps** (Helm subchart in `Chart.yaml`/`Chart.lock`, container image tag, Terraform provider/module version, `uses:` action). Verify: `Chart.lock` regenerated to match `Chart.yaml` (digest + version); the new version is within any documented compatibility range and the app actually supports it (e.g. a MariaDB/Elasticsearch/JDK bump the backend can run against); **values-schema drift** — a subchart bump can rename or remove values keys, so `git grep` the keys this repo sets against the new chart's schema; whether the pin is immutable (digest/SHA) or a floating tag; and whether the changelog names a breaking change or a CVE fix. For actions, note SHA-pin vs mutable tag.
- **Networking / gateway / routing** (Gateway API `HTTPRoute`, Traefik `TraefikService`/listeners, `Ingress`, path rewrites, sticky sessions). Verify: every `backendRef` names a Service that exists with a matching port name/number; path matches don't silently overlap or shadow each other; rewrite/redirect filters produce the intended path; TLS/listener config is coherent; cross-namespace refs have a `ReferenceGrant`; and session-affinity assumptions still hold when replica count or the backing Service changes.
- **New or restructured chart / resource.** Verify: `_helpers.tpl` name/fullname logic can't collide across resources; selector labels are a strict subset of pod labels; required values fail loud (`required`/`fail`) rather than rendering empty; secrets aren't defaulted to real values; RBAC is least-privilege; and it wires into the umbrella chart / dependencies correctly.
- **Terraform infrastructure.** Verify: replacement-vs-in-place for every changed argument against the provider **source** for the pinned version (see reference map); no orphaned module/variable/output (defined-but-never-referenced, or a caller missing a required variable); IAM/security-group scope is least-privilege; secrets go to SSM/Secrets Manager, never into state or outputs. Don't re-flag what `tfsec`/`terrascan`/`tflint` already gate in this repo's CI.
- **CI / GitHub Actions.** Verify: `permissions:` is least-privilege; actions are SHA-pinned where it matters; secrets aren't exposed to untrusted/fork contexts (`pull_request_target` misuse, echoing secrets); trigger conditions are correct; a reusable-workflow change is compatible with its callers.
- **Shell scripts.** Verify: `set -euo pipefail` (or equivalent care), quoting, idempotency, injection-safe interpolation of any external/user value, and correct wait/gating/rollout logic.
- **Values / configuration.** Verify the coupling checklist below — a values change usually has its consequence in a template, a Service, a Secret key, or a JDBC/URL string, not in the values file itself.
- **Docs / README.** Verify claims against the templates: dead config (a documented values key no template reads), stale example commands, and directory/paths that no longer exist.

### Trace outward — the bugs live outside the diff

The diff is a piece of a bigger machine; review the machine. Follow each thread at least one level out:

- **Unchanged neighbors.** Re-read the unchanged code adjacent to the change. Of each assumption it makes, ask: does this PR make it false?
- **Values ↔ template correspondence.** A values key no template reads is dead config; a template field with no backing value renders empty. `git grep` every `.Values.` reference against `values.yaml`, both directions.
- **The merged result, not the commit stack.** Review the final combined state.

### Build context before you critique — the senior-engineer habit

A senior reviewer finds out *why* the code is the way it is before deciding it's wrong. Do this proportionally to how surprising or consequential the change is — a one-line typo fix doesn't need it; a lifecycle-sensitive or cross-resource change does.

- **Read history, not just current state.** `git log --oneline -n 20 -- <file>` and `git blame` on the touched hunks. Odd-looking code often has a reason (a prior incident, a deliberate workaround); don't flag a deliberate tradeoff as a bug, but do check whether this PR invalidates the reason it existed.
- **Follow references the PR gives you.** `Fixes #123` / `Related to #456` — read them (`gh issue view` / `gh pr view`) before forming a verdict; they often carry the constraint that makes an odd change correct.
- **Check precedent in the repo.** Before calling a pattern wrong, `git grep` how the same problem is solved elsewhere here. Matching an existing convention usually isn't worth a comment; diverging from it without reason is.
- **Verify external system semantics against authoritative source, not memory.** "This Terraform field forces replacement," "this Kubernetes/CRD field defaults to X," "this chart renamed that value" — provider/API/chart behavior changes across versions and is easy to misremember. When a finding's correctness hinges on external semantics and you're not certain, verify via the reference map. If you can't verify, say so and post it as a `question:`, never a confident `blocking:`.
- **State what you learned, briefly, when it changes the verdict.** "This matches the pattern in `service.yaml`, so not flagging" reads as senior judgment; silence on why you didn't flag something reads as not having looked.

#### Reference map — where to verify each technology this repo touches

Do this proactively for whatever the PR actually touches. This repo layers several APIs; CRD fields in particular are not part of general Kubernetes knowledge — treat any recollection of a CRD schema as a hypothesis to check.

| Technology | Where it shows up | Where to verify |
|---|---|---|
| Kubernetes core/apps API (StatefulSet, Deployment, Service, ConfigMap, Secret, HPA) | `helm/*/templates/*.yaml` | `raw.githubusercontent.com/kubernetes/api/master/<group>/<version>/types.go`, or `kubernetes.io/docs/reference/generated/kubernetes-api/` |
| Gateway API (HTTPRoute) | `httproute.yaml`, `admin-httproute.yaml`, `grafana-httproute.yaml` | `gateway-api.sigs.k8s.io/reference/spec/` |
| Traefik CRDs (TraefikService, sticky sessions, listeners) | `traefikservice.yaml`, operator chart | `doc.traefik.io/traefik/reference/routing/kubernetes/crd/http/` |
| MariaDB Operator CRD (`k8s.mariadb.com/v1alpha1`) | `mariadb-*.yaml` | `github.com/mariadb-operator/mariadb-operator` docs/CRD reference — third-party operator, so verify rather than assume |
| ECK (Elastic Cloud on Kubernetes) | init containers, `-eck-es-*` secrets | `www.elastic.co/guide/en/cloud-on-k8s/current/` |
| Helm templating functions/behavior | all chart templates | `helm.sh/docs/chart_template_guide/` |
| Terraform + AWS provider resource semantics (ForceNew, defaults) | `terraform/modules/**` | `raw.githubusercontent.com/hashicorp/terraform-provider-aws/main/internal/service/<service>/<resource>.go` for the actual schema — **`registry.terraform.io` is JS-rendered and returns an empty shell to `WebFetch`, so go to the provider source on GitHub instead** |
| GitHub Actions workflow syntax | `.github/workflows/*.yaml` | `docs.github.com/en/actions/reference` |

Use `WebFetch` against these if available. If not, say so and post the finding as a `question:` rather than asserting CRD/provider/API behavior from memory.

**This table is a snapshot of today's stack, not a whitelist.** The repo will add things not in it — a new provider or resource, a new CRD from another operator, a new Action, a script in a new language, a call to a new external service. "Not in the table" is never permission to review from memory. Detect what the PR introduces, then find its authoritative source the same way:

- **New `apiVersion`/`kind` in a manifest** → a CRD from some operator; the `apiVersion` group (e.g. `k8s.mariadb.com`) usually names it — find the operator repo and read its CRD schema.
- **New `provider`/resource type in Terraform** → find that provider's source on GitHub (`raw.githubusercontent.com/<org>/terraform-provider-<name>/main/...`), since registry pages don't render for `WebFetch`.
- **New `uses:` action** → read that action's repo/README for real inputs/outputs; note SHA vs mutable-tag pinning.
- **A new file type / language / manifest** (script, `Dockerfile`, `package.json`, `go.mod`) → review it against that tool's own idioms and docs, not this repo's Helm/Terraform conventions.
- **A call to a new external service/API** → find its docs before asserting anything.

State plainly when you had to look something up fresh — that's the job, not a gap to hide. If you can't find authoritative source for something new and consequential, downgrade the finding to a `question:`.

### Coupling patterns (openmrs-contrib-cluster) — conditional, illustrative, not exhaustive

These are the cross-resource failures known to matter here, written as **"if a PR does X → verify Y."** They illustrate the trace-outward method; they are a floor. Apply the same reasoning to couplings not listed.

**Any file paths, line numbers, or claims about the repo's current state below are illustrations from when this was written — the repo changes, and the fixes these describe may already be merged. Never assert current repo state from this file. Re-locate the code (`git grep`, `Read`) and re-derive the fact from the PR's actual head before citing it.**

- **Peer discovery over DNS (Infinispan/JGroups clustered cache) → headless Service.** If a PR enables or touches `infinispan.clustered` (which drives `cache.type: cluster`, `cache.stack: kubernetes`, and a `jgroups.dns.query` FQDN), verify a **headless** Service backs the pods (`clusterIP: None`, `publishNotReadyAddresses: true`) and the query points at it. A plain `ClusterIP` Service resolves to one VIP, so DNS_PING finds a single address, peers never discover each other, and each pod forms a **silent** singleton cache that still passes health checks. Apply the same check to any DNS-based peer-discovery mechanism, not just JGroups.
- **StatefulSet ⇄ governing headless Service.** If a PR sets or changes a StatefulSet's `serviceName`, verify it names a real headless Service. `serviceName` is **immutable** — changing it on an existing StatefulSet forces a recreate (data loss if `volumeClaimTemplates` also change). If a PR depends on stable per-pod DNS, verify `serviceName` is actually set (an unset value is an empty string, not a name-derived default).
- **HPA ⇄ workload kind/name.** If a PR touches an HPA or changes a workload's kind or name, verify `scaleTargetRef.kind` and `scaleTargetRef.name` match the real workload. An HPA pointing at a kind/name that doesn't resolve (e.g. `kind: Deployment` against a StatefulSet) is a **silent no-op** — it reports healthy and never scales.
- **volumeClaimTemplates ⇄ data.** `volumeClaimTemplates` are **immutable after creation**; changing PVC name, storage class, or access mode forces StatefulSet recreation and destroys data. If a PR touches these (or `persistence.*`/`global.defaultStorageClass`), flag whether it's a new install (safe) or an upgrade (data loss), with a concrete failure-mode sentence.
- **Service selector ⇄ pod labels.** If a PR changes the label set, verify the Service `selector` remains a strict subset of the pod template's labels — otherwise the Service routes to nothing.
- **Sticky sessions ⇄ replicas ⇄ route.** If session affinity matters (stateful backend), verify the affinity object (e.g. a Traefik sticky `TraefikService`) is actually the backend the `HTTPRoute`/`Ingress` targets when the workload runs more than one replica. A PR that disables the affinity object while keeping multiple replicas can silently drop stickiness.
- **Secret/ConfigMap keys ⇄ consumers.** If a PR adds/renames a key in a Secret or ConfigMap, verify the consumer actually reads it — via blanket `envFrom` or an explicit `secretKeyRef`/`configMapKeyRef`. On a rename, `git grep` the old name across all templates and `values.yaml` (with a positive control) to confirm nothing still references it — a renamed key silently drops the env var and the app starts with an unset value.
- **Terraform module ⇄ root caller.** If a module is added or its variables change, verify the root passes all required variables (no `default = null` a caller skips). If removed, verify nothing references it. If it adds an output, verify a caller reads it.
- **Replacement-forcing Terraform args ⇄ stateful resources.** Before calling any argument change a destroy+recreate, verify `ForceNew` against the provider source for the version this repo pins (`ForceNew` can change across provider majors). For `aws_db_instance` as verified against the current provider: `engine` is `ForceNew` (changing it destroys+recreates → data loss), while `identifier` and `engine_version` update in place; EKS cluster `version` is an in-place control-plane upgrade, not a replacement. Re-verify rather than trusting these specifics.

**Silent-failure upgrade rule.** When a failure produces wrong behavior *without* erroring — singleton cache, selector matching nothing, dropped env key, HPA on the wrong kind, a route pointing at a non-existent backend — treat it one level more seriously than a crash. CI can't catch what doesn't throw; the cost lands on operators in production. Lead with these.

### Test coverage is a review dimension

For each behavior change, name the check that would catch a regression: a Helm test hook (`helm/openmrs-backend/templates/tests/`), a CI validation job, a `terraform plan` step, or — where automated coverage is thin — a documented manual verification step in the PR body. A behavior change with no such check is a finding, even when the manifest looks obviously correct: this repo has little-to-no chart-render testing in CI, so "it looks right" is unverified until someone runs it. Scale to consequence — don't invent a coverage gap for a comment or a label tweak.

### Convergence

A pass that surfaced a substantive finding cannot be your last: one real find is evidence of unexplored ground, so sweep again until a pass turns up nothing substantive. The converse holds too — don't invent findings to fill a quota; a clean PR earns a short review.

### When an adversarial refutation pass is worth it

The verification above is the default and usually enough. A heavier technique — challenging each candidate from an independent context (told to *refute* it: does it reproduce, is the mechanism right, does the named resource actually break; refuted-but-unproven becomes a `question:`) — earns its cost only when **two or more** hold:

- the finding is a **judgment call, not a mechanical fact** (a second pass re-tracing a deterministic claim reaches the same answer);
- you're reviewing **solo in one pass** with no independent cross-check;
- the pass is **rushed or low-effort**, where "verify before asserting" is most likely to be skipped;
- the **cost of a false positive is high** — a `blocking` finding about data loss or an outage.

When none hold, it re-runs verification you already did. Keep it a conditional escalation, never a default step.

## Step 3 — Compose the review

The review's job is to surface what needs action. Lead with action.

The body is **earned, not mandatory, and the default is none.** It exists only to carry what no single inline comment can: a cross-cutting concern with no line to sit on, or a shared root cause across findings. Summarizing or triaging the inline comments is not such a thing. When a single inline comment already conveys the verdict, post the inline comments with an **empty body**.

When a body is warranted:

1. **Verdict first** — disposition + one headline reason + scope, in your own words. Never print a `Verdict:`/`Summary:` label. "I think this is good to merge — nothing here blocks" or "This needs work — …".
2. **Findings live in exactly one place.** The body must not restate inline comments — reference them bare ("the inline question on the Service change"), never recap what they say.
3. **End by making explicit what blocks merge** — a short list when it's more than one thing, nothing when nothing blocks.

A "ready to merge, nothing to act on" verdict is **not** posted — the workflow's 👍 is the clean signal.

Rules for every inline comment, no exceptions:

- **First line makes clear what kind of comment it is, in plain language** — "This needs fixing before merge — …", "Optional: …", "Is this intended?" — **not** stamped taxonomy prefixes (`issue (blocking):`, `nit:`, or em-dash/colon variants like `Question — …`). Open with the thing itself. The distinctions that must come through:
  - **blocking** — must fix before merge. Must contain "if merged as-is, X breaks because Y." If you can't write that sentence, it isn't blocking.
  - **suggestion** — recommended change the author may decline.
  - **question** — a genuine question whose answer affects the verdict (also for uncertainty about an observed side effect, and for anything you couldn't verify because a tool was absent).
  - **nit** — trivial, take or leave.
  - **note (no action needed)** — only to record deliberate acceptance for the audit trail, or warn a specific future reader.
- **When presenting alternatives, state the recommended default.** Never end on "either is fine."
- **Do not narrate what the diff does** — the author wrote it.
- **Keep each comment to its finding.** Say a cross-cutting point once, on the anchor that best carries it.
- Use ```suggestion blocks for concrete line replacements (RIGHT side only).
- Scale to the PR: fewer, sharper comments beat exhaustive ones.

Evidence lives *inside the finding it supports*, not in a standalone recap — a real finding is self-justifying once the reader checks it against the code. **Checked it and it's fine → say nothing.**

## Step 4 — Post or stage (only with consent)

Posting publishes under the user's own GitHub account. **Post** only when the user passed `--post`, asked explicitly, or the CI automation path is driving (which always posts inline — see the arguments note). **Stage** only when the user passed `--stage` or asked for a draft. With neither, present the full review in conversation and offer to post or stage. `--stage` sits between conversation-only and `--post`: the review is created on GitHub in PENDING state — invisible to the author, no notification — and the user finishes it in the UI (edits, deletes, then submits or discards). Staging is a checkpoint, not a lower bar: the user may submit it unedited, so a staged review must already pass every rule in this file, including the gate below.

### Missing tools downgrade, never silence

If confirming a finding would require `helm template`, `terraform plan`, or any unavailable tool, **raise it as a `question:`** — state what you'd verify and why the source-based trace suggests a concern. "Post nothing" applies only to a genuinely clean PR, never to "I couldn't run the tool."

### A clean verdict is reported to the user, never posted or staged

When the review turns up nothing to act on — fresh PR, or a re-review where every prior finding is resolved — there is no review to publish or stage. Tell the user it's ready to merge in conversation and stop (in CI, post nothing; the workflow's 👍 is the clean signal). Never open a review whose body just announces the PR is good to go — an "LGTM / ready to merge" comment is the clearest tell that a bot, not a person, is on the other end. Posting still happens normally when there ARE action items; you just never add a standalone merge-readiness flourish.

### Pre-posting gate

Before presenting, posting, or staging, write these as explicit standalone lines in your report. If any can't be said truthfully, fix the review, not the wording:

> "Every finding was verified by reading the full file, tracing values/CRD/provider behavior, or checking authoritative source — not just read off the diff."

> "No inline comment or verdict leads with a stamped label. Every blocking comment contains its failure-mode sentence, and no comment exists merely to acknowledge a fix or credit already-resolved work."

> "The body carries only what no inline comment can, and is empty when a single inline comment conveys the verdict. No restated findings, no verified-clean recap, and — on a re-review — no tally of what got fixed."

> "Needs action before merge: [list, or 'none' — and if 'none', this verdict goes to the asker in conversation, never posted or staged]."

### Mechanics — shared by post and stage

- **Re-run the pending-review check immediately before any create** (state can change since Step 1). One pending review per user per PR: either kind of create 422s "User can only have one pending review per pull request," and REST can't append to an existing one. On a hit that isn't yours, stop and ask.
- **Build `payload.json` with `python3` + `json.dump`** — hand-written JSON with raw tabs/newlines breaks the API call. The payload has a `body` and a `comments` array.
- **Prefer** the `mcp__github_inline_comment__create_inline_comment` tool for a straight `--post` of inline comments when it's available; use the `gh api` payload path below when staging, replying into threads, or when the tool is absent.
- **Anchor to lines in the PR diff.** `"side": "RIGHT"` with **PR-head** line numbers for added/context lines; `"side": "LEFT"` with **merge-base** line numbers for a comment on a deleted line. Exact numbers via `git show <ref>:<path> | cat -n`; confirm the merge-base first (`git merge-base origin/<base> pr-<n>`). Multi-line comments use `start_line`/`start_side` plus `line`/`side`, and the whole span must fall in one diff hunk. If the natural target isn't in the diff, anchor to the nearest in-diff line and reference the real location in text — never drop a finding because it won't anchor.
- **Comments post under the user's name** — first person, collegial.

### Posting (`--post` / CI)

- Submit one review: `gh api repos/<owner>/<repo>/pulls/<n>/reviews --input payload.json` with `"event": "COMMENT"` (never APPROVE/REQUEST_CHANGES unless the user explicitly chose that).
- **If a create or comment is rejected** (422 / not part of the diff), re-anchor and retry rather than giving up.
- **Threaded replies** (Step 1 may route you here to build on an existing thread): `gh api repos/<owner>/<repo>/pulls/<n>/comments/<comment_id>/replies -f body=...`. These post as standalone review comments with their own ids — they won't appear in the main review's `comments` array, so don't expect them in the verification below.
- **Verify after posting — trust content, not counts:** `gh api repos/<owner>/<repo>/pulls/<n>/comments --paginate --jq '.[] | select(.pull_request_review_id == <id>) | {path, line, side, body}'`. `--paginate` is mandatory (30/page; a busy PR exceeds it → false negatives). Diff against what you submitted by `{path, line}`; if something looks missing, re-query (reads lag writes) before concluding it's gone. **Never re-post on a mismatch** — that's how duplicates happen. If duplicates already exist, delete extras with `gh api -X DELETE repos/<owner>/<repo>/pulls/comments/<comment_id>`.
- **Fix in place, never post a second review:** update body with `gh api -X PUT repos/<owner>/<repo>/pulls/<n>/reviews/<id> --input body.json` (`{"body": ""}` blanks it outright — the right move when the body only re-announced an inline comment); edit an inline comment with `gh api -X PATCH repos/<owner>/<repo>/pulls/comments/<comment_id> -f body=...`.

### Staging (`--stage`, interactive only)

- Same payload, but **omit `event` entirely** — GitHub creates the review PENDING. The create returns the review's `id` (REST) and `node_id` (GraphQL) — keep both.
- **Staged thread replies:** the `/replies` REST endpoint publishes immediately and can't stage. Attach the reply to the pending review via GraphQL `addPullRequestReviewThreadReply` with `pullRequestReviewId` (the pending review's `node_id`), `pullRequestReviewThreadId`, and `body`. Find the thread id in the PR's `reviewThreads` connection by matching the target comment's REST id against `fullDatabaseId` — it comes back as a **string**, so a numeric jq comparison silently matches nothing (on older GHES where `fullDatabaseId` errors, match `databaseId` instead). For a replies-only round, create the pending review first with an empty `{}` payload so there's something to attach to.
- **Verify a staged review:** pending comments do **not** appear in `/pulls/<n>/comments` — list them with `gh api repos/<owner>/<repo>/pulls/<n>/reviews/<review_id>/comments --paginate`. Compare by `{path, body}`, **not** `{path, line}`: until submitted, pending comments report `line`/`side` as `null` (only diff-relative `position` is set), so a line-based diff false-mismatches on every staged comment. Expected set = the payload's comments **plus** every GraphQL-attached reply (match replies by `body`); those aren't duplicates. Re-query after a few seconds if something looks missing before repairing.
- **Repairing a staged review:** never per-comment DELETE — it silently eats your own drafts. A missing/newly-requested reply attaches in place via the GraphQL path (no restage). Anything else (bad anchor, missing top-level comment) is delete-and-restage: `gh api -X DELETE repos/<owner>/<repo>/pulls/<n>/reviews/<review_id>`, then rebuild. Rebuild source: **before** hand-off, from your composition with the defect fixed; **after** hand-off, list current drafts first (`.../reviews/<review_id>/comments --paginate`) and let the user's UI edits win on wording/deletions while the piece the repair exists to restore comes from your composition. Deletion evaporates GraphQL-attached replies too, so restage them, then re-verify against the corrected set — not against a rebuild that inherited the loss.
- **Hand-off:** end with the review URL, say plainly it's visible only to the user until they submit it (Files changed → "Finish your review"), and that a forgotten pending review is a review that never happened. Which event to submit with — comment, approve, request changes — is the user's call in the UI, not something to instruct. Discard from the CLI: `gh api -X DELETE repos/<owner>/<repo>/pulls/<n>/reviews/<review_id>` (pending reviews only).

## Anti-patterns

- **Don't invent concerns to look thorough.** A clean PR gets a short, confident review. Diminishing returns are a real signal.
- **Don't post unverified suspicion as blocking.** Couldn't verify it → `question:`, or more homework for you, not the author.
- **Don't let severity labels substitute for analysis.** A finding is blocking because of its written failure mode, not because it pattern-matches a category. Small-looking patterns (a missing `publishNotReadyAddresses`, a swapped selector key, a floating image tag) are routinely under-labeled.
- **Don't restore confidence the author already has.** The review's value is the delta — what must change, plus the rare verified-clean item a later reviewer would otherwise re-raise. A recap of what they got right is cost without benefit.
- **Don't let the review read as machine output.** Vary structure, use plain language, avoid em-dashes and rigid templates. A verbatim header on every review, a taxonomy tag on every comment, or a comment that announces its own speech act ("A correction to my earlier point: …") are tells — write like a careful human colleague, and when retracting something, lead with the corrected fact, not the announcement.
- **Don't acknowledge fixes (especially on re-review).** Fixed and nothing remaining → no comment. The re-review that should be two lines shouldn't become a wall of "looks good now."
- **Don't critique an inflated version of the PR.** Respond to the author's actual scope; a larger redesign is a follow-up suggestion, not a blocker on this PR.
- **Don't fake confidence on a PR too large to review.** Say so plainly and suggest splitting; name what you verified and what you couldn't reach.
