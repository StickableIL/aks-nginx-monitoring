output "resource_group_name" {
  description = "The name of the resource group"
  value       = azurerm_resource_group.main.name
}

output "kubernetes_cluster_name" {
  description = "The name of the AKS cluster"
  value       = module.aks.cluster_name
}

output "acr_login_server" {
  description = "The login server URL for Azure Container Registry"
  value       = module.aks.acr_login_server
}

output "acr_admin_username" {
  description = "The admin username for Azure Container Registry"
  value       = module.aks.acr_admin_username
}

output "acr_admin_password" {
  description = "The admin password for Azure Container Registry"
  value       = module.aks.acr_admin_password
  sensitive   = true
}

output "kube_config" {
  description = "The kubeconfig for the AKS cluster"
  value       = module.aks.kube_config
  sensitive   = true
}

output "host" {
  description = "The Kubernetes cluster server host"
  value       = module.aks.host
  sensitive   = true
}

output "configure_kubectl" {
  description = "Command to configure kubectl with the new cluster"
  value       = "az aks get-credentials --resource-group ${azurerm_resource_group.main.name} --name ${module.aks.cluster_name}"
}

output "monitoring_namespace" {
  description = "The Kubernetes namespace for monitoring"
  value       = "monitoring"
}

output "argocd_namespace" {
  description = "The Kubernetes namespace for ArgoCD"
  value       = "argocd"
}

output "access_argocd" {
  description = "Commands to access ArgoCD UI"
  value       = <<EOT
1. Port forward ArgoCD server:
   kubectl port-forward svc/argocd-server -n argocd 8080:443

2. Get initial admin password:
   kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d

3. Access ArgoCD UI:
   Open https://localhost:8080 in your browser
   Username: admin
   Password: (use password from step 2)
EOT
}

output "access_prometheus" {
  description = "Commands to access Prometheus UI"
  value       = <<EOT
1. Port forward Prometheus server:
   kubectl port-forward svc/prometheus-server -n monitoring 9090:9090

2. Access Prometheus UI:
   Open http://localhost:9090 in your browser
EOT
}

output "access_alertmanager" {
  description = "Commands to access Alertmanager UI"
  value       = <<EOT
1. Port forward Alertmanager:
   kubectl port-forward svc/alertmanager -n monitoring 9093:9093

2. Access Alertmanager UI:
   Open http://localhost:9093 in your browser
EOT
}
