# TRUNK-6520: MariaDB Bitnami → Official Operator Migration

## Overview

Migrated from Bitnami MariaDB (primary-replica) to the official MariaDB Kubernetes
Operator with Galera cluster topology. The operator is installed as a cluster
prerequisite (not a subchart) because it installs cluster-scoped CRDs and RBAC.

## Why the Operator?

| Capability | Bitnami Chart | Official Operator |
|---|---|---|
| Galera cluster management | Manual, via separate galera chart | Native CRD support |
| Automated failover | Requires manual intervention | Built-in automatic failover |
| Backups & restore | External tooling needed | CRD-driven (`Backup`, `Restore`) |
| Recovery | Manual pod deletion | `recovery.enabled: true` |
| Scaling | Modify replicaCount | Modify `replicas` in CRD |

## Files Modified

### `helm/openmrs-backend/Chart.yaml`
- **Removed** Bitnami `mariadb` dependency (OCI, version 22.0.0)
- Kept `mariadb-galera` dependency (will be removed in TRUNK-6629)
- Kept `elasticsearch`, `minio`, `grafana`, `loki`, `alloy` dependencies unchanged

### `helm/openmrs-backend/values.yaml`
- Changed `mariadb.image.repository` from `bitnamilegacy/mariadb` → `mariadb`
- Changed `mariadb.image.tag` from `10.11` → `"10.11"`
- Added `mariadb.primary.resources` (requests/limits) for operator CRD
- Added `mariadb-operator` section with `enabled: false`, `galera: false`
- Added `minio.containerPorts` (api: 9000, console: 9001) for URL helper

### `helm/openmrs-backend/templates/mariadb-instance.yaml` (NEW)
Creates a `MariaDB` CRD resource when `mariadb-operator.enabled: true`.
- apiVersion: `k8s.mariadb.com/v1alpha1`
- References `openmrs-backend-mariadb-secret` for credentials
- Supports two topologies via `mariadb-operator.galera`:
  - `true` → 3-node Galera cluster with `recovery.enabled: true`
  - `false` → 2-node primary-replica with `autoFailover: true`
- Uses official `mariadb:10.11` image
- myCnf includes Galera-required settings (binlog_format, innodb_autoinc_lock_mode)

### `helm/openmrs-backend/templates/mariadb-secret.yaml` (NEW)
Creates a Secret with `root-password` and `user-password` for the operator.
Gated on `mariadb-operator.enabled: true`.

### `helm/openmrs-backend/templates/configmap.yaml`
Added operator condition block at the top of the DB hostname section:
- Operator enabled + Galera → OMRS_DB_HOSTNAME: `<release>-mariadb`
- Operator enabled + Replication → OMRS_DB_HOSTNAME: `<release>-mariadb-primary`
- Legacy Bitnami paths preserved under `{{- else }}`
- Fixed MinIO endpoint quoting (single-quoted YAML string to prevent Helm
  YAML serializer from re-escaping the port)

### `helm/openmrs-backend/templates/statefulset.yaml`
Added operator branch to init container `resolve-mariadb-hosts`:
- Operator + Galera → `jdbc:mariadb:loadbalance://<release>-mariadb.<ns>.svc.cluster.local:3306/...`
- Operator + Replication → `jdbc:mariadb://<release>-mariadb-primary.<ns>.svc.cluster.local:3306/...`
- Legacy Bitnami host resolution preserved under `{{ else }}`
- Init container and command condition expanded to include operator

### `helm/openmrs-backend/templates/secret.yaml`
Added operator branch for `OMRS_DB_USERNAME`/`OMRS_DB_PASSWORD`:
- Reads from `.Values.mariadb.auth.username` / `.Values.mariadb.auth.password`
- Fallback to `openmrs` / `OpenMRS123`

### `helm/openmrs-backend/templates/_helpers.tpl`
Fixed `openmrs-minio.url` helper to hardcode port 9000 instead of using
`containerPorts.api` with `quote` (which produced YAML-invalid URLs like
`http://host:"9000"` that broke Spring's S3StorageService).

### `helm/kind-openmrs.yaml`
- Set `galera.enabled: false` (Bitnami galera not installed — operator
  manages Galera via CRD)
- Set `mariadb-operator.enabled: true`
- Set `mariadb-operator.galera: true` (operator creates Galera topology)

### `README.md`
Added MariaDB Operator prerequisites section documenting the two-chart install:
1. `mariadb-operator-crds` (CRDs)
2. `mariadb-operator` (operator itself)
Added parameter table entries for `mariadb-operator.enabled` and
`mariadb-operator.galera`.

## Operator Install (Prerequisite)

```bash
helm repo add mariadb-operator https://helm.mariadb.com/mariadb-operator
helm repo update

# CRDs first (mandatory separate chart)
helm install mariadb-operator-crds mariadb-operator/mariadb-operator-crds \
  -n mariadb-system --create-namespace

# Then the operator
helm install mariadb-operator mariadb-operator/mariadb-operator \
  -n mariadb-system --create-namespace --wait
```

## Key Design Decisions

1. **Two separate CRD + operator charts**: The official operator requires
   installing CRDs and the operator as two separate Helm charts. The CRDs
   chart must be installed first.

2. **`mariadb-operator.galera` not `galera.enabled`**: Since the
   `mariadb-galera` Bitnami dependency remains (for TRUNK-6629 removal),
   using `galera.enabled` would trigger both the operator AND the old
   Bitnami galera chart. A separate `mariadb-operator.galera` flag avoids
   this conflict.

3. **Minimal Galera spec**: The MariaDB operator manages SST, agent, init
   containers internally. Only `enabled: true` and `recovery: enabled: true`
   are specified — no `sst`, `replicaThreads`, or `agent.image` fields.

4. **Service naming**: Galera → `<release>-mariadb` (single service, all
   nodes equal). Replication → `<release>-mariadb-primary` (writes to
   primary only).

## Validation (Tested in Kind Cluster)

| Check | Result |
|---|---|
| `helm lint` | pass |
| MariaDB CRD in rendered output | yes |
| OMRS_DB_HOSTNAME | `openmrs-mariadb` |
| Bitnami mariadb references | 0 |
| Operator pods Running | 3/3 (operator, cert-controller, webhook) |
| MariaDB CRD READY=True | yes |
| `wsrep_cluster_size` | 3 |
| `wsrep_ready` | ON |
| JDBC URL | `jdbc:mariadb:loadbalance://openmrs-mariadb.openmrs.svc.cluster.local:3306/openmrs?...` |
| Liquibase completed | yes |
| ES, MinIO, Loki, Grafana | all functional |
