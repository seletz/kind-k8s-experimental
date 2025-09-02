#!/bin/bash
set -e

echo "📥 Downloading Flux OpenAPI schemas..."
mkdir -p /tmp/flux-crd-schemas
curl -sSL https://github.com/fluxcd/flux2/releases/latest/download/crd-schemas.tar.gz | tar zxf - -C /tmp/flux-crd-schemas

echo "🔍 Validating YAML syntax..."
find . -type f \( -name "*.yaml" -o -name "*.yml" \) | xargs -I {} yq e . {} > /dev/null

echo "🎯 Validating Helm releases..."
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts 2>/dev/null || true
helm repo add grafana https://grafana.github.io/helm-charts 2>/dev/null || true
helm repo update > /dev/null

helm template kube-prometheus-stack prometheus-community/kube-prometheus-stack \
  --namespace monitoring \
  --dry-run > /dev/null

echo "🚀 Validating Kubernetes manifests..."
find clusters -name "*.yaml" -o -name "*.yml" | xargs kubeconform -strict -ignore-missing-schemas -schema-location default -schema-location /tmp/flux-crd-schemas -verbose

echo "🔧 Validating Kustomize overlays..."
find . -type f -name "kustomization.y*ml" -print0 | while IFS= read -r -d $'\0' file; do
  dir="${file%/*}"
  echo "INFO - Validating kustomization $dir"
  kustomize build "$dir" | kubeconform -strict -ignore-missing-schemas -schema-location default -schema-location /tmp/flux-crd-schemas
done

echo "✅ All validations passed!"