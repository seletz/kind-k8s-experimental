# Quickstart

```
# Install prerequisites
$ brew install kind lens helm

# Create empty cluster
$ kind create cluster --config kind-config.yml --name experimental

# Export Kubeconfig to clipboard (for importing into lens GUI)
kind get kubeconfig --name experimental | pbcopy
```

# Monitoring

```
# Add the Prometheus community Helm repository
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo add grafana https://grafana.github.io/helm-charts
helm repo update

# Install the complete stack
helm install monitoring prometheus-community/kube-prometheus-stack \
  --namespace monitoring \
  --create-namespace \
  --set prometheus.service.type=NodePort \
  --set grafana.service.type=NodePort \
  --set alertmanager.service.type=NodePort
  ```

  In Lens, switch to "prometheus" as metrics source, then switch to "Prometheus Operator".

To access grafana, first get the grafana admin password:

```
kubectl --namespace monitoring get secrets monitoring-grafana -o jsonpath="{.data.admin-password}" | base64 -d ; echo
```

Then add a port forward:

```
export POD_NAME=$(kubectl --namespace monitoring get pod -l "app.kubernetes.io/name=grafana,app.kubernetes.io/instance=monitoring" -oname)
kubectl --namespace monitoring port-forward $POD_NAME 3000
```

Now you can access http://localhost:3000

The default installation adds many useful dashboards.

# PostgreSQL: CloudNativePG

Following the [docs](https://cloudnative-pg.io/documentation/1.27/installation_upgrade/)

```
# Install the Operator Manifest
kubectl apply --server-side -f \
  https://raw.githubusercontent.com/cloudnative-pg/cloudnative-pg/release-1.27/releases/cnpg-1.27.0.yaml

# Create a namespace for our new cluster
kubectl create namespace pg-example-cluster

# And provision a clister with 3 instances (1 master, 2 replicas)
kubectl apply -f pg-cluster-example.yml

# Import the CloudNativePG Dashboard
kubectl apply -f cloudnative-pg-dashboard.yml
```
