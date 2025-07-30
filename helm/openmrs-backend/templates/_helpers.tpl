{{/*
Expand the name of the chart.
*/}}
{{- define "openmrs-backend.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Create a default fully qualified app name.
We truncate at 63 chars because some Kubernetes name fields are limited to this (by the DNS naming spec).
If release name contains chart name it will be used as a full name.
*/}}
{{- define "openmrs-backend.fullname" -}}
{{- if .Values.fullnameOverride }}
{{- .Values.fullnameOverride | trunc 63 | trimSuffix "-" }}
{{- else }}
{{- $name := default .Chart.Name .Values.nameOverride }}
{{- if contains $name .Release.Name }}
{{- .Release.Name | trunc 63 | trimSuffix "-" }}
{{- else }}
{{- printf "%s-%s" .Release.Name $name | trunc 63 | trimSuffix "-" }}
{{- end }}
{{- end }}
{{- end }}

{{/*
Create chart name and version as used by the chart label.
*/}}
{{- define "openmrs-backend.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Common labels
*/}}
{{- define "openmrs-backend.labels" -}}
helm.sh/chart: {{ include "openmrs-backend.chart" . }}
{{ include "openmrs-backend.selectorLabels" . }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}

{{/*
Selector labels
*/}}
{{- define "openmrs-backend.selectorLabels" -}}
app.kubernetes.io/name: {{ include "openmrs-backend.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}

{{/*
Create the name of the service account to use
*/}}
{{- define "openmrs-backend.serviceAccountName" -}}
{{- if .Values.serviceAccount.create }}
{{- default (include "openmrs-backend.fullname" .) .Values.serviceAccount.name }}
{{- else }}
{{- default "default" .Values.serviceAccount.name }}
{{- end }}
{{- end }}

{{/*
Get the service name of elastic search created by bitmani elastic helm chart
*/}}
{{- define "elasticsearch.serviceName" -}}
{{- $name := "elasticsearch" -}}
{{- $releaseName := regexReplaceAll "(-?[^a-z\\d\\-])+-?" (lower .Release.Name) "-" -}}
{{- if contains $name $releaseName -}}
{{- $releaseName | trunc 63 | trimSuffix "-" -}}
{{- else -}}
{{- printf "%s-%s" $releaseName $name | trunc 63 | trimSuffix "-" -}}
{{- end -}}
{{- end }}

{{/*
Create the url for the elastic search
*/}}
{{- define "openmrs-elasticsearch.url" -}}
{{- $releaseNameSpace := .Release.Namespace -}}
{{- $clusterDomain := "svc.cluster.local" }}
{{- $port := default "9200"  quote .Values.elasticsearch.service.ports.restAPI }}
{{- $fullurl := printf "%s%s.%s.%s:%s" "http://" (include "elasticsearch.serviceName" .) $releaseNameSpace $clusterDomain $port }}
{{- quote $fullurl }}
{{- end }}

{{- define "openmrs.default.serverOptions" -}}
{{- .Values.defaultOmrsServerOpts }}
{{- end }}

{{- define "infinispan.cache.jgroups.dnsQuery" -}}
{{- printf "_ping._tcp.%s-ping.%s.svc.%s" (include "openmrs-backend.fullname" .) .Release.Namespace .Values.infinispan.clusterDomain }}
{{- end }}

{{- define "infinispan.cache.args" }}
{{- printf "-Djgroups.dns.query=%s -Dcache.type=%s -Djgroups.bind.port=%s -Djgroups.port_range=%s -Djgroups.dns.record=SRV -Djgroups.bind.address=%s -Dcache.stack=kubernetes" (include "infinispan.cache.jgroups.dnsQuery" .)  "cluster"  (quote .Values.infinispan.bind_port) (quote .Values.infinispan.port_range) "SITE_LOCAL"}}
{{- end }}

{{- define "openmrs.serverOptions" -}}
{{- printf "%s %s" (include "openmrs.default.serverOptions" .) (include "infinispan.cache.args" .) }}
{{- end }}
