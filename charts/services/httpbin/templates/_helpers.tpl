{{/* vim: set filetype=mustache: */}}
{{/*
Expand the name of the chart.
*/}}
{{- define "httpbin.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{/*
Create a default fully qualified app name.
We truncate at 63 chars because some Kubernetes name fields are limited to this (by the DNS naming spec).
If release name contains chart name it will be used as a full name.
*/}}
{{- define "httpbin.fullname" -}}
{{- if .Values.fullnameOverride -}}
{{- .Values.fullnameOverride | trunc 63 | trimSuffix "-" -}}
{{- else -}}
{{- $name := default .Chart.Name .Values.nameOverride -}}
{{- if contains $name .Release.Name -}}
{{- .Release.Name | trunc 63 | trimSuffix "-" -}}
{{- else -}}
{{- printf "%s-%s" .Release.Name $name | trunc 63 | trimSuffix "-" -}}
{{- end -}}
{{- end -}}
{{- end -}}

{{/*
Create chart name and version as used by the chart label.
*/}}
{{- define "httpbin.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{/*
Common labels
*/}}
{{- define "httpbin.labels" -}}
helm.sh/chart: {{ include "httpbin.chart" . }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{ include "httpbin.deploymentSelectorLabels" . }}
{{- end -}}

{{/*
Deployment selector labels
*/}}
{{- define "httpbin.deploymentSelectorLabels" -}}
{{ include "httpbin.selectorLabels" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- if .Values.version }}
version: {{ .Values.version }}
{{- end }}
{{- end -}}

{{/*
Service selector labels
*/}}
{{- define "httpbin.serviceSelectorLabels" -}}
{{ include "httpbin.selectorLabels" . }}
{{- if not .Values.version }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}
{{- end -}}

{{/*
Selector labels
*/}}
{{- define "httpbin.selectorLabels" -}}
app.kubernetes.io/name: {{ include "httpbin.name" . }}
{{- if .Values.version }}
app: {{ include "httpbin.name" . }}
{{- end }}
{{- end -}}

{{/*
Create the name of the service account to use
*/}}
{{- define "httpbin.serviceAccountName" -}}
{{- if .Values.serviceAccount.create -}}
    {{ default (include "httpbin.fullname" .) .Values.serviceAccount.name }}
{{- else -}}
    {{ default "default" .Values.serviceAccount.name }}
{{- end -}}
{{- end -}}
