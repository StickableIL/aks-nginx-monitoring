variable "resource_group_name" {
  description = "Name of the resource group"
  type        = string
}

variable "location" {
  description = "Azure region for resources"
  type        = string
}

variable "cluster_name" {
  description = "Name of the AKS cluster"
  type        = string
}

variable "kubernetes_version" {
  description = "Kubernetes version"
  type        = string
  default     = null # Will use latest stable version
}

variable "node_count" {
  description = "Number of nodes in the default node pool"
  type        = number
  default     = 2
}

variable "node_vm_size" {
  description = "Size of the node pool VMs"
  type        = string
  default     = "Standard_B2s"
}

variable "acr_name" {
  description = "Name of the Azure Container Registry"
  type        = string
}

variable "environment" {
  description = "Environment name for tagging"
  type        = string
  default     = "development"
}
