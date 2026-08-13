# openmrs-contrib-cluster
Contains terraform and helm charts to deploy OpenMRS distro in a cluster.

Terraform setup is borrowed from Bahmni https://github.com/Bahmni/bahmni-infra (please see the terraform directory). It has been further adjusted for general use in other OpenMRS distributions.

## Overview

See https://openmrs.atlassian.net/wiki/x/tgBLCw for more details.

## Other options

### AWS

If you intend to deploy on AWS and you are intersted in a solution that runs natively on AWS and is not easily movable to on-prem or any other cloud provider you may want to have a look at https://github.com/openmrs/openmrs-contrib-cluster-aws-ecs It showcases the usage of AWS CDK instead of Terraform for setting up an ECS cluster instead of Kubernetes. It also utilizes AWS Fargate and AWS Aurora managed services for high availability and scalability. 

At this point we did not add support for AWS Fargate and AWS Aurora for Kubernetes deployment as part of our general solution in this repo, but we may do that in the future if there is enough interest or a contribution.

## Usage

### Helm

We recommend https://kind.sigs.k8s.io/ for local testing.

To install on Mac OS:

      brew install kubectl
      brew install helm
      brew install kind

Other install options: 
1. https://kubernetes.io/docs/tasks/tools/
2. https://helm.sh/docs/intro/install
3. https://kind.sigs.k8s.io/docs/user/quick-start/#installing-from-release-binaries


## Quick Start (Kind for local testing)

### Prerequisites

| Tool | Install |
|------|---------|
| Docker | [docker.com](https://docs.docker.com/get-docker/) |
| kind | `brew install kind` or [kind.sigs.k8s.io](https://kind.sigs.k8s.io/docs/user/quick-start/#installing-from-release-binaries) |
| kubectl | `brew install kubectl` or [kubernetes.io](https://kubernetes.io/docs/tasks/tools/) |
| helm | `brew install helm` or [helm.sh](https://helm.sh/docs/intro/install) |

The bootstrap script runs preflight checks and will fail with a clear message if any are missing.

Make sure Docker is running, then one command bootstraps everything:

      cd helm
      make deploy

This handles all of the following in order (idempotent — safe to re-run):

| Step | What it does |
|------|-------------|
| 1a   | Preflight checks — verifies `kind`, `kubectl`, `helm`, Docker |
| 1b   | Pre-pulls images + Helm dependencies in parallel |
| 2    | Creates Kind cluster (`kind-config.yaml`) + loads images |
| 3    | Installs `openmrs-operator` chart — bundles Gateway API CRDs, MariaDB operator, ECK operator, Traefik, and local-path-provisioner |
| 4    | Deploys OpenMRS umbrella chart (live pod status every 10s) |
| 5    | Prints pod summaries and access URL |

Once deployment completes, OpenMRS is available at:

      http://localhost:8080/openmrs/spa/login

With the default `kind-openmrs.yaml`, the following dashboards are accessible out of the box:

| Service | URL | Controlled by |
|---------|-----|---------------|
| Grafana (logs dashboard) | http://localhost:8080/grafana/ | `monitoring.enabled` (deploys Grafana/Loki/Alloy via the umbrella) |
| SeaweedFS Admin (cluster overview & file browser) | http://localhost:8080/seaweedfs-admin/ | `seaweedfs.enabled` + `seaweedfs.admin.enabled` (deploys it) and `openmrs-backend.seaweedfs.admin.httpRoute.enabled` (exposes the route) |

No port-forwarding needed — Traefik binds the port directly. Default credentials: Grafana `admin` / `Admin123`, SeaweedFS Admin `admin` / `Admin123`.

To disable monitoring (Grafana, Loki, Alloy), set `monitoring.enabled=false` in `kind-openmrs.yaml` or pass `--set monitoring.enabled=false` to `helm`.

### Make targets

| Command | Description |
|---------|-------------|
| `make deploy` | Full bootstrap (idempotent) |
| `make deploy-operators` | Prerequisites only — stops before OpenMRS |
| `make deploy-openmrs` | OpenMRS only (assumes operators are running) |
| `make teardown` | Delete Kind cluster (prompts for confirmation) |
| `make status` | Pod summary across all namespaces |
| `make logs` | Stream openmrs-backend pod logs |
| `make help` | Print all available targets |

### Environment variables

| Variable | Default | Description |
|----------|---------|-------------|
| `MONITORING=true` | `false` | Enable Grafana/Loki/Alloy monitoring stack |
| `CLUSTER_NAME` | `kind` | Kind cluster name |
| `SKIP_OPERATORS=true` | `false` | Skip `openmrs-operator` chart install |
| `SKIP_OPENMRS=true` | `false` | Skip OpenMRS deployment (exit after step 3) |

### 6. Deploy additional tenants (multi-tenancy)

The `helm/openmrs-tenant` chart deploys an isolated OpenMRS tenant (backend + frontend)
that shares the primary cluster's MariaDB. It is a **thin umbrella**: the backend and
frontend workloads come from the shared `openmrs-backend` / `openmrs-frontend` charts
(consumed as dependencies), and the tenant chart only supplies the per-tenant
configuration on top of them. Each tenant is a separate Helm release in its own namespace.

#### Prerequisites

- Primary OpenMRS stack deployed and running (steps 1–4 above)
- MariaDB accessible from tenant namespace (default DNS: `<primary-release>-mariadb.<primary-namespace>.svc.cluster.local`, e.g. `openmrs-mariadb.openmrs.svc.cluster.local`)
- A database and user created for the tenant:

```bash
kubectl exec -n openmrs svc/openmrs-mariadb -- mysql -u root -pRoot123 -e "
  CREATE DATABASE IF NOT EXISTS openmrs_<tenant> CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci;
  CREATE USER IF NOT EXISTS '<tenant>_user'@'%' IDENTIFIED BY '<password>';
  GRANT ALL PRIVILEGES ON openmrs_<tenant>.* TO '<tenant>_user'@'%';
  FLUSH PRIVILEGES;
"
```

#### Install a tenant

A tenant connects to the shared MariaDB via a full JDBC URL
(`openmrs-backend.db.url`). `db.hostname` (and `db.port`) must point at the same
MariaDB — the backend image's `wait-for-it` preflight gates on
`OMRS_DB_HOSTNAME:OMRS_DB_PORT` (defaulting to `localhost:3306`, which never
resolves), so the JDBC URL alone is not enough. Vendor the shared charts once,
then install:

```bash
helm dependency update helm/openmrs-tenant   # once — vendors openmrs-backend/openmrs-frontend

helm install <tenant> helm/openmrs-tenant \
  -n tenant-<tenant> --create-namespace \
  --set global.tenant.name=<tenant> \
  --set global.defaultStorageClass=standard \
  --set openmrs-backend.db.url="jdbc:mariadb:loadbalance://<primary-release>-mariadb.<primary-namespace>.svc.cluster.local:3306/openmrs_<tenant>?autoReconnect=true&sessionVariables=default_storage_engine=InnoDB&useUnicode=true&characterEncoding=UTF-8&useMysqlMetadata=true" \
  --set openmrs-backend.db.hostname=<primary-release>-mariadb.<primary-namespace>.svc.cluster.local \
  --set openmrs-backend.db.port=3306 \
  --set openmrs-backend.db.username=<tenant>_user \
  --set openmrs-backend.db.password=<password>
```

Example for a tenant named `coast`:

```bash
helm install coast helm/openmrs-tenant \
  -n tenant-coast --create-namespace \
  --set global.tenant.name=coast \
  --set global.defaultStorageClass=standard \
  --set openmrs-backend.db.url="jdbc:mariadb:loadbalance://openmrs-mariadb.openmrs.svc.cluster.local:3306/openmrs_coast?autoReconnect=true&sessionVariables=default_storage_engine=InnoDB&useUnicode=true&characterEncoding=UTF-8&useMysqlMetadata=true" \
  --set openmrs-backend.db.hostname=openmrs-mariadb.openmrs.svc.cluster.local \
  --set openmrs-backend.db.port=3306 \
  --set openmrs-backend.db.username=coast_user \
  --set openmrs-backend.db.password=CoastPass123
```

> **Naming:** resources are named from the **release name** (the first argument to
> `helm install`) by the shared charts, e.g. release `coast` → `coast-openmrs-backend` /
> `coast-openmrs-frontend`.
>
> **Tenant label:** `global.tenant.name` sets the `app.kubernetes.io/tenant` label on
> the backend and frontend **pods** (it propagates into the shared charts as a global).
> It does **not** land on Services/ConfigMaps — labelling every resource per tenant
> would need a `commonLabels` hook on the shared charts (planned).

#### Verification

```bash
# Check pods with tenant label
kubectl get pods -n tenant-<tenant> -L app.kubernetes.io/tenant

# Wait for ready
kubectl wait --for=condition=ready pod -n tenant-<tenant> --all --timeout=600s

# Port-forward to backend (API)
kubectl port-forward -n tenant-<tenant> svc/<tenant>-openmrs-backend 8080:8080

# Port-forward to frontend (SPA)
kubectl port-forward -n tenant-<tenant> svc/<tenant>-openmrs-frontend 8081:80
```

> **Note on routing:** tenant HTTPRoutes are disabled in this chart
> (`openmrs-backend.gateway.enabled` and `openmrs-frontend.gateway.enabled` default to
> `false`) — per-tenant routing is deferred to a later phase (TRUNK-6654), since the
> shared charts' routes carry no hostname and would collide on the shared gateway.
> Reach the backend API via `kubectl port-forward` as shown. The **frontend SPA UI is
> not fully usable over port-forward** — the app shell requests its assets under
> `SPA_PATH` (`/openmrs/spa`), which needs a gateway rewrite (stripping the prefix
> before nginx) that port-forward cannot provide. Once tenant routing lands, each
> tenant's frontend and backend will sit behind a per-tenant hostname
> (e.g. `<tenant>.example.com`), like the primary OpenMRS stack.

#### Tenant chart parameters

The tenant chart's own values, plus the most common shared-chart overrides it passes
through. For the full shared-chart surface, see `helm/openmrs-backend/values.yaml` and
`helm/openmrs-frontend/values.yaml`.

| Name | Description | Default |
|------|-------------|---------|
| `global.tenant.name` | Tenant identifier; sets the `app.kubernetes.io/tenant` label on backend/frontend pods | **required** |
| `global.tenant.hostname` | Per-tenant hostname, reserved for future routing | `""` |
| `global.defaultStorageClass` | StorageClass for tenant PVCs (overrides the shared chart default) | `""` |
| `openmrs-backend.db.url` | Full JDBC URL to the shared MariaDB | **required** |
| `openmrs-backend.db.hostname` | Shared MariaDB host, used by the backend's `wait-for-it` preflight (`OMRS_DB_HOSTNAME`) | **required** |
| `openmrs-backend.db.port` | Shared MariaDB port | `3306` |
| `openmrs-backend.db.username` | Tenant DB user | **required** |
| `openmrs-backend.db.password` | Tenant DB password | **required** |
| `openmrs-backend.podLabels` | Extra labels for backend pods | `{}` |
| `openmrs-frontend.enabled` | Deploy the frontend | `true` |
| `openmrs-frontend.spaPath` | URL path the SPA is served from (`SPA_PATH`) | `"/openmrs/spa"` |
| `openmrs-frontend.apiUrl` | SPA → backend API URL (`API_URL`) | `"/openmrs"` |
| `openmrs-frontend.defaultLocale` | Default UI locale (`SPA_DEFAULT_LOCALE`) | `"en"` |
| `openmrs-frontend.configUrls` | Distro config JSON URLs (`SPA_CONFIG_URLS`); omitted when empty | `""` |
| `openmrs-frontend.replicaCount` | Frontend replicas | `1` |
| `openmrs-frontend.podLabels` | Extra labels for frontend pods | `{}` |

Images and versions are inherited from the shared charts (backend `3.7.x-no-demo`,
frontend `3.7.x`); override via `openmrs-backend.image.*` / `openmrs-frontend.image.*`
if needed. Clustering, autoscaling, and shared storage are shared-chart features and
are covered in later phases.

### Alternative: install from Helm registry

      helm repo add openmrs https://openmrs.github.io/openmrs-contrib-cluster/
      helm upgrade --install --create-namespace -n openmrs \
        --set global.defaultStorageClass=standard openmrs openmrs/openmrs

The embedded MariaDB CR uses Galera clustering by default (`global.mariadb.galera: true`).
To use basic primary/replica replication instead:

      helm upgrade --install --create-namespace -n openmrs \
        --set global.defaultStorageClass=standard \
        --set global.mariadb.galera=false \
        --set global.mariadb.replicas=2 openmrs openmrs/openmrs

### Kubernetes Dashboard (optional)

      helm repo add kubernetes-dashboard https://kubernetes-retired.github.io/dashboard/
      helm upgrade --install kubernetes-dashboard kubernetes-dashboard/kubernetes-dashboard \
        --create-namespace --namespace kubernetes-dashboard \
        --set extraArgs="--token-ttl=0"
      kubectl -n kubernetes-dashboard create token admin-user
      kubectl -n kubernetes-dashboard port-forward svc/kubernetes-dashboard-kong-proxy 8443:443
      # Go to https://localhost:8443/ and login with generated token

#### Migrating to 2.0.0

`openmrs`/`openmrs-backend`/`openmrs-frontend` 2.0.0 relocated infra-deploy
values out of `openmrs-backend` and into the umbrella's top level (`openmrs-backend`
is now a workload-only chart). A values file written for 1.x will fail to render
with an error naming the exact key that moved, rather than silently dropping it.

| Old key (≤ 1.2.2) | New key (2.0.0+) |
|---|---|
| `openmrs-backend.monitoring.*` | `monitoring.*` |
| `openmrs-backend.grafana.*` | `grafana.*` |
| `openmrs-backend.loki.*` | `loki.*` |
| `openmrs-backend.alloy.*` | `alloy.*` |
| `openmrs-backend.elasticsearch-eck.*` | `elasticsearch-eck.*` |
| `openmrs-backend.seaweedfs.master.*` / `.volume.*` / `.filer.*` / `.s3.enabled` / `.s3.replicas` / `.s3.enableAuth` | `seaweedfs.*` (same sub-paths, top level) |
| `openmrs-backend.seaweedfs.admin.ingress.*` | `seaweedfs.admin.ingress.*` |
| `openmrs-backend.mariadb.auth.*` | `global.mariadb.auth.*` |
| `openmrs-backend.mariadb.enabled` / `.galera` / `.replicas` | `global.mariadb.enabled` / `.galera` / `.replicas` |
| `openmrs-backend.galera.*` | removed (was never read by any template) — use `global.mariadb.*` |
| `openmrs-backend.elasticsearch.enabled: true` (used to deploy the ECK cluster) | same path, but now **only** wires the workload — also set top-level `elasticsearch.enabled: true` to actually deploy it |
| `openmrs-backend.seaweedfs.enabled: true` (used to deploy SeaweedFS) | same path, but now **only** wires the workload — also set top-level `seaweedfs.enabled: true` to actually deploy it |
| `openmrs-backend.seaweedfs.admin.enabled: true` (used to deploy the Admin component) | same path, but now **only** wires the workload's own HTTPRoute — also set top-level `seaweedfs.admin.enabled: true` to actually deploy the Admin component |

The last three rows are the trap in this table: the *path* didn't change, only what it does, so nothing about the key itself tells you something's different. `helm/openmrs/templates/NOTES.txt` fails the render if `openmrs-backend.elasticsearch.enabled`/`.seaweedfs.enabled`/`.seaweedfs.admin.enabled` is `true` without the matching top-level flag, specifically to catch this. `openmrs-backend.elasticsearch.uris`/`.username`/`.password` and `openmrs-backend.seaweedfs.s3.credentials.admin.*`/`.admin.httpRoute.*`/`.admin.urlPrefix` are genuinely unaffected — those only ever wired the workload, never deployed anything.

#### Parameters

##### Global parameters

| Name                      | Description                                                                             | Value   |
| ------------------------- |-----------------------------------------------------------------------------------------|---------|
| `defaultStorageClass`     | Global default StorageClass for Persistent Volume(s)                                    | `"gp2"` |

#### Common parameters

Prepend with the name of the service: `openmrs-backend`, `openmrs-frontend`, `traefik-gateway`, `mariadb`.

| Name                | Description                  | Default Value                                            |
|---------------------|------------------------------|----------------------------------------------------------|
| `.image.repository` | Image to use for the service | `e.g. "openmrs/openmrs-reference-application-3-backend"` |
| `.image.tag`        | Tag to use for the service   | `e.g. "3.0.0"`                                           |


#### OpenMRS-backend parameters

`openmrs-backend` is a workload-only chart (no embedded infra) so both the umbrella
and a tenant chart can consume it. Infra deploy/scale settings live on the umbrella
(next section); these values only control how the workload *connects* to that infra.

| Name                                                             | Description                                                                                                            | Default Value                                             |
|------------------------------------------------------------------|------------------------------------------------------------------------------------------------------------------------|-----------------------------------------------------------|
| `openmrs-backend.db.hostname`                                    | External DB hostname. Only used when `global.mariadb.enabled=false`                                                     | `""` |
| `openmrs-backend.db.database`                                    | OpenMRS database name for external (bring-your-own) databases. Empty falls back to `"openmrs"`. Ignored when `global.mariadb.enabled=true`, where the name always comes from `global.mariadb.auth.database` | `""` |
| `openmrs-backend.db.username` / `.password`                      | Credentials for an external (bring-your-own) database. Used only when `global.mariadb.enabled=false`                   | `"openmrs"` / `"OpenMRS123"` |
| `openmrs-backend.db.url`                                         | Full JDBC URL for an external database. **Requires `db.hostname` set too** — the URL is the JDBC connection, `db.hostname` feeds the image's startup preflight (which otherwise falls back to `localhost`). Ignored when `global.mariadb.enabled=true` | `""` |
| `openmrs-backend.persistence.size`                               | Size of persistent volume to claim (for search index, attachments, etc.)                                               | `"8Gi"`                                                   |
| `openmrs-backend.elasticsearch.enabled`                          | Wire the workload to use Elasticsearch (hibernate-search env/volumes). Does **not** deploy a cluster — see `elasticsearch.enabled` below | `false` |
| `openmrs-backend.elasticsearch.uris` / `.username` / `.password` | External Elasticsearch connection details, used when `uris` is non-empty                                                | `""` |
| `openmrs-backend.seaweedfs.enabled`                              | Wire the workload for S3 storage (injects S3 credentials into the Secret). Does **not** deploy SeaweedFS — see `seaweedfs.enabled` below | `false` |
| `openmrs-backend.seaweedfs.admin.httpRoute.enabled`              | Expose a Gateway API HTTPRoute to the SeaweedFS Admin service (deployed separately by the umbrella)                     | `false` |
| `openmrs-backend.seaweedfs.admin.httpRoute.hostnames`            | Hostnames for the admin HTTPRoute                                                                                       | `["localhost"]` |
| `openmrs-backend.seaweedfs.s3.credentials.admin.accessKey` / `.secretKey` | S3 access/secret key — must match the umbrella's `seaweedfs.s3.credentials.admin.*` below                        | `"openmrs"` / `"OpenMRS123"` |

#### Umbrella infra parameters (`helm/openmrs`)

The umbrella owns and deploys the infra (MariaDB, Elasticsearch, SeaweedFS, Grafana/Loki/Alloy);
`openmrs-backend` above only carries the matching connection values. None of this
exists in a tenant chart consuming the shared `openmrs-backend`/`openmrs-frontend` charts.

| Name                                                        | Description                                                                                  | Default Value    |
|--------------------------------------------------------------|------------------------------------------------------------------------------------------------|-------------------|
| `global.mariadb.enabled`                                     | Deploy the embedded MariaDB CR **and** connect the backend workload to it — one flag, read by both | `true`            |
| `global.mariadb.auth.database` / `.username` / `.password`   | Name/credentials for the OpenMRS database, read by both the MariaDB CR and the backend workload's connection — one value, not two to keep in sync | `"openmrs"` / `"openmrs"` / `"OpenMRS123"` |
| `global.mariadb.replicas` / `.galera`                        | Replica count / Galera clustering mode — read by both the MariaDB CR and the backend's JDBC URL construction | `2` / `true`      |
| `mariadb.auth.rootPassword`                                  | Password for the `root` user. Ignored if existing secret is provided. Umbrella-only — the backend workload never needs it | `"Root123"`       |
| `mariadb.primary.persistence.size`                           | MariaDB primary persistent volume size                                                         | `"8Gi"`           |
| `elasticsearch.enabled`                                      | Deploy an ECK-managed Elasticsearch cluster                                                    | `false`           |
| `elasticsearch-eck.*`                                        | ECK `Elasticsearch` CR spec (`nodeSets`, `podTemplate.spec.containers[].resources`, `volumeClaimTemplates`) — see the ECK docs below | see `values.yaml` |
| `seaweedfs.enabled`                                          | Deploy SeaweedFS (master/volume/filer/S3 gateway)                                              | `false`           |
| `seaweedfs.master.replicas`                                  | Number of SeaweedFS master nodes for Raft consensus                                            | `3`               |
| `seaweedfs.volume.replicas`                                  | Number of SeaweedFS volume servers (one per worker node recommended)                           | `3`               |
| `seaweedfs.volume.dataDirs[0].size`                          | Persistent volume size per volume server pod                                                   | `"8Gi"`           |
| `seaweedfs.filer.replicas`                                   | Number of SeaweedFS filer replicas (3+ recommended for HA)                                     | `3`               |
| `seaweedfs.admin.enabled`                                    | Deploy the SeaweedFS Admin component                                                            | `false`           |
| `seaweedfs.admin.secret.adminPassword`                       | Admin dashboard password (empty = no auth)                                                     | `"Admin123"`      |
| `seaweedfs.s3.replicas`                                      | Number of S3 API gateway replicas (stateless)                                                  | `2`               |
| `seaweedfs.s3.enableAuth`                                    | Enable S3 credential authentication                                                            | `true`            |
| `seaweedfs.s3.credentials.admin.accessKey` / `.secretKey`    | S3 access/secret key — must match `openmrs-backend.seaweedfs.s3.credentials.admin.*` above      | `"openmrs"` / `"OpenMRS123"` |
| `monitoring.enabled`                                          | Enable monitoring (deploys Grafana, Loki, Alloy)                                                | `false`           |
| `grafana.adminPassword`                                       | Grafana admin password                                                                          | `"Admin123"`      |
| `grafana.ingress.enabled` / `.hosts`                          | Ingress for Grafana (disabled when using HTTPRoute)                                              | `false` / `["localhost"]` |
| `grafana.httpRoute.enabled` / `.hostnames` / `.path`          | Gateway API HTTPRoute for Grafana                                                                | `false` / `["localhost"]` / `"/grafana"` |

See [MariaDB Operator](https://github.com/mariadb-operator/mariadb-operator) for MariaDB CRD parameters.

See [ECK Elasticsearch configuration](https://www.elastic.co/docs/deploy-manage/deploy/cloud-on-k8s/elasticsearch-configuration)
for full configuration options. The ECK operator must be installed as a cluster prerequisite
before enabling Elasticsearch — see the Prerequisites section below.

See [Grafana](https://github.com/grafana-community/helm-charts/blob/main/charts/grafana/README.md), [Loki](https://github.com/grafana/loki/blob/main/production/helm/loki/README.md) and [Alloy](https://github.com/grafana/alloy/blob/main/operations/helm/charts/alloy/README.md) helm charts for other Grafana parameters.

#### Prerequisites: SeaweedFS (S3-compatible object storage)

No separate operator installation is required. SeaweedFS is included as a
Helm subchart dependency of the `openmrs` umbrella (not `openmrs-backend`,
which is workload-only). When `seaweedfs.enabled=true`, the umbrella deploys:

| Component | Pods | Purpose |
|---|---|---|
| Master | 3 | Raft-based cluster coordination |
| Volume server | 3 | Persistent data storage with PVCs (one per worker node recommended) |
| Filer | 3 | Metadata store required by the S3 gateway (uses MariaDB as backend for easy backup) |
| S3 gateway | 2 | Stateless S3 API endpoint at `<release>-seaweedfs-s3:8333` (depends on filer) |

Credentials are configured via `s3.credentials.admin` values and injected into
the backend's Secret as `storage.s3.accessKeyId` and `storage.s3.secretAccessKey`.
This is declared in two places — `openmrs-backend.seaweedfs.s3.credentials.admin.*`
(the workload's copy) and the umbrella's top-level `seaweedfs.s3.credentials.admin.*`
(the third-party chart's own copy) — and must be kept in sync by hand; the
third-party chart has its own values schema and doesn't share Helm's `global.*`
mechanism the rest of the credential wiring uses. See the parameter tables above
for both sides.

##### SeaweedFS Filer: MariaDB backend

The filer uses MariaDB as its metadata store. The subchart's filer StatefulSet template
hardcodes `WEED_MYSQL_USERNAME` and `WEED_MYSQL_PASSWORD` referencing the Secret
`{release}-seaweedfs-db-secret` with keys `user` and `password` (both `optional: true`).
The subchart creates this Secret automatically as a pre-install hook (with placeholder
credentials). The chart overrides these via two mechanisms (env vars take precedence by
appearing after the hardcoded entries):

1. `filer.extraEnvironmentVars.WEED_MYSQL_USERNAME` — plain value (username is not sensitive)
2. `filer.secretExtraEnvironmentVars.WEED_MYSQL_PASSWORD` — references the MariaDB
   secret `{fullname}-mariadb-secret` key `user-password`, avoiding the password in
   the StatefulSet YAML

> The secret name in `secretExtraEnvironmentVars` is a hardcoded string because the
> subchart does not process it through `tpl`. The default `{fullname}-mariadb-secret`
> assumes `openmrs-backend` as the fullname — the umbrella reconstructs this name via
> the `openmrs.backendFullname` helper (`helm/openmrs/templates/_helpers.tpl`), which
> reads `openmrs-backend.nameOverride`/`.fullnameOverride`. If you override either on
> the backend, keep this value (and the umbrella's own mariadb Secret/SqlJob names) in sync.

The chart also creates a pre-install hook Job that creates the `filemeta` table
before the filer starts. This table is required by the filer's MariaDB store and
the filer will crash with a fatal error if it is missing.

The chart creates a pre-install hook Job that creates the `filemeta` table before the filer starts — the filer requires this table to exist and will crash with a fatal error if it is missing.

See [SeaweedFS documentation](https://github.com/seaweedfs/seaweedfs/wiki)
for full details.

### Security Notes (Production)

The default values in `kind-openmrs.yaml` are optimized for local development
and **must be reviewed before production use**:

| Concern | Local dev | Production |
|---------|-----------|------------|
| Grafana default credentials (`admin`/`Admin123`) | Safe — localhost only | **Must change** — use a strong password or SSO |
| SeaweedFS security (`enableSecurity: false`) | Safe — no external access | **Must enable** — otherwise data is publicly accessible |
| SeaweedFS Admin default credentials (`admin`/`Admin123`) | Safe — localhost only | **Must change** — use a strong password |
| HTTP (no TLS) | Fine — localhost only | **Must enable TLS** on the Gateway listener |
| HTTPRoute auth | Safe — traffic is cluster-internal only | **Add auth middleware** (e.g., OAuth, basic auth) via HTTPRoute filters or a reverse proxy |

For production, start with these overrides:

```yaml
grafana:
  adminPassword: "<strong-password>"
seaweedfs:
  global:
    seaweedfs:
      enableSecurity: true
  admin:
    secret:
      adminPassword: "<strong-password>"
```

TLS can be configured by adding a certificate to the Gateway listener in
`helm/kind-traefik.yaml` and switching `kind-openmrs.yaml` to `https`.

### Terraform and AWS

#### Setting up terraform and AWS

1. Install [Terraform](https://learn.hashicorp.com/tutorials/terraform/install-cli)


      brew install tfenv 
      tfenv install 1.9.5


2. Install [AWS CLI](https://docs.aws.amazon.com/cli/latest/userguide/getting-started-install.html)


      brew install awscli
      aws configure

Before running Terraform commands, note that in the `terraform/aws` folder you will find AWS custom policies and roles used by the project:

- `terraform/aws/policies` — contains AWS IAM policies
- `terraform/aws/roles` — contains AWS IAM roles

#### Initialize Terraform backend (one time operation)

To Initialize terraform backend run:


      cd terraform-backend
      terraform init
      terraform apply
      cd ..

#### Running Terraform


1. Deploy the cluster and supporting services


      cd terraform/
      terraform init
      terraform apply -var-file=nonprod.tfvars


2. Run helm to deploy ALB controller and OpenMRS


      cd terraform-helm/
      terraform init
      terraform apply -var-file=nonprod.tfvars


3. Configure kubectl client to monitor your cluster (optionally)

      
      aws eks update-kubeconfig --name openmrs-cluster-nonprod


## Development Setup

### Setting up pre-commit hooks

This is a one-time setup that needs to be run only when the repo is cloned.
1. Install [pre-commit](https://pre-commit.com/#install)


      brew install pre-commit


2. Install pre-commit dependencies

    - [terrascan](https://github.com/accurics/terrascan)
    - [tfsec](https://github.com/aquasecurity/tfsec#installation)
    - [tflint](https://github.com/terraform-linters/tflint#installation)
   

      brew install terrascan tfsec tflint


3. Initialise pre-commit hooks


      pre-commit install --install-hooks


Now before every commit, the hooks will be executed.

### Developing Helm Charts

Once you have local or AWS cluster setup (see above) and kubectl is pointing to your cluster you can run helm install 
directly from source. To verify you kubectl is connected to the correct cluster run:


      kubectl cluster-info


If you need to change your kubectl cluster run:


      # For AWS
      aws eks update-kubeconfig --name openmrs-cluster-nonprod
      
      # For local Kind cluster
      kubectl cluster-info --context kind-kind


To install Helm Charts from source run (see above for possible settings):


      cd helm/openmrs
      helm upgrade --install --create-namespace -n openmrs --values ../kind-openmrs.yaml openmrs .


If you made any changes in helm/openmrs-backend or helm/openmrs-frontend or helm/traefik-gateway you need to update 
dependencies and run helm upgrade.


      # form helm/openmrs dir
      helm dependency update
      helm upgrade openmrs .

### Releasing from Github Actions

1. Bump `openmrs-backend`/`openmrs-frontend`/`openmrs-tenant` `Chart.yaml` (and the
   dependency pins on backend/frontend in **both** `helm/openmrs/Chart.yaml` and
   `helm/openmrs-tenant/Chart.yaml`) in a regular commit first — the workflow below
   doesn't touch these charts, they version independently of the umbrella.
2. Go to the "Actions" tab in the GitHub repository.
3. Select the "Release Charts" workflow from the left sidebar.
4. Click the "Run workflow" dropdown button.
5. Enter the desired umbrella version (e.g., `2.0.0`) in the "version" input field.
   `openmrs-operator` versions independently and is left untouched unless you also
   fill in "operator_version" — leave it blank to skip releasing it this round.
6. Click the green "Run workflow" button.

This will:
- Update the version in `helm/openmrs/Chart.yaml` (and `helm/openmrs-operator/Chart.yaml`
  if `operator_version` was set).
- Commit and push the changes.
- Create a git tag.
- Package and release the charts to GitHub Pages.

## Directory Structure
```
helm                              # helm charts
├── Makefile                      # one-command local bootstrap (make deploy)
├── scripts                       # bootstrap helpers (lib.sh, bootstrap.sh, teardown.sh)
├── openmrs                       # umbrella chart
├── openmrs-backend               # backend subchart
├── openmrs-frontend              # frontend subchart
├── traefik-gateway               # Traefik Gateway API subchart
├── openmrs-operator              # Cluster operators chart (MariaDB, ECK, Traefik, Gateway API)
├── kind-config.yaml              # Kind cluster definition
├── kind-init.yaml                # Cluster prerequisites
├── kind-openmrs.yaml             # OpenMRS values (local dev)
├── kind-openmrs-min.yaml         # OpenMRS values (minimal)
├── kind-traefik.yaml             # Traefik values (local dev)
terraform-backend                 # terraform AWS backend setup
terraform                         # terraform AWS setup
├── ...
├── aws
├── ├── policies                  # aws custom policies
├── ├── roles                     # aws custom roles
|── modules                       # contains reusable resources across environemts
│   ├── vpc
│   ├── eks
│   ├── ....
│   ├── main.tf                   # File where provider and modules are initialized
│   ├── variables.tf
│   ├── nonprod.tfvars            # values for nonprod environment
│   ├── outputs.tf
│   ├── config.s3.tfbackend       # backend config values for s3 backend
└── ...
terraform-helm                    # terraform Helm installer
```