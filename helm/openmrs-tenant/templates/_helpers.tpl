{{- define "openmrs-tenant.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{- define "openmrs-tenant.backend.name" -}}
{{- default "backend" .Values.backend.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{- define "openmrs-tenant.backend.fullname" -}}
{{- if .Values.backend.fullnameOverride }}
{{- .Values.backend.fullnameOverride | trunc 63 | trimSuffix "-" }}
{{- else }}
{{- printf "%s-%s" .Release.Name (default "backend" .Values.backend.nameOverride) | trunc 63 | trimSuffix "-" }}
{{- end }}
{{- end }}

{{- define "openmrs-tenant.backend.selectorLabels" -}}
app.kubernetes.io/name: {{ include "openmrs-tenant.backend.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}

{{- define "openmrs-tenant.backend.labels" -}}
helm.sh/chart: {{ include "openmrs-tenant.chart" . }}
{{ include "openmrs-tenant.backend.selectorLabels" . }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
app.kubernetes.io/tenant: {{ required "tenant.name is required" .Values.tenant.name }}
{{- end }}

{{- define "openmrs-tenant.backend.serviceAccountName" -}}
{{- if .Values.backend.serviceAccount.create }}
{{- default (include "openmrs-tenant.backend.fullname" .) .Values.backend.serviceAccount.name }}
{{- else }}
{{- default "default" .Values.backend.serviceAccount.name }}
{{- end }}
{{- end }}

{{- define "openmrs-tenant.frontend.name" -}}
{{- default "frontend" .Values.frontend.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{- define "openmrs-tenant.frontend.fullname" -}}
{{- if .Values.frontend.fullnameOverride }}
{{- .Values.frontend.fullnameOverride | trunc 63 | trimSuffix "-" }}
{{- else }}
{{- printf "%s-%s" .Release.Name (default "frontend" .Values.frontend.nameOverride) | trunc 63 | trimSuffix "-" }}
{{- end }}
{{- end }}

{{- define "openmrs-tenant.frontend.selectorLabels" -}}
app.kubernetes.io/name: {{ include "openmrs-tenant.frontend.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}

{{- define "openmrs-tenant.frontend.labels" -}}
helm.sh/chart: {{ include "openmrs-tenant.chart" . }}
{{ include "openmrs-tenant.frontend.selectorLabels" . }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
app.kubernetes.io/tenant: {{ required "tenant.name is required" .Values.tenant.name }}
{{- end }}

{{- define "openmrs-tenant.frontend.serviceAccountName" -}}
{{- if .Values.frontend.serviceAccount.create }}
{{- default (include "openmrs-tenant.frontend.fullname" .) .Values.frontend.serviceAccount.name }}
{{- else }}
{{- default "default" .Values.frontend.serviceAccount.name }}
{{- end }}
{{- end }}
