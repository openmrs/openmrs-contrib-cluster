{{/*
Expand the name of the chart.
*/}}
{{- define "openmrs.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Create chart name and version as used by the chart label.
*/}}
{{- define "openmrs.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Common labels
*/}}
{{- define "openmrs.labels" -}}
helm.sh/chart: {{ include "openmrs.chart" . }}
{{ include "openmrs.selectorLabels" . }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}

{{/*
Selector labels
*/}}
{{- define "openmrs.selectorLabels" -}}
app.kubernetes.io/name: {{ include "openmrs.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}