{{- define "openmrs.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{- define "openmrs.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{- define "openmrs.labels" -}}
helm.sh/chart: {{ include "openmrs.chart" . }}
{{ include "openmrs.selectorLabels" . }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}

{{- define "openmrs.selectorLabels" -}}
app.kubernetes.io/name: {{ include "openmrs.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}

{{/* Mirrors openmrs-backend.fullname exactly (fullnameOverride, nameOverride,
release-contains-name) so infra defined here that must reference the backend
(e.g. its MariaDB secret) computes the same name — keep the two in sync. */}}
{{- define "openmrs.backendFullname" -}}
{{- $backend := index .Values "openmrs-backend" -}}
{{- if $backend.fullnameOverride -}}
{{- $backend.fullnameOverride | trunc 63 | trimSuffix "-" -}}
{{- else -}}
{{- $name := default "openmrs-backend" $backend.nameOverride -}}
{{- if contains $name .Release.Name -}}
{{- .Release.Name | trunc 63 | trimSuffix "-" -}}
{{- else -}}
{{- printf "%s-%s" .Release.Name $name | trunc 63 | trimSuffix "-" -}}
{{- end -}}
{{- end -}}
{{- end }}

