{{- /*
Standard labels for every K8s resource the tenant chart renders.
Use in metadata.labels via: {{ include "openmrs-tenant.labels" . | nindent N }}
*/}}
{{- define "openmrs-tenant.labels" -}}
app.kubernetes.io/name: openmrs-tenant
app.kubernetes.io/instance: {{ .Release.Name }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
app.kubernetes.io/tenant: {{ .Values.global.tenant.name | quote }}
{{- end }}

{{- /*
The tenant-scoped name openmrs_<tenant> (hyphens become underscores so it stays
consistent with the openmrs_<tenant> JDBC URL convention). Both the default
database name and the required DB username are built from it.
*/}}
{{- define "openmrs-tenant.normalizedTenant" -}}
{{- printf "openmrs_%s" (.Values.global.tenant.name | toString | replace "-" "_") -}}
{{- end }}

{{- define "openmrs-tenant.dbName" -}}
{{- .Values.dbBootstrap.database | default (include "openmrs-tenant.normalizedTenant" .) -}}
{{- end }}
