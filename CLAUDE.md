# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

This repository contains a Kubernetes experimental setup using kind (Kubernetes in Docker) with monitoring, PostgreSQL, and management UI components. It's designed for local development and testing of Kubernetes deployments with a complete observability stack.

## Architecture

The setup consists of:

- **kind cluster**: Multi-node local Kubernetes cluster (1 control-plane + 3 worker nodes)
- **Monitoring stack**: Prometheus, Grafana, and Alertmanager via kube-prometheus-stack
- **PostgreSQL**: CloudNativePG operator for PostgreSQL clusters with monitoring integration
- **Management UI**: Headlamp for in-cluster Kubernetes management
- **Observability**: Pre-configured Grafana dashboards for PostgreSQL monitoring

## Common Commands

### Cluster Management
```bash
# Create the experimental cluster
kind create cluster --config kind-config.yml --name experimental

# Delete the cluster
kind delete cluster --name experimental

# Get kubeconfig (for Lens or other tools)
kind get kubeconfig --name experimental | pbcopy
```

### Prerequisites Installation
```bash
brew install kind lens helm
```

### Monitoring Stack Setup
```bash
# Add Helm repositories
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo add grafana https://grafana.github.io/helm-charts
helm repo update

# Install monitoring stack (using inline NodePort settings from README)
helm install monitoring prometheus-community/kube-prometheus-stack \
  --namespace monitoring \
  --create-namespace \
  --set prometheus.service.type=NodePort \
  --set grafana.service.type=NodePort \
  --set alertmanager.service.type=NodePort

# Get Grafana admin password
kubectl --namespace monitoring get secrets monitoring-grafana -o jsonpath="{.data.admin-password}" | base64 -d ; echo

# Port forward to access Grafana
export POD_NAME=$(kubectl --namespace monitoring get pod -l "app.kubernetes.io/name=grafana,app.kubernetes.io/instance=monitoring" -oname)
kubectl --namespace monitoring port-forward $POD_NAME 3000
```

### PostgreSQL Setup
```bash
# Install CloudNativePG operator
kubectl apply --server-side -f \
  https://raw.githubusercontent.com/cloudnative-pg/cloudnative-pg/release-1.27/releases/cnpg-1.27.0.yaml

# Create PostgreSQL cluster with monitoring
kubectl create namespace pg-example-cluster
kubectl apply -f pg-cluster-example.yml

# Import CloudNativePG dashboard to Grafana
kubectl apply -f cloudnative-pg-dashboard.yml
```

### Management UI Setup
```bash
# Deploy Headlamp in-cluster UI
kubectl apply -f kubernetes-headlamp.yaml

# Install metrics-server for resource usage visibility
kubectl apply -f https://github.com/kubernetes-sigs/metrics-server/releases/latest/download/components.yaml
```

## Key Configuration Files

- `kind-config.yml`: Multi-node kind cluster configuration
- `kube-prometheus-stack-values.yml`: Custom Helm values for monitoring stack with PostgreSQL monitoring selectors
- `pg-cluster-example.yml`: CloudNativePG cluster definition with 3 instances and monitoring enabled
- `cloudnative-pg-dashboard.yml`: Grafana ConfigMap for PostgreSQL monitoring dashboard
- `kubernetes-headlamp.yaml`: In-cluster Headlamp deployment with observability features
- `grafana-dashboard.json`: Additional Grafana dashboard configuration

## Development Workflow

1. Create kind cluster with `kind create cluster --config kind-config.yml --name experimental`
2. Install monitoring stack using Helm with custom values
3. Deploy PostgreSQL clusters using CloudNativePG manifests
4. Import monitoring dashboards to Grafana
5. Access services via kubectl port-forward or NodePort services
6. Use Lens GUI for visual cluster management (import kubeconfig)

## Service Access

All services are accessed via kubectl port-forward:

```bash
# Grafana (monitoring dashboards)
kubectl port-forward -n monitoring service/monitoring-grafana 3000:80
# Access: http://localhost:3000 (admin/[generated-password])

# Prometheus (metrics collection)
kubectl port-forward -n monitoring service/monitoring-kube-prometheus-prometheus 9090:9090
# Access: http://localhost:9090

# Alertmanager (alert management)
kubectl port-forward -n monitoring service/monitoring-kube-prometheus-alertmanager 9093:9093
# Access: http://localhost:9093

# Headlamp (Kubernetes dashboard)
kubectl port-forward -n kube-system service/headlamp 8080:80
# Access: http://localhost:8080 (requires service account token)

# Get Grafana admin password
kubectl get secret -n monitoring monitoring-grafana -o jsonpath="{.data.admin-password}" | base64 -d ; echo

# Get Headlamp access token
kubectl get secret headlamp-admin -n kube-system -o jsonpath='{.data.token}' | base64 -d ; echo
```

## Monitoring Integration

The setup includes integrated monitoring where:
- PostgreSQL clusters automatically expose metrics via PodMonitor
- Grafana includes pre-configured dashboards for PostgreSQL observability
- Prometheus is configured to scrape PostgreSQL metrics using label selectors
- Headlamp includes observability features with OTLP endpoint configuration