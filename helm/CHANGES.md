# ECK Elasticsearch Migration — Changes

## Problem

Elasticsearch was migrated from Bitnami to ECK operator (PR #8 TRUNK-6535), but Hibernate Search failed to bootstrap with the following sequence of errors:

1. **PKIX path building failed** — ECK's self-signed TLS certificate not trusted by JVM
2. **Hostname mismatch** — cert CN (`es.local`) didn't match URL (`svc.cluster.local`)
3. **401 Unauthorized** — no credentials sent to ECK Elasticsearch (security enabled by default)
4. **400 Bad Request** — `analysis-phonetic` plugin not installed

## Changes

### 1. `openmrs-backend/templates/_helpers.tpl` — Fix hostname mismatch

**Change**: ES URL now uses `service.namespace.svc` instead of `service.namespace.svc.cluster.local`.

**Why**: ECK certificates include `service.namespace.svc` in SAN entries, but `service.namespace.svc.cluster.local` doesn't match when the Kind cluster uses a custom domain (`es.local`). Using `.svc` (cluster-local DNS suffix without domain) matches the cert's SAN.

```diff
- https://<service>.<namespace>.svc.cluster.local:9200
+ https://<service>.<namespace>.svc:9200
```

### 2. `openmrs-backend/templates/configmap.yaml` — JVM truststore via env var

**Change**: Added `JAVA_TOOL_OPTIONS` with truststore path. Added `OMRS_EXTRA_HIBERNATE_SEARCH_BACKEND_SSL_VERIFICATION__MODE: "none"`.

**Why**: The backup startup script (`/openmrs/startup.sh`) overwrites `JAVA_OPTS`, so `-Djavax.net.ssl.trustStore=` set in the startup command gets lost. `JAVA_TOOL_OPTIONS` is read by the JVM directly and survives the startup script. The `__` → `.` conversion (double underscore → dot) correctly produces `hibernate.search.backend.ssl.verification_mode=none` (where the single underscore in `verification_mode` is a literal part of the property key).

### 3. `openmrs-backend/templates/statefulset.yaml` — Truststore, credentials, and volume mounts

**Changes**:

- **Volumes**: Added `es-ca-cert` (ECK's public certs secret), `es-truststore` (emptyDir shared between init and main container), and `es-cred` (ECK's elastic user secret).
- **Init container `import-es-ca`**: Copies the default JVM cacerts, imports the ECK CA cert via `keytool`, saves to the shared truststore.
- **Volume mounts**: Truststore at `/truststore`, ES credentials at `/etc/es-cred` in the main container.
- **Startup command**: Exports `OMRS_EXTRA_HIBERNATE_SEARCH_BACKEND_PASSWORD` by reading the mounted ECK secret file, then calls `exec /openmrs/startup.sh`.
- **Removed**: `env` entry with dotted name (`hibernate.search.backend.password`) — env vars with dots aren't processed by OpenMRS's startup script.

**Why ECK secret mount instead of `env` with `secretKeyRef`**: OpenMRS's `startup-init.sh` only processes env vars with the `OMRS_EXTRA_*` prefix. The `OMRS_EXTRA_HIBERNATE_SEARCH_BACKEND_PASSWORD` env var is set via `export` in the startup command (reading from the mounted secret file), which happens before `exec startup.sh`.

### 4. `openmrs-backend/templates/secret.yaml` — ES username via OMRS_EXTRA convention

**Change**: Added `OMRS_EXTRA_HIBERNATE_SEARCH_BACKEND_USERNAME: "elastic"` for ECK mode.

**Why**: The `hibernate.search.backend.username` property must use the `OMRS_EXTRA_*` prefix so OpenMRS's `startup-init.sh` processes it (converts single `_` to `.`, creating `hibernate.search.backend.username`).

**Important**: The transformation in `startup-init.sh` is:
- Single `_` → `.` (property path separator)
- Double `__` → `_` (literal underscore in property key)

So for `hibernate.search.backend.username` (all dots, no literal underscores), use single underscores between segments: `OMRS_EXTRA_HIBERNATE_SEARCH_BACKEND_USERNAME`. Do NOT use `__` (which would produce literal underscores instead of dots).

### 5. `kind-openmrs.yaml` — Complete ECK nodeSet config

**Changes**: Added anonymous access config, plugin init container, and resource limits that were missing from the `nodeSets` override.

```diff
 elasticsearch-eck:
   nodeSets:
     - name: default
       count: 1
       config:
         node.roles: [master, data, ingest]
         node.store.allow_mmap: false
+        xpack.security.authc.anonymous.username: anonymous
+        xpack.security.authc.anonymous.roles: superuser
+        xpack.security.authc.anonymous.authz_exception: false
+      podTemplate:
+        spec:
+          initContainers:
+            - name: install-plugins
+              command: [sh, -c, bin/elasticsearch-plugin install --batch analysis-phonetic]
+          containers:
+            - name: elasticsearch
+              resources:
+                requests: { cpu: 500m, memory: 2Gi, ephemeral-storage: 50Mi }
+                limits:   { cpu: 750m, memory: 2Gi, ephemeral-storage: 2Gi }
```

**Why**: `kind-openmrs.yaml` overrides the entire `nodeSets` array from `values.yaml`. Without these fields, anonymous access, the `analysis-phonetic` plugin, and resource limits were silently dropped.

**Plugin installation**: ECK 3.x (operator 3.4.0) doesn't support the `plugins` field at `nodeSets[].plugins` (returns "unknown field" API warning). Use an init container instead.

### 6. `openmrs-backend/values.yaml` — Contains plugins field (for ECK 2.x compatibility)

The `plugins: [- analysis-phonetic]` field remains in `values.yaml` as the default for potential ECK 2.x users. For ECK 3.x, override with the init container approach in your values override file.

## Architecture

```
ECK Elasticsearch (openmrs-elasticsearch-eck)
├── Service: openmrs-elasticsearch-eck-es-http (port 9200, HTTPS)
├── Secret: openmrs-elasticsearch-eck-es-http-certs-public (CA cert)
├── Secret: openmrs-elasticsearch-eck-es-elastic-user (password)
└── StatefulSet: openmrs-elasticsearch-eck-es-default
    └── Init container: install-plugins (analysis-phonetic)

OpenMRS Backend (openmrs-backend-0)
├── Init container: resolve-mariadb-hosts
├── Init container: import-es-ca
│   ├── Mount: es-ca-cert  → /etc/es-ca/ca.crt (ECK CA)
│   └── Mount: es-truststore → /truststore/cacerts (shared)
├── Main container: openmrs-backend
│   ├── Mount: es-truststore → /truststore (JVM truststore with ECK CA)
│   ├── Mount: es-cred → /etc/es-cred/elastic (ES password)
│   ├── Env from ConfigMap:
│   │   ├── OMRS_SEARCH_ES_URIS: https://openmrs-elasticsearch-eck-es-http.openmrs.svc:9200
│   │   ├── OMRS_EXTRA_HIBERNATE_SEARCH_BACKEND_SSL_VERIFICATION__MODE: none
│   │   └── JAVA_TOOL_OPTIONS: -Djavax.net.ssl.trustStore=...
│   ├── Env from Secret:
│   │   └── OMRS_EXTRA_HIBERNATE_SEARCH_BACKEND_USERNAME: elastic
│   └── Startup command sets:
│       ├── OMRS_EXTRA_HIBERNATE_SEARCH_BACKEND_PASSWORD (from /etc/es-cred/elastic)
│       └── JAVA_OPTS (truststore args + verification_mode)
```

## How to fix the `openmrs-backend/values.yaml` `plugins` field for ECK 3.x

Replace the `plugins:` line with the init container approach:

```yaml
elasticsearch-eck:
  nodeSets:
    - name: default
      ...
      # Remove:
      # plugins:
      #   - analysis-phonetic
      # Add:
      podTemplate:
        spec:
          initContainers:
            - name: install-plugins
              command:
                - sh
                - -c
                - bin/elasticsearch-plugin install --batch analysis-phonetic
```
