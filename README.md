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

## Configuring Access

By default, all services are deployed with ClusterIP type for internal access. To expose services externally, you have several options:

1. Azure Application Gateway Ingress Controller (AGIC):
   - Recommended for production environments
   - Provides WAF capabilities and SSL termination
   - Configure in the terraform/modules/aks/main.tf file

2. Nginx Ingress Controller:
   ```bash
   # Install Nginx Ingress Controller
   helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx
   helm repo update
   helm install nginx-ingress ingress-nginx/ingress-nginx
   ```

3. Port Forwarding (for development/testing):
   ```bash
   # For ArgoCD UI
   kubectl port-forward svc/argocd-server -n argocd 8080:443

   # For Prometheus
   kubectl port-forward svc/prometheus-operated -n monitoring 9090:9090

   # For Alertmanager
   kubectl port-forward svc/alertmanager-operated -n monitoring 9093:9093

   # For Nginx application
   kubectl port-forward svc/nginx 8000:80
   ```

## Quick Start

1. Clone this repository:
   ```bash
   git clone <repository-url>
   cd aks-nginx-monitoring
   ```

2. Login to Azure:
   ```bash
   az login
   # Verify your subscription
   az account show
   # If needed, set specific subscription
   # az account set --subscription <subscription-id>
   ```

3. Initialize Terraform:
   ```bash
   cd terraform
   terraform init
   ```

4. Deploy the infrastructure:
   ```bash
   terraform apply
   ```

5. Configure kubectl:
   ```bash
   az aks get-credentials --resource-group <resource-group> --name <cluster-name>
   ```

6. Install ArgoCD:
   ```bash
   kubectl create namespace argocd
   kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml
   ```

7. Access ArgoCD UI using port-forward:
   ```bash
   kubectl port-forward svc/argocd-server -n argocd 8080:443
   ```
   Get the initial admin password:
   ```bash
   kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d
   ```

8. Deploy the application using ArgoCD:
   ```bash
   kubectl apply -f kubernetes/argocd/application.yaml
   ```

## Monitoring

### Monitoring Architecture

The monitoring stack consists of internal (ClusterIP) services:

1. Internal Services:
   - `prometheus-operated`: Internal service created by Prometheus Operator that performs the actual metrics collection and alert evaluation
   - `alertmanager-operated`: Internal service that handles alert routing and management

The monitoring flow works as follows:
1. The ServiceMonitor (kubernetes/nginx/servicemonitor.yaml) defines what to monitor:
   - Targets nginx pods with label 'app: nginx' in the default namespace
   - Scrapes metrics every 15 seconds from the metrics port
2. The prometheus-operated service:
   - Discovers the ServiceMonitor
   - Scrapes metrics from nginx based on the ServiceMonitor configuration
   - Evaluates alert rules (like NginxHighCPU)

### Accessing Monitoring Services

Use port-forwarding to access the monitoring services:

```bash
# Access Prometheus UI
kubectl port-forward svc/prometheus-operated -n monitoring 9090:9090

# Access Alertmanager UI
kubectl port-forward svc/alertmanager-operated -n monitoring 9093:9093
```

### Using Prometheus UI

1. Key Pages to Check (after port-forwarding):
   - Targets: http://localhost:9090/targets (shows if nginx metrics scraping is working)
   - Alerts: http://localhost:9090/alerts (shows configured alert rules)
   - Rules: http://localhost:9090/rules (shows all prometheus rules)

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

Access Alertmanager using port-forward to:
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
- All services are internal by default - configure ingress or use port-forwarding based on your requirements
