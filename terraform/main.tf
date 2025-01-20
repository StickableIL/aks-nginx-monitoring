terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 4.0"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.0"
    }
    helm = {
      source  = "hashicorp/helm"
      version = "~> 2.0"
    }
  }

  required_version = ">= 1.0"
}

provider "azurerm" {
  features {}
  subscription_id = "8ff7e3ec-8391-4fb2-8400-6f7865f36f69"
}

resource "azurerm_resource_group" "main" {
  name     = var.resource_group_name
  location = var.location
  tags     = var.tags
}

module "aks" {
  source = "./modules/aks"

  resource_group_name = azurerm_resource_group.main.name
  location           = azurerm_resource_group.main.location
  cluster_name       = var.cluster_name
  kubernetes_version = var.kubernetes_version
  node_count        = var.node_count
  node_vm_size      = var.node_vm_size
  acr_name          = var.acr_name
  environment       = var.environment
}

# Configure providers after AKS cluster is created
provider "kubernetes" {
  host                   = module.aks.host
  client_certificate     = base64decode(module.aks.client_certificate)
  client_key             = base64decode(module.aks.client_key)
  cluster_ca_certificate = base64decode(module.aks.cluster_ca_certificate)
}

provider "helm" {
  kubernetes {
    host                   = module.aks.host
    client_certificate     = base64decode(module.aks.client_certificate)
    client_key             = base64decode(module.aks.client_key)
    cluster_ca_certificate = base64decode(module.aks.cluster_ca_certificate)
  }
}

# Add monitoring namespace
resource "kubernetes_namespace" "monitoring" {
  metadata {
    name = "monitoring"
  }
}

# Add ArgoCD namespace
resource "kubernetes_namespace" "argocd" {
  metadata {
    name = "argocd"
  }
}

# Install Prometheus and Alertmanager using Helm
resource "helm_release" "prometheus" {
  name       = "prometheus"
  repository = "https://prometheus-community.github.io/helm-charts"
  chart      = "kube-prometheus-stack"
  namespace  = kubernetes_namespace.monitoring.metadata[0].name

  set {
    name  = "alertmanager.enabled"
    value = "true"
  }

  set {
    name  = "grafana.enabled"
    value = "false"
  }

  depends_on = [kubernetes_namespace.monitoring]
}

# Install ArgoCD using Helm
resource "helm_release" "argocd" {
  name       = "argocd"
  repository = "https://argoproj.github.io/argo-helm"
  chart      = "argo-cd"
  namespace  = kubernetes_namespace.argocd.metadata[0].name

  depends_on = [kubernetes_namespace.argocd]
}

# Create a terraform.tfvars file for easy customization
resource "local_file" "terraform_tfvars" {
  filename = "${path.module}/terraform.tfvars"
  content  = <<-EOT
    resource_group_name = "${var.resource_group_name}"
    location           = "${var.location}"
    cluster_name       = "${var.cluster_name}"
    acr_name          = "${var.acr_name}"
    environment       = "${var.environment}"
    node_count        = ${var.node_count}
    node_vm_size      = "${var.node_vm_size}"
  EOT
}
