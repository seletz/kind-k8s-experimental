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
helm repo add headlamp https://kubernetes-sigs.github.io/headlamp/ 2>/dev/null || true
helm repo update > /dev/null

# Legacy validation for backwards compatibility
helm template kube-prometheus-stack prometheus-community/kube-prometheus-stack \
  --namespace monitoring \
  --dry-run > /dev/null

# Enhanced validation: template and lint all HelmReleases with their actual values
find infrastructure -name "helm-release.yaml" -type f | while read -r helmrelease_file; do
  echo "INFO - Validating HelmRelease: $helmrelease_file"
  
  # Extract chart, repo, and values from HelmRelease
  chart_name=$(yq e '.spec.chart.spec.chart' "$helmrelease_file")
  repo_name=$(yq e '.spec.chart.spec.sourceRef.name' "$helmrelease_file") 
  namespace=$(yq e '.spec.targetNamespace // .metadata.namespace' "$helmrelease_file")
  
  # Create temporary values file
  values_file="/tmp/helm-values-$(basename "$helmrelease_file" .yaml).yaml"
  yq e '.spec.values' "$helmrelease_file" > "$values_file"
  
  # Validate with helm template and lint
  if [ "$chart_name" != "null" ] && [ "$repo_name" != "null" ]; then
    helm template test-release "$repo_name/$chart_name" \
      --namespace "$namespace" \
      --values "$values_file" \
      --validate \
      --dry-run > /dev/null
    
    helm lint "$repo_name/$chart_name" \
      --values "$values_file" > /dev/null
  fi
  
  # Cleanup
  rm -f "$values_file"
done

echo "🚀 Validating Kubernetes manifests..."
find clusters -name "*.yaml" -o -name "*.yml" | xargs kubeconform -strict -ignore-missing-schemas -schema-location default -schema-location /tmp/flux-crd-schemas -verbose

echo "🔧 Validating Kustomize overlays..."
find . -type f -name "kustomization.y*ml" -print0 | while IFS= read -r -d $'\0' file; do
  dir="${file%/*}"
  echo "INFO - Validating kustomization $dir"
  kustomize build "$dir" | kubeconform -strict -ignore-missing-schemas -schema-location default -schema-location /tmp/flux-crd-schemas
done

echo "✅ All validations passed!"