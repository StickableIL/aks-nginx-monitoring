# AKS Nginx Monitoring Infrastructure

This project deploys a monitored Nginx application on Azure Kubernetes Service (AKS) using Terraform, ArgoCD, and Prometheus/Alertmanager for monitoring.

## Prerequisites

- Azure CLI installed and configured
- Terraform >= 1.0.0
- kubectl
- helm

## Terraform Deployment

1. Prerequisites Setup:
   ```bash
   # Login to Azure
   az login

   # Add required Helm repositories
   helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
   helm repo add argo-helm https://argoproj.github.io/argo-helm
   helm repo update
   ```

2. Default Configuration:
   The Terraform configuration includes these default values:
   - Resource Group: aks-nginx-monitoring-rg
   - Location: eastus
   - Cluster Name: aks-nginx-cluster
   - ACR Name: aksnginxmonitoring
   - Node Count: 2
   - VM Size: Standard_B2s

   Note: The ACR name must be globally unique. You may need to modify it if "aksnginxmonitoring" is already taken.

3. Deploy Infrastructure:
   ```bash
   terraform init
   terraform plan   # Review the changes
   terraform apply
   ```

4. Post-deployment Setup:
   ```bash
   # Get AKS credentials
   az aks get-credentials --resource-group aks-nginx-monitoring-rg --name aks-nginx-cluster

   # Verify deployments
   kubectl get pods -n monitoring
   kubectl get pods -n argocd
   ```

The deployment will create:
- AKS cluster with 2 nodes
- Azure Container Registry
- Prometheus monitoring stack
- ArgoCD deployment
- Required namespaces and RBAC configurations

## Project Structure

```
.
├── terraform/
│   ├── modules/
│   │   └── aks/
│   │       ├── main.tf
│   │       ├── variables.tf
│   │       └── outputs.tf
│   ├── main.tf
│   ├── variables.tf
│   └── outputs.tf
├── kubernetes/
│   ├── nginx/
│   │   ├── alertrule.yaml
│   │   ├── configmap.yaml
│   │   ├── deployment.yaml
│   │   ├── service.yaml
│   │   └── servicemonitor.yaml
│   ├── monitoring/
│   │   └── prometheus-values.yaml
│   └── argocd/
│       └── application.yaml
└── README.md
```

## Public Access URLs

- ArgoCD UI: http://57.152.14.57
- Nginx Application: http://135.237.2.156

## Quick Start

1. Clone this repository:
   ```bash
   git clone <repository-url>
   cd aks-nginx-monitoring
   ```

2. Initialize Terraform:
   ```bash
   cd terraform
   terraform init
   ```

3. Deploy the infrastructure:
   ```bash
   terraform apply
   ```

4. Configure kubectl:
   ```bash
   az aks get-credentials --resource-group <resource-group> --name <cluster-name>
   ```

5. Install ArgoCD:
   ```bash
   kubectl create namespace argocd
   kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml
   ```

6. Access ArgoCD UI:
   ```bash
   kubectl port-forward svc/argocd-server -n argocd 8080:443
   ```
   Get the initial admin password:
   ```bash
   kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d
   ```

7. Deploy the application using ArgoCD:
   ```bash
   kubectl apply -f kubernetes/argocd/application.yaml
   ```

## Monitoring

### Monitoring Architecture

The monitoring stack consists of both internal (ClusterIP) and external (LoadBalancer) services:

1. Internal Services:
   - `prometheus-operated`: Internal service created by Prometheus Operator that performs the actual metrics collection and alert evaluation
   - `alertmanager-operated`: Internal service that handles alert routing and management

2. External Services:
   - `prometheus-external`: LoadBalancer service (172.212.69.91:9090) that provides external access to the Prometheus UI
   - `alertmanager-external`: LoadBalancer service (20.242.176.155:9093) that provides external access to the Alertmanager UI

The monitoring flow works as follows:
1. The ServiceMonitor (kubernetes/nginx/servicemonitor.yaml) defines what to monitor:
   - Targets nginx pods with label 'app: nginx' in the default namespace
   - Scrapes metrics every 15 seconds from the metrics port
2. The internal prometheus-operated service:
   - Discovers the ServiceMonitor
   - Scrapes metrics from nginx based on the ServiceMonitor configuration
   - Evaluates alert rules (like NginxHighCPU)
3. The external services (prometheus-external and alertmanager-external):
   - Do not participate in the actual monitoring
   - Only provide external UI access to view the collected metrics, alerts, and manage the monitoring stack
   - Use selectors to route external traffic to the same pods that the internal services use

### Accessing Monitoring Services

Prometheus and Alertmanager are exposed via external IPs:

- Prometheus: http://172.212.69.91:9090
- Alertmanager: http://20.242.176.155:9093

### Using Prometheus UI

1. Key Pages to Check:
   - Targets: http://172.212.69.91:9090/targets (shows if nginx metrics scraping is working)
   - Alerts: http://172.212.69.91:9090/alerts (shows configured alert rules)
   - Rules: http://172.212.69.91:9090/rules (shows all prometheus rules)

2. Useful Prometheus Queries:
   ```
   # Container CPU Usage
   rate(container_cpu_usage_seconds_total{container="nginx"}[5m]) * 100

   # Container Memory Usage
   container_memory_usage_bytes{container="nginx"}

   # Container Restart Count
   kube_pod_container_status_restarts_total{container="nginx"}
   ```

### Testing Alerts

The following alerts are configured:

1. NginxHighCPUUsage Alert:
   - Triggers if CPU > 80% for 5 minutes
   - Query to monitor:
     ```
     rate(container_cpu_usage_seconds_total{container="nginx"}[5m]) * 100
     ```

2. NginxContainerRestarting Alert:
   - Triggers if > 2 restarts in 15 minutes
   - Query to monitor:
     ```
     changes(container_start_time_seconds{container="nginx"}[15m])
     ```

### Using Alertmanager UI

Access Alertmanager at http://20.242.176.155:9093 to:
- View active alerts
- Check silenced/inhibited alerts
- Review alert history

Note: The ServiceMonitor is configured to scrape metrics every 15 seconds, so any changes should be reflected in Prometheus with minimal delay.

## Cleanup

To destroy all resources:

```bash
terraform destroy
```

## Time Estimation

The estimated time to complete this setup is approximately 2 hours:
- Infrastructure setup: 45 minutes
- Monitoring configuration: 45 minutes
- ArgoCD setup and testing: 30 minutes

## Assumptions

1. Azure subscription is already configured
2. Azure CLI is installed and authenticated
3. Required Azure resource providers are registered
4. Terraform and kubectl are installed locally
5. Basic familiarity with Kubernetes concepts

## Notes

- The AKS cluster uses system-assigned managed identity
- Default node pool uses Standard_B2s VM size
- Monitoring is configured with basic CPU usage alerts
- ArgoCD is used for GitOps-based deployment
