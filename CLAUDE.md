# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

This repository contains a Kubernetes experimental setup using kind (Kubernetes in Docker) with GitOps via Flux CD. It includes monitoring, PostgreSQL, and management UI components deployed declaratively. It's designed for local development and testing of Kubernetes deployments with a complete observability stack using GitOps best practices.

## Architecture

The setup consists of:

- **kind cluster**: Multi-node local Kubernetes cluster (1 control-plane + 3 worker nodes)
- **GitOps**: Flux CD for declarative infrastructure management
- **Infrastructure controllers**: Helm repositories and CloudNativePG operator via Flux
- **Infrastructure configs**: Applications deployed after controllers are ready
- **Monitoring stack**: Prometheus, Grafana, and Alertmanager via HelmRelease
- **PostgreSQL**: CloudNativePG operator and clusters with monitoring integration
- **Management UI**: Headlamp for in-cluster Kubernetes management with metrics-server
- **Validation**: Local and CI validation of GitOps configuration

## Common Commands

### Cluster Management
```bash
# Create the experimental cluster
mise run create_cluster
# Or manually: kind create cluster --config kind-config.yml --name experimental

# Delete the cluster
mise run delete_cluster

# Get kubeconfig (for Lens or other tools)
mise run prepare_kubeconfig
```

### Prerequisites Installation
```bash
brew install kind lens helm
# mise will handle other tools (flux, kustomize, etc.)
```

### GitOps Workflow
```bash
# Bootstrap Flux (one-time setup)
flux bootstrap github \
  --owner=seletz \
  --repository=kind-k8s-experimental \
  --branch=develop \
  --path=clusters/local-kind \
  --personal

# Check Flux status
mise run flux_check
mise run flux_kustomisations

# Validate GitOps configuration locally (before push)
mise run validate

# Monitor deployment status
flux get kustomizations --watch
kubectl get pods -A --watch
```

### Manual Access (if needed)
```bash
# Force reconciliation
flux reconcile kustomization infra-controllers --with-source
flux reconcile kustomization infra-configs --with-source

# Check specific component status
kubectl get helmreleases -A
kubectl get pods -n cnpg-system  # CloudNativePG
kubectl get pods -n monitoring    # Prometheus stack
kubectl get pods -n kube-system | grep -E "(headlamp|metrics-server)"
```

## Key Configuration Files

### GitOps Structure
- `clusters/local-kind/`: Flux cluster configuration
  - `flux-system/`: Flux bootstrap manifests  
  - `infrastructure.yaml`: Infrastructure kustomizations with dependencies
- `infrastructure/`: Two-phase infrastructure deployment
  - `controllers/`: Phase 1 - Helm repositories and operators
  - `configs/`: Phase 2 - Applications (depends on controllers)

### Infrastructure Components
- `kind-config.yml`: Multi-node kind cluster configuration
- `infrastructure/configs/monitoring/`: Prometheus/Grafana HelmRelease
- `infrastructure/configs/postgresql/`: CloudNativePG cluster and dashboard
- `infrastructure/configs/headlamp/`: Kubernetes dashboard and metrics-server
- `scripts/validate.sh`: GitOps validation script

### Development Tools
- `mise.toml`: Tool management and task automation
- `.github/workflows/test.yaml`: CI validation workflow

## Development Workflow

1. Create kind cluster: `mise run create_cluster`
2. Bootstrap Flux: `flux bootstrap github ...` (one-time)
3. Make infrastructure changes in Git
4. Validate locally: `mise run validate`
5. Commit and push changes
6. Flux automatically syncs and deploys
7. Monitor with: `flux get kustomizations --watch`
8. Access services via port-forward

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
- Grafana includes pre-configured dashboards for PostgreSQL and Flux observability
- Prometheus is configured to scrape PostgreSQL and Flux controller metrics
- Headlamp includes observability features with OTLP endpoint configuration

### Key Monitoring Configuration Lessons

**Prometheus PodMonitor Discovery:**
- Default kube-prometheus-stack uses `podMonitorSelectorNilUsesHelmValues: true`
- Must set to `false` to discover PodMonitors without matching Helm labels
- Use `podMonitorSelector: {}` to discover all PodMonitors across namespaces

**CloudNativePG Integration:**
- Operator must be deployed in `cnpg-system` namespace for proper webhook operation
- Auto-generated PodMonitors only have `cnpg.io/cluster` labels by default
- Use operator label inheritance via `INHERITED_LABELS` configuration for custom labels
- Webhook connectivity requires proper DNS names and port configuration (port 9443)

**Flux Controller Metrics:**
- Flux controllers expose metrics on `http-prom` port (8080)
- Requires dedicated PodMonitor to scrape controller metrics for dashboard visibility
- Flux Control Plane dashboard needs `flux-system` namespace parameter to show data

**GitOps Troubleshooting:**
- Use `wait: false` temporarily to bypass stuck health checks during reconciliation
- HelmRelease label conflicts (commonLabels) can cause YAML parsing errors
- Two-phase deployment (controllers → configs) prevents dependency issues