# Rebase on upstream/main — PR #10 merged

## What happened

PR #10 (`patch-1` — fix: Resolve backend pod crash, 404 on localhost, and helm template bugs) was merged into `upstream/main` on 2026-05-13. Our `TRUNK-6535` branch (ECK migration) was rebased on top of it.

### PR #10 fixes we now inherit

| Bug | Fix | File |
|-----|-----|------|
| `elasticsearch.uris` value not rendered (Helm template expression missing) | Wrapped with `{{ }}` | `configmap.yaml` |
| Grafana ingress shadowing OpenMRS catch-all | Changed host from `localhost` to `grafana.local` | `values.yaml` |
| Backend crash when ES not ready | Added `wait-for-elasticsearch` init container using `kubectl` | `statefulset.yaml` |
| Malformed URLs (literal `"9200"` instead of `9200`) | Replaced `quote` with `toString` | `_helpers.tpl` |
| Typo `defaultIngessClass` | Fixed to `defaultIngressClass` | `kind-openmrs-min.yaml` |

### Conflicts resolved during rebase

1. **`_helpers.tpl`** (commit `6da1632` — Bitnami → official Elastic chart):
   - Upstream had `service.ports.restAPI` (Bitnami, PR #10's `toString` fix)
   - Our commit used `service.port` (official Elastic chart)
   - Resolution: used our property path with upstream's `toString` pattern

2. **`_helpers.tpl`** (commit `355b69d` — official chart → ECK):
   - Upstream had URL via `printf "%s%s..." "http://"` format
   - Our commit used `printf "http://%s..."` format
   - Resolution: took ECK version

3. **`configmap.yaml`** (commit `e4e2be8` — ECK config):
   - Duplicate `OMRS_EXTRA_HIBERNATE_SEARCH_BACKEND_SSL_VERIFICATION__MODE: "none"`
   - Resolution: kept both branches (once in `elasticsearch.enabled` block, once in `else if .uris` block)

### Stash merge after rebase

Our local WIP changes (truststore, credentials, etc.) were applied on top with 1 conflict:

**`statefulset.yaml`** — `wait-for-elasticsearch` vs `import-es-ca`:
- Upstream (PR #10) added `wait-for-elasticsearch` waiting for Bitnami statefulset
- Our stash added `import-es-ca` for ECK CA truststore import
- **Resolution**: kept BOTH init containers:
  - `import-es-ca` runs first (imports ECK CA cert into JVM truststore)
  - `wait-for-elasticsearch` runs second, **adapted for ECK** (polls `kubectl get elasticsearch <cr> -o jsonpath='{.status.phase}'` for `green`/`yellow` instead of checking Bitnami statefulset replicas)

### Rebased commit history (top of `TRUNK-6535`)

```
2b7bb01 Use native plugins, drop redundant overrides, raise memory to 2Gi
464fd20 Remove obevious comments
e450c2e Clean up comments
e4e2be8 Use helm helm chart for ECK config
8718a38 Remove security config because its not supported in ECK
355b69d Replaced deprecated Helm subchart with ECK-managed CR
cb16ea1 fix(helm): trim ES roles and add sysctlVmMaxMapCount
6da1632 feat(helm): migrate elasticsearch from bitnami to official elastic chart
367f2ed fix: Resolve backend pod crash, 404 on localhost, and helm template bugs (#10)  ← upstream/main
```

Commit `a892fab` (Fix ingress typo) was dropped — already fixed upstream in PR #10.
