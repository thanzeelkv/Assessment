
variable "project_name" {
  description = "Short project identifier used in resource naming"
  type        = string
  default     = "aksassess"
}

variable "environment" {
  description = "Deployment environment (dev | staging | prod)"
  type        = string
  default     = "dev"

  validation {
    condition     = contains(["dev", "staging", "prod"], var.environment)
    error_message = "environment must be one of: dev, staging, prod."
  }
}

variable "location" {
  description = "Azure region for all resources"
  type        = string
  default     = "eastus"
}

variable "tags" {
  description = "Common tags applied to every resource"
  type        = map(string)
  default = {
    ManagedBy   = "Terraform"
    Project     = "AKS-Assessment"
    Owner       = "DevOps"
  }
}

variable "kubernetes_version" {
  description = "Kubernetes version for the AKS cluster"
  type        = string
  default     = "1.29"
}

variable "system_node_count" {
  description = "Number of nodes in the system node pool"
  type        = number
  default     = 2
}

variable "system_node_vm_size" {
  description = "VM SKU for system node pool"
  type        = string
  default     = "Standard_D2s_v3"
}

variable "user_node_min_count" {
  description = "Minimum node count for the user node pool (auto-scale)"
  type        = number
  default     = 1
}

variable "user_node_max_count" {
  description = "Maximum node count for the user node pool (auto-scale)"
  type        = number
  default     = 5
}

variable "user_node_vm_size" {
  description = "VM SKU for user node pool"
  type        = string
  default     = "Standard_D4s_v3"
}

variable "acr_sku" {
  description = "ACR SKU (Basic | Standard | Premium)"
  type        = string
  default     = "Standard"
}

variable "key_vault_sku" {
  description = "Key Vault SKU (standard | premium)"
  type        = string
  default     = "standard"
}
