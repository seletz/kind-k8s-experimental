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

![](images/grafana-kubelet.png)

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

![](images/grafana-pg.png)

```
# Install the Operator Manifest
kubectl apply --server-side -f \
  https://raw.githubusercontent.com/cloudnative-pg/cloudnative-pg/release-1.27/releases/cnpg-1.27.0.yaml

# Create a namespace for our new cluster
kubectl create namespace pg-example-cluster

# And provision a clister with 3 instances (1 master, 2 replicas)
kubectl apply -f pg-cluster-example.yml

# To enable scraping, label the podmonitor
kubectl label podmonitor pg-example-cluster release=monitoring

# Import the CloudNativePG Dashboard
kubectl apply -f cloudnative-pg-dashboard.yml
```

## CLI Management

Using the `krew` plugin `cnpg` we can manage PG clusters. (see [docs](https://cloudnative-pg.io/documentation/1.27/kubectl-plugin/#))

```
brew install kubectl-cnpg
```

(restart your shell)

Then you can do things like:

```
kubectl cnpg psql pg-example-cluster
psql (17.5 (Debian 17.5-1.pgdg110+1))
Type "help" for help.

postgres=#
```


# In-Cluster Management UI

Following the [docs](https://headlamp.dev/docs/latest/installation/in-cluster/)

![](images/headlamp.png)

```
# Apply the configuration
kubectl apply -f kubernetes-headlamp.yaml

# To have headlamp "see" cluster usage, we need to install metrics-server
# Downloaded from: https://github.com/kubernetes-sigs/metrics-server/releases/latest/download/components.yaml
# Modified for kind clusters by adding --kubelet-insecure-tls flag due to TLS certificate issues
#
# Diff applied to metrics-server Deployment spec.template.spec.containers[0].args:
#   - --cert-dir=/tmp
#   - --secure-port=10250
#   - --kubelet-preferred-address-types=InternalIP,ExternalIP,Hostname
#   - --kubelet-use-node-status-port
#   - --metric-resolution=15s
# + - --kubelet-insecure-tls
#
kubectl apply -f metrics-server-deployment.yaml
```

Use port-forward to access:

```
kubectl port-forward -n kube-system service/headlamp 8080:80
```

To access Headlamp, you'll need the service account token:

```
# Get the Headlamp access token
kubectl get secret headlamp-admin -n kube-system -o jsonpath='{.data.token}' | base64 -d ; echo
```

Copy this token and paste it into the Headlamp login screen when accessing the UI.

# Accessing All Services

Once everything is deployed, you can access all services via port-forwarding:

## Grafana Dashboard
```
kubectl port-forward -n monitoring service/monitoring-grafana 3000:80
```
Access: http://localhost:3000 (login: admin/[password from earlier])

## Prometheus
```
kubectl port-forward -n monitoring service/monitoring-kube-prometheus-prometheus 9090:9090
```
Access: http://localhost:9090

## Alertmanager
```
kubectl port-forward -n monitoring service/monitoring-kube-prometheus-alertmanager 9093:9093
```
Access: http://localhost:9093

## Headlamp (already covered above)
```
kubectl port-forward -n kube-system service/headlamp 8080:80
```
Access: http://localhost:8080
