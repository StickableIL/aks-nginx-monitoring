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
│   │   ├── deployment.yaml
│   │   ├── service.yaml
│   │   └── configmap.yaml
│   ├── monitoring/
│   │   ├── prometheus-values.yaml
│   │   └── alertmanager-config.yaml
│   └── argocd/
│       └── application.yaml
└── README.md
```

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

### Accessing Prometheus

```bash
kubectl port-forward svc/prometheus-server -n monitoring 9090:9090
```
Access Prometheus UI at http://localhost:9090

### Accessing Alertmanager

```bash
kubectl port-forward svc/alertmanager -n monitoring 9093:9093
```
Access Alertmanager UI at http://localhost:9093

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
