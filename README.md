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
| 3    | Installs `openmrs-operator` chart - bundles Gateway API CRDs, MariaDB operator, ECK operator, Traefik, Metrics Server, and Cluster Autoscaler (opt-in) |
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

### Scaling

Horizontal scaling has two layers:

- **Pod level (HPA)** - the backend HPA (`openmrs-backend.autoscaling.enabled`) targets
  the backend StatefulSet. Metrics Server (installed by the `openmrs-operator` chart,
  `metrics-server.enabled`, on by default) provides the CPU/memory `Resource` metrics.
  When autoscaling is on, sticky (session-affine) routing engages automatically so
  scale-out never drops `openmrs_session` cookies, and a PodDisruptionBudget guards
  voluntary disruptions once running more than one replica.

  > **Prerequisite for correct multi-replica behaviour:** replicas must share
  > second-level cache and object storage. Sticky routing only pins a user to one
  > pod; it does not share cache or files across pods. Without both, replicas serve
  > stale cached reads and store uploads on per-pod local disk invisible to other
  > pods. The chart enforces this at render time - enabling autoscaling (or
  > `replicaCount>1`) without them fails the render.
  >
  > On the **umbrella** chart these are subchart keys, so they need the
  > `openmrs-backend.` prefix - and SeaweedFS also needs its own top-level toggle to
  > actually deploy. The full working set is **four** values:
  >
  > ```
  > --set openmrs-backend.autoscaling.enabled=true \
  > --set openmrs-backend.infinispan.clustered=true \
  > --set openmrs-backend.seaweedfs.enabled=true \
  > --set seaweedfs.enabled=true      # top-level - deploys SeaweedFS itself
  > ```
  >
  > (On the standalone `openmrs-backend` chart it's just `autoscaling.enabled`,
  > `infinispan.clustered`, `seaweedfs.enabled`.) Mind the cost: enabling SeaweedFS
  > at umbrella defaults adds ~11 pods (3 master, 3 volume, 3 filer, 2 s3) on top of
  > MariaDB's 3 Galera replicas - size the node group accordingly.

  > **Sticky sessions are backend-only.** Only the backend holds session state, so
  > only it gets a session-affinity `TraefikService`; the frontend is a stateless SPA
  > (static assets, the session lives in the backend) and needs none. The cookie name
  > is overridable per tenant (`openmrs-backend.traefikService.sticky.cookie.name`,
  > default `openmrs_session`) to avoid collisions on a shared gateway, and is marked
  > `Secure` by default (`traefikService.sticky.cookie.secure=true`) for production
  > HTTPS. **Set it to `false` for plain-HTTP setups - e.g. testing multiple replicas
  > locally on Kind - or the browser drops the cookie and stickiness silently breaks.**
  > (A single-replica install renders no cookie at all. Note this default changed: prior
  > releases emitted `secure: false`, so an existing plain-HTTP multi-replica deployment
  > flips to `Secure` on upgrade and silently loses stickiness - set
  > `traefikService.sticky.cookie.secure=false` explicitly there.)

  > **Clustered-cache DNS re-discovery.** With `infinispan.clustered=true` the backend
  > shortens the JVM DNS cache to `infinispan.dnsCacheTtlSeconds` (default 5) so JGroups
  > DNS_PING re-resolves the headless Service and finds new or replaced pods promptly on
  > scale events, instead of waiting out the JVM's ~30s default. Leave it low where pods
  > churn (autoscaling); raise it to trim DNS lookups on a stable cluster.
- **Node level (Kubernetes Cluster Autoscaler)** - the `openmrs-operator` chart can
  deploy the Cluster Autoscaler (`clusterAutoscaler.enabled=true`, default off), which
  scales the managed node group / auto-scaling group within its min/max bounds. The
  chart is cloud-agnostic: implementers pick their provider via
  `clusterAutoscaler.cloudProvider`. Only `aws` is validated here; the upstream
  chart also supports `azure`, `gce`, `magnum`, `clusterapi` and others, but those
  need provider-specific values before they render a valid manifest (e.g. `magnum`
  requires `clusterAutoscaler.cloudConfigPath`). No provider is hard-coded.
  Discovery is tag-based (`k8s.io/cluster-autoscaler/<cluster>=owned`): on EKS
  those tags are applied automatically to the managed node group's ASG, so there's
  nothing to set by hand; on other providers tag the node group yourself. For EKS,
  the Terraform module provides the building blocks: a `lifecycle` guard on the
  node group in `terraform/modules/eks/cluster.tf` (so `terraform apply` doesn't
  fight CA over `desired_size`), and a least-privilege IRSA role in
  `terraform/modules/eks/iam.tf` whose ARN is exported as the
  `cluster_autoscaler_role_arn` module output. Wiring that ARN onto the CA
  ServiceAccount is a manual install-time step (not yet automated in
  `terraform-helm`): pass it - plus the cluster's region - when installing the
  operator chart, e.g.
  ```
  helm dependency update ./helm/openmrs-operator   # once - vendors the operator subcharts (charts/ is gitignored)
  helm upgrade --install openmrs-operator ./helm/openmrs-operator -n openmrs-system --create-namespace \
    --set traefik.enabled=false \
    --set clusterAutoscaler.enabled=true \
    --set clusterAutoscaler.cloudProvider=aws \
    --set clusterAutoscaler.awsRegion=<region> \
    --set clusterAutoscaler.autoDiscovery.clusterName=<eks-cluster-name> \
    --set 'clusterAutoscaler.rbac.serviceAccount.annotations.eks\.amazonaws\.com/role-arn'=$(terraform -chdir=terraform output -raw cluster_autoscaler_role_arn)
  ```
  `awsRegion` must match the cluster's region (this repo's is `us-east-2`); without
  it the upstream chart pins `AWS_REGION=us-east-1` and CA silently manages nothing.
  `traefik.enabled=false` is set because the chart's Traefik defaults are
  Kind-specific (control-plane `nodeSelector` + `hostPort: 8080`) and would sit
  Pending on EKS; leave it off here, but if the cluster already runs the operator
  chart omit that flag, or the upgrade removes the gateway.

  > **What CA will and won't reclaim:** CA scales the group up for pending pods and
  > removes a node it added once that node empties, but it will **not** consolidate a
  > node still running a SeaweedFS (or Traefik / Metrics Server) pod - those mount
  > `emptyDir`/`hostPath` and CA's default `--skip-nodes-with-local-storage=true`
  > keeps such nodes. So backend replica scale-out/scale-in works, but full
  > consolidation of nodes hosting the shared infra is a follow-up (per-component
  > `safe-to-evict-local-volumes` annotations plus a PVC for the SeaweedFS master),
  > not part of this PR.

  Local Kind clusters must never run the CA (no node group), hence the default
  `false`.

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
- The **MariaDB operator** running **cluster-wide** (installed automatically by step 3's `openmrs-operator` chart; it watches all namespaces and reconciles the `Database` / `User` / `Grant` CRs below)

The tenant's database and user are **created automatically**: the tenant chart renders the
MariaDB operator's `Database` / `User` / `Grant` custom resources (in the tenant namespace,
referencing the shared MariaDB via `mariaDbRef`). The operator turns them into
`CREATE DATABASE` / `CREATE USER` / `GRANT` / `ALTER USER ... WITH MAX_USER_CONNECTIONS`
declaratively — no imperative bootstrap Job runs, and the shared MariaDB's **root password
never enters the tenant namespaces** (it stays inside the operator). Nothing to do by hand.

> **Manual fallback:** with `--set dbBootstrap.enabled=false` the CRs are not
> rendered and you must create the database and user yourself, e.g.:
>
> ```bash
> # _ is a LIKE wildcard in GRANT; escape each _ as \_ and wrap in backticks.
> # A quoted heredoc ('SQL') keeps backticks intact through the local shell.
> kubectl exec -i -n openmrs svc/openmrs-mariadb -- mysql -u root -pRoot123 <<'SQL'
>   CREATE DATABASE IF NOT EXISTS openmrs_east_coast CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci;
>   CREATE USER IF NOT EXISTS 'openmrs_east_coast_user'@'%' IDENTIFIED BY '<password>';
>   GRANT ALL PRIVILEGES ON `openmrs\_east\_coast`.* TO 'openmrs_east_coast_user'@'%';
>   FLUSH PRIVILEGES;
> SQL
> ```

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
  --set openmrs-backend.db.username=openmrs_<tenant>_user \
  --set openmrs-backend.db.password=<password> \
  --set dbBootstrap.mariaDbRef.name=<primary-release>-mariadb \
  --set dbBootstrap.mariaDbRef.namespace=<primary-namespace>
```

> **Hyphenated tenant names:** the database defaults to `openmrs_<tenant>` with
> any `-` in the tenant name replaced by `_` (JDBC URL convention). For example,
> `global.tenant.name=east-coast` provisions `openmrs_east_coast`, so use
> `.../openmrs_east_coast?...` in the JDBC URL, not `openmrs_east-coast`.
> **Do not use `_` in tenant names** — both `-` and `_` normalize to `_`, so
> `east-coast` and `east_coast` would collide on the same MariaDB account.

The chart renders the MariaDB operator's `Database` / `User` / `Grant` CRs, which
auto-provision the tenant database `openmrs_<tenant>` (override via
`dbBootstrap.database`), the `openmrs_<tenant>_user` user, and its grants — the password is
taken from `openmrs-backend.db.password` (matching the backend's own Secret). The CRs
target the shared MariaDB via `dbBootstrap.mariaDbRef` (defaults to the primary chart's
`openmrs-mariadb` CR in the `openmrs` namespace). Set `--set dbBootstrap.enabled=false`
to skip bootstrapping and manage the database manually (see above).

> **Known operator limitation:** the MariaDB operator (26.6.0, installed by
> `openmrs-operator`) has an upstream SQL-injection advisory (CWE-89): it builds SQL
> without escaping `'` in user/database names or passwords. The tenant chart rejects
> `'`, `\` and `` ` `` (database name only) while `dbBootstrap.enabled=true` so the install fails
> loudly instead of leaving a `User`/`Grant` CR stuck in `Error`. Change the value or
> set `dbBootstrap.enabled=false` and create the user manually.

Example for a tenant named `coast`:

```bash
helm install coast helm/openmrs-tenant \
  -n tenant-coast --create-namespace \
  --set global.tenant.name=coast \
  --set global.defaultStorageClass=standard \
  --set openmrs-backend.db.url="jdbc:mariadb:loadbalance://openmrs-mariadb.openmrs.svc.cluster.local:3306/openmrs_coast?autoReconnect=true&sessionVariables=default_storage_engine=InnoDB&useUnicode=true&characterEncoding=UTF-8&useMysqlMetadata=true" \
  --set openmrs-backend.db.hostname=openmrs-mariadb.openmrs.svc.cluster.local \
  --set openmrs-backend.db.port=3306 \
  --set openmrs-backend.db.username=openmrs_coast_user \
  --set openmrs-backend.db.password=CoastPass123 \
  --set openmrs-backend.gateway.enabled=true \
  --set "openmrs-backend.gateway.hostnames[0]=coast.example.com" \
  --set openmrs-frontend.gateway.enabled=true \
  --set "openmrs-frontend.gateway.hostnames[0]=coast.example.com"
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

# Check the MariaDB operator reconciled the tenant's CRs (Database/User/Grant ready)
kubectl get database,user,grant -n tenant-<tenant>

# Point the tenant hostname at the gateway (local dev)
echo "127.0.0.1 coast.example.com" | sudo tee -a /etc/hosts

# Open the SPA in a browser (Traefik binds host port 8080 on the Kind cluster)
# http://coast.example.com:8080/openmrs/spa/home

# Port-forward to backend (API) for direct access
kubectl port-forward -n tenant-<tenant> svc/<tenant>-openmrs-backend 8080:8080
```

#### Scaling a tenant

A tenant scales horizontally the same way the primary does - by flipping the shared
`openmrs-backend` values - plus per-tenant object storage. Running more than one
replica requires clustered cache **and** shared storage (the backend guard enforces
it). By default a tenant shares the primary's SeaweedFS with **its own bucket and its
own bucket-scoped credentials**, so one tenant's key can never touch another's files:

```bash
helm install <tenant> helm/openmrs-tenant \
  -n tenant-<tenant> --create-namespace \
  # ... the DB + gateway values from above ...
  --set openmrs-backend.replicaCount=3 \
  --set openmrs-backend.infinispan.clustered=true \
  --set openmrs-backend.autoscaling.enabled=true \
  --set openmrs-frontend.autoscaling.enabled=true \
  --set openmrs-backend.traefikService.sticky.cookie.name=openmrs_session_<tenant> \
  --set openmrs-backend.seaweedfs.enabled=true \
  --set openmrs-backend.seaweedfs.s3.endpoint=http://<primary-release>-seaweedfs-s3.<primary-ns>.svc.cluster.local:8333 \
  --set openmrs-backend.seaweedfs.s3.bucketName=openmrs-<tenant> \
  --set openmrs-backend.seaweedfs.s3.credentials.accessKey=<tenant>-key \
  --set openmrs-backend.seaweedfs.s3.credentials.secretKey=<tenant-secret> \
  --set s3Bootstrap.enabled=true \
  --set s3Bootstrap.master=<primary-release>-seaweedfs-master.<primary-ns>.svc.cluster.local:9333
```

> **Bucket name must be DNS-style (hyphens, not underscores).** The tenant *database*
> is `openmrs_<tenant>` (underscores, MySQL), but the S3 *bucket* must be a valid S3
> name — use `openmrs-<tenant>` (`openmrs_<tenant>` is rejected as `InvalidBucketName`).
> The tenant chart guards this at render time.

`s3Bootstrap` runs a post-install Job that creates the tenant's bucket and a SeaweedFS
identity scoped to `Read/Write/List:<bucket>`. For this to take effect the shared
SeaweedFS S3 gateway must use **filer-backed dynamic IAM** (`seaweedfs.s3.enableAuth=false`,
the default here) so runtime-provisioned identities are honoured and hot-reloaded; the
umbrella's `s3Seed` hook seeds the primary's own bucket-scoped identity so auth is still
enforced (the primary cannot read or write tenant buckets). To use
**managed S3** instead of SeaweedFS, point `seaweedfs.s3.endpoint` at the S3 URL, set
`seaweedfs.s3.forcePathStyle=false` with a real `seaweedfs.s3.region`, provision the
bucket/credentials in the cloud, and leave `s3Bootstrap.enabled=false`. Give the backend
either static `openmrs-backend.seaweedfs.s3.credentials.accessKey`/`.secretKey`, **or**,
for IRSA / instance credentials, set `openmrs-backend.seaweedfs.s3.credentials.useDefaultChain=true`
(this emits no static keys, so the AWS SDK default credential chain applies) and attach the
role via `openmrs-backend.serviceAccount.annotations` (e.g. `eks.amazonaws.com/role-arn`).

> **Static key charset:** `s3Bootstrap` (and the primary `s3Seed`) pass the access/secret
> keys to a `weed shell` command, so the chart restricts them to `[A-Za-z0-9/+=_.@-]` with no
> leading `-` (rejecting whitespace/flag injection at render time). Managed-S3 keys that need
> other characters should use `useDefaultChain=true` rather than static keys.

> **Rotating a tenant key** by re-running `s3Bootstrap` with a new
> `credentials.accessKey` *adds* the new key to the tenant's SeaweedFS identity but does
> **not** revoke the old one — the previous key stays valid. After a leak, delete the old
> key directly against the shared SeaweedFS (`weed shell` → `s3.accesskey.delete`).

> **Note on routing:** tenant HTTPRoutes are disabled by default (`gateway.enabled=false`).
> To enable host-based routing, set `openmrs-backend.gateway.enabled=true` and
> `openmrs-backend.gateway.hostnames` (and likewise for frontend). The shared charts'
> routes emit hostnames only when `gateway.hostnames` is non-empty, so the primary
> umbrella's hostless routes act as a catch-all while tenant routes match on specific
> hostnames — no collisions. Each tenant's frontend and backend sit behind a per-tenant
> hostname (e.g. `coast.example.com`), like the primary OpenMRS stack. Point that
> hostname at the gateway (DNS, or an `/etc/hosts` entry) to reach the SPA.

#### Tenant chart parameters

The tenant chart's own values, plus the most common shared-chart overrides it passes
through. For the full shared-chart surface, see `helm/openmrs-backend/values.yaml` and
`helm/openmrs-frontend/values.yaml`.

| Name | Description | Default |
|------|-------------|---------|
| `global.tenant.name` | Tenant identifier; sets the `app.kubernetes.io/tenant` label on backend/frontend pods | **required** |
| `global.defaultStorageClass` | StorageClass for tenant PVCs (overrides the shared chart default) | `""` |
| `openmrs-backend.db.url` | Full JDBC URL to the shared MariaDB | **required** |
| `openmrs-backend.db.hostname` | Shared MariaDB host, used by the backend's `wait-for-it` preflight (`OMRS_DB_HOSTNAME`) | **required** |
| `openmrs-backend.db.port` | Shared MariaDB port | `3306` |
| `openmrs-backend.db.username` | Tenant DB user; must be exactly `openmrs_<tenant>_user` when `dbBootstrap.enabled=true` | **required** |
| `openmrs-backend.db.password` | Tenant DB password | **required** |
| `dbBootstrap.enabled` | Render the MariaDB operator's `Database` / `User` / `Grant` CRs that auto-provision the tenant's DB/user/grants on the shared MariaDB | `true` |
| `dbBootstrap.mariaDbRef.name` | Name of the shared MariaDB CR to provision on | `openmrs-mariadb` |
| `dbBootstrap.mariaDbRef.namespace` | Namespace of the shared MariaDB CR | `openmrs` |
| `dbBootstrap.database` | Tenant database to provision on the shared MariaDB; default `openmrs_<tenant>` with hyphens normalized to underscores. Must contain `openmrs_<tenant>` and be the database in `openmrs-backend.db.url` — a mismatch or missing tenant name fails at render time | `openmrs_<tenant>` |
| `dbBootstrap.maxUserConnections` | Per-tenant `MAX_USER_CONNECTIONS` limit on the shared MariaDB | `20` |
| `dbBootstrap.cleanupPolicy` | Whether the DB/user are dropped on `helm uninstall`: `Skip` (safe default, keeps tenant data) or `Delete` | `Skip` |
| `openmrs-backend.gateway.enabled` | Enable Gateway API HTTPRoute for the backend (requires `gateway.hostnames` set) | `false` |
| `openmrs-backend.gateway.hostnames` | Hostnames for the backend HTTPRoute; must be non-empty when `gateway.enabled=true` | `[]` |
| `openmrs-backend.podLabels` | Extra labels for backend pods | `{}` |
| `openmrs-frontend.enabled` | Deploy the frontend | `true` |
| `openmrs-frontend.gateway.enabled` | Enable Gateway API HTTPRoute for the frontend (requires `gateway.hostnames` set) | `false` |
| `openmrs-frontend.gateway.hostnames` | Hostnames for the frontend HTTPRoute; must be non-empty when `gateway.enabled=true` | `[]` |
| `openmrs-frontend.spaPath` | URL path the SPA is served from (`SPA_PATH`) | `"/openmrs/spa"` |
| `openmrs-frontend.apiUrl` | SPA → backend API URL (`API_URL`) | `"/openmrs"` |
| `openmrs-frontend.defaultLocale` | Default UI locale (`SPA_DEFAULT_LOCALE`) | `"en"` |
| `openmrs-frontend.configUrls` | Distro config JSON URLs (`SPA_CONFIG_URLS`); omitted when empty | `""` |
| `openmrs-frontend.replicaCount` | Frontend replicas | `1` |
| `openmrs-frontend.podLabels` | Extra labels for frontend pods | `{}` |
| `openmrs-backend.replicaCount` | Backend replicas; `>1` requires clustered cache **and** shared storage (guarded) | `1` |
| `openmrs-backend.infinispan.clustered` | Clustered L2 cache (JGroups DNS_PING); required for `>1` replica | `false` |
| `openmrs-backend.autoscaling.enabled` | HPA for the backend (needs clustered cache + shared storage) | `false` |
| `openmrs-backend.autoscaling.minReplicas` / `.maxReplicas` | Backend HPA bounds | `1` / `5` |
| `openmrs-backend.autoscaling.targetCPUUtilizationPercentage` | Backend HPA CPU target | `80` |
| `openmrs-backend.traefikService.sticky.cookie.name` | Sticky-session cookie name; set per tenant to avoid collisions on the shared gateway | `"openmrs_session"` |
| `openmrs-backend.seaweedfs.enabled` | Use the primary's shared SeaweedFS for this tenant's object storage | `false` |
| `openmrs-backend.seaweedfs.s3.endpoint` | Primary's S3 endpoint (e.g. `http://openmrs-seaweedfs-s3.openmrs.svc.cluster.local:8333`) | `""` |
| `openmrs-backend.seaweedfs.s3.bucketName` | Tenant bucket; DNS-style. With `s3Bootstrap.enabled=true` must be exactly `openmrs-<tenant>` (`openmrs_<tenant>` is rejected as `InvalidBucketName`) | `""` |
| `openmrs-backend.seaweedfs.s3.region` | S3 region | `us-east-2` |
| `openmrs-backend.seaweedfs.s3.forcePathStyle` | Path-style addressing (`"true"` for SeaweedFS; `"false"` for managed S3) | `"true"` |
| `openmrs-backend.seaweedfs.s3.credentials.accessKey` / `.secretKey` | Tenant's bucket-scoped key; required when `seaweedfs.enabled` unless `useDefaultChain=true`. Charset `[A-Za-z0-9/+=_.@-]`, no leading `-`. With `s3Bootstrap.enabled=true` the access key must also contain the tenant name | `""` |
| `openmrs-backend.seaweedfs.s3.credentials.useDefaultChain` | Managed S3 with IRSA/instance creds: emit no static keys, waive the key requirement | `false` |
| `openmrs-frontend.autoscaling.enabled` | HPA for the frontend | `false` |
| `openmrs-frontend.autoscaling.minReplicas` / `.maxReplicas` / `.targetCPUUtilizationPercentage` | Frontend HPA bounds and CPU target | `1` / `5` / `80` |
| `s3Bootstrap.enabled` | Provision this tenant's bucket + bucket-scoped identity on the shared SeaweedFS | `false` |
| `s3Bootstrap.image` | SeaweedFS image for the bootstrap Job; match the deployed SeaweedFS version | `chrislusf/seaweedfs:4.31` |
| `s3Bootstrap.master` | Shared SeaweedFS master the Job talks to | `openmrs-seaweedfs-master.openmrs.svc.cluster.local:9333` |
| `s3Bootstrap.backoffLimit` | Job retry limit | `6` |
| `s3Bootstrap.activeDeadlineSeconds` | Job deadline; caps a hang on an unresolvable master. Keep under the install `--timeout` so a hang fails the Job, not helm | `240` |

Images and versions are inherited from the shared charts (backend `3.7.x-no-demo`,
frontend `3.7.x`); override via `openmrs-backend.image.*` / `openmrs-frontend.image.*`
if needed. Clustering, autoscaling, and shared object storage are the shared-chart
features in the rows above — enable them per tenant with the `replicaCount` /
`infinispan.clustered` / `autoscaling.*` and `seaweedfs.*` / `s3Bootstrap.*` values.

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

Prepend with the name of the service: `openmrs-backend`, `openmrs-frontend`, `mariadb`. (The `openmrs-operator` chart is installed separately - see the Scaling section for its values.)

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
| `openmrs-backend.seaweedfs.s3.credentials.admin.accessKey` / `.secretKey` | The primary backend's S3 credential, and the bucket-scoped identity the umbrella's `s3Seed` hook seeds (`Read/Write/List` on the primary's bucket only, **not** cluster-admin - it cannot reach tenant buckets). **This is the value to set/rotate for the primary's storage.** | `"openmrs"` / `"OpenMRS123"` |

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
| `seaweedfs.s3.enableAuth`                                    | `false` = filer-backed dynamic IAM: the gateway reads identities from the filer (so per-tenant `s3-bootstrap` identities are honoured and hot-reloaded) and the `s3Seed` hook seeds the primary's bucket-scoped identity. `true` = static `-config` file (admin-only; runtime per-tenant provisioning will not work). Auth is enforced either way. | `false`           |
| `s3Seed.enabled` / `.image` / `.activeDeadlineSeconds`       | Post-install hook that seeds the primary's own identity (scoped `Read/Write/List` on its bucket, not `Admin`, so the primary cannot reach tenant buckets) into the filer-backed IAM store (only rendered when `seaweedfs.s3.enableAuth=false`); the primary bucket it creates follows `openmrs-backend.seaweedfs.s3.bucketName`. Verifies the identity applied and fails the install otherwise. `activeDeadlineSeconds` caps the hook (it races cold-start when installed without `--wait`), kept under the install `--timeout`. | `true` / `"chrislusf/seaweedfs:4.31"` / `240` |
| `seaweedfs.s3.credentials.admin.accessKey` / `.secretKey`    | Static S3 admin credential, **only consumed when `seaweedfs.s3.enableAuth=true`**. In the default filer-backed mode it has no effect — set `openmrs-backend.seaweedfs.s3.credentials.admin.*` instead. | `"openmrs"` / `"OpenMRS123"` |
| `monitoring.enabled`                                          | Enable monitoring (deploys Grafana, Loki, Alloy)                                                | `false`           |
| `grafana.adminPassword`                                       | Grafana admin password                                                                          | `"Admin123"`      |
| `grafana.ingress.enabled` / `.hosts`                          | Ingress for Grafana (disabled when using HTTPRoute)                                              | `false` / `["localhost"]` |
| `grafana.httpRoute.enabled` / `.hostnames` / `.path`          | Gateway API HTTPRoute for Grafana                                                                | `false` / `["localhost"]` / `"/grafana"` |
| `backup.enabled`                                              | Deploy Velero backup resources (BackupStorageLocation, Schedule) for this namespace. Requires Velero to already be installed on the cluster | `false` |
| `backup.schedule`                                             | Cron schedule for the daily Velero backup                                                       | `"0 2 * * *"`     |
| `backup.ttl`                                                  | How long Velero keeps a backup before deleting it                                               | `"720h0m0s"`      |
| `backup.bucket`                                                | S3 bucket backups are stored in. Required when `backup.enabled=true`                             | `""`              |
| `backup.region`                                                | AWS region of the S3 bucket                                                                      | `"us-east-1"`     |
| `backup.s3ForcePathStyle`                                      | Set `true` for S3-compatible endpoints (SeaweedFS, MinIO); leave `false` for AWS S3               | `false`           |
| `backup.s3Url`                                                 | S3-compatible endpoint URL (e.g. the SeaweedFS S3 service). Leave empty for AWS S3. Also gates whether the bucket-setup Job runs | `""` |
| `backup.credentials.accessKey` / `.secretKey`                  | AWS credentials for Velero and the bucket-setup Job, stored as a Secret                           | `""` / `""`       |
| `backup.veleroNamespace`                                       | Namespace Velero is installed in                                                                 | `"velero"`        |
| `backup.restore.enabled`                                       | Deploy the scheduled restore CronJob. Restores the whole namespace from the latest completed backup on every run — intended for demo environments, not production | `false` |
| `backup.restore.schedule`                                      | Cron schedule for the scheduled restore                                                          | `"0 3 * * *"`     |
| `backup.restore.image`                                         | Image used to submit the scheduled Restore via kubectl                                            | `"registry.k8s.io/kubectl:v1.30.14"` |
| `backup.mariadbBackup.enabled`                                 | Deploy a dedicated CronJob that dumps MariaDB directly to S3, independent of Velero                | `false`           |
| `backup.mariadbBackup.schedule`                                | Cron schedule for the MariaDB dump                                                                | `"30 1 * * *"`    |
| `backup.mariadbBackup.image`                                   | Image used to run `mysqldump`. Empty defaults to `mariadb:<mariadb.image.tag>`                     | `""`              |
| `backup.mariadbBackup.bucket`                                  | S3 bucket the dump is uploaded to. Required when `backup.mariadbBackup.enabled=true`               | `""`              |
| `backup.mariadbBackup.region`                                  | AWS region of the S3 bucket                                                                        | `"us-east-1"`     |
| `backup.mariadbBackup.s3ForcePathStyle`                        | Set `true` for S3-compatible endpoints (adds `--no-sign-request` to the upload)                    | `false`           |
| `backup.mariadbBackup.s3Endpoint`                              | S3-compatible endpoint URL (MinIO, SeaweedFS, etc). Leave empty for AWS S3                          | `""`              |
| `backup.mariadbBackup.mariadbHost`                             | MariaDB primary host to dump from. Empty defaults to `{release}-mariadb-primary`                    | `""`              |
| `backup.mariadbBackup.rootPasswordSecret.name` / `.key`        | Secret/key holding the MariaDB root password used to run `mysqldump`. Empty name defaults to the umbrella's own MariaDB secret, which only exists when `global.mariadb.enabled=true` — **required** (render fails) when `global.mariadb.enabled=false`, same external-DB case `mariadbHost` above anticipates | `""` / `"root-password"` |
| `backup.mariadbBackup.credentials.accessKey` / `.secretKey`    | AWS credentials for uploading the dump to S3, stored as a Secret                                    | `""` / `""`       |

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

The primary's S3 credential is injected into the backend's Secret as
`storage.s3.accessKeyId`/`storage.s3.secretAccessKey` and, in the default filer-backed
mode, seeded into the gateway by the `s3Seed` hook. Both read
`openmrs-backend.seaweedfs.s3.credentials.admin.*`, so that is the single value to set.
The umbrella's top-level `seaweedfs.s3.credentials.admin.*` is a separate copy consumed
**only** by the third-party subchart's static config (`seaweedfs.s3.enableAuth=true`); if
you run that mode, keep the two in sync by hand — the subchart has its own values schema
and can't read Helm's `global.*`.

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

#### Prerequisites: Velero (backup and restore)

[Velero](https://velero.io/) must already be installed on the cluster with its
CRDs registered before setting `backup.enabled=true` — the chart does not deploy
Velero itself, only the `BackupStorageLocation`/`Schedule` resources that use it.
`helm/openmrs/templates/velero-crd-check.yaml` fails the install/upgrade with a
clear error (pointing at the [Velero install docs](https://velero.io/docs/latest/basic-install/))
if `backup.enabled=true` and the `velero.io/v1/Schedule` CRD isn't present on the
target cluster. To render the backup templates offline (CI, `helm template`
without a live `--kube-apiserver`), pass `--api-versions velero.io/v1/Schedule`
so the check doesn't fail on a rendering environment that has no cluster to ask.

Enabling `backup.enabled=true` deploys, in the release namespace:

- a `BackupStorageLocation` pointing at `backup.bucket` (via `backup.s3Url` for
  S3-compatible endpoints like the umbrella's own SeaweedFS, or AWS S3 directly)
- a daily `Schedule` (`backup.schedule`) that backs up the whole namespace, with
  a pre-backup hook that snapshots Elasticsearch first when
  `openmrs-backend.elasticsearch.enabled=true`
- a one-time post-install/post-upgrade Job that creates `backup.bucket` if it
  doesn't already exist (only when `backup.s3Url` is set, i.e. an S3-compatible
  endpoint rather than AWS S3)

Two independent, opt-in CronJobs build on top of that:

- `backup.restore.enabled=true` adds a CronJob that submits a Velero `Restore`
  from the latest completed backup of this release's `Schedule` on
  `backup.restore.schedule`. It restores the **entire namespace** unconditionally
  on every run with no check that anything is actually broken — enable this only
  for demo/ephemeral environments that want a daily reset to a known state, never
  in production. Use the Velero CLI for a real restore.
- `backup.mariadbBackup.enabled=true` adds a CronJob that dumps MariaDB directly
  to S3 (via `mysqldump`) on `backup.mariadbBackup.schedule`, independent of
  Velero — useful as a lighter-weight, faster-to-restore-from database-only backup
  alongside (or instead of) the full-namespace Velero backup.

### Security Notes (Production)

The default values in `kind-openmrs.yaml` are optimized for local development
and **must be reviewed before production use**:

| Concern | Local dev | Production |
|---------|-----------|------------|
| Grafana default credentials (`admin`/`Admin123`) | Safe — localhost only | **Must change** — use a strong password or SSO |
| SeaweedFS security (`enableSecurity: false`) | Safe — no external access | **Must enable** — otherwise data is publicly accessible |
| SeaweedFS S3 auth (`seaweedfs.s3.enableAuth: false`, filer-backed IAM) | Cluster-internal; brief pre-seed window (worst on the `true → false` upgrade) | Auth is enforced once the `s3Seed` hook seeds an identity. A brief pre-seed window accepts anonymous access on **a fresh install, or the `enableAuth: true → false` upgrade** from a released chart (which ships `true`). The upgrade is the worse case: helm rolls the gateway Deployment to the config-less version **before** the `post-upgrade` hook runs, so for the roll plus the seed Job anything in the cluster (tenant pods included) can read/write the primary's bucket unauthenticated — and on that path the bucket already holds data. The hook verifies and **fails the install** if seeding doesn't take, so the store is never left silently open in steady state. For a zero-length window on both paths, seed via a gateway initContainer (moving the seed to `pre-upgrade` does not help — its creds Secret would not exist yet on the first upgrade). |
| SeaweedFS Admin default credentials (`admin`/`Admin123`) | Safe — localhost only | **Must change** — use a strong password |
| HTTP (no TLS) | Fine — localhost only | **Must enable TLS** on the Gateway listener |
| HTTPRoute auth | Safe — traffic is cluster-internal only | **Add auth middleware** (e.g., OAuth, basic auth) via HTTPRoute filters or a reverse proxy |
| Sticky-session cookie `Secure` flag (`openmrs-backend.traefikService.sticky.cookie.secure`) | Set `false` to test multiple replicas on plain-HTTP Kind, or the cookie is dropped | **Keep `true`** (default), an HTTPS-only cookie |

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


If you made any changes in helm/openmrs-backend, helm/openmrs-frontend or helm/openmrs-operator you need to update 
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
├── openmrs-operator              # Cluster operators chart (MariaDB, ECK, Traefik, Gateway API, Metrics Server, Cluster Autoscaler)
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