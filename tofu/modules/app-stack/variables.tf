# =============================================================================
# Module: app-stack — variables.tf
# Location: platform-infra/tofu/modules/app-stack/variables.tf
#
# Inputs for the app-stack module which creates the Secret (database
# credentials) and PersistentVolumeClaim (PostgreSQL data storage).
# =============================================================================

# The namespace where these resources will be created.
# This comes from the namespace module output.
variable "namespace" {
  type        = string
  description = "Namespace where the Secret and PVC will be created"
}

# The name of the app — used to name resources consistently.
variable "app_name" {
  type        = string
  description = "Name of the application — used to prefix resource names"
}

# ─── Database credentials ────────────────────────────────────────────────────
# These are marked sensitive = true which tells OpenTofu to:
#   1. Redact the value in plan and apply output
#   2. Never write them to the state file in plaintext
#
# In production you would pull these from a secrets manager (Vault, AWS SSM).
# For local development we accept them as variables and store in tfvars
# which is gitignored.

variable "db_name" {
  type        = string
  description = "PostgreSQL database name"
  default     = "airlinedb"
}

variable "db_username" {
  type        = string
  description = "PostgreSQL username"
  sensitive   = true
}

variable "db_password" {
  type        = string
  description = "PostgreSQL password"
  sensitive   = true
}

# ─── Storage ─────────────────────────────────────────────────────────────────

# How much persistent storage to allocate for PostgreSQL data.
# For local development 1Gi is plenty.
# In production this would be 50Gi-500Gi depending on data volume.
variable "storage_size" {
  type        = string
  description = "Size of the PersistentVolumeClaim for PostgreSQL data"
  default     = "1Gi"
}

# StorageClass controls how the PVC is provisioned.
# Kind ships with 'standard' which uses local-path-provisioner.
# On AWS EKS this would be 'gp3'. On GKE it would be 'standard-rwo'.
variable "storage_class" {
  type        = string
  description = "Kubernetes StorageClass for the PVC"
  default     = "standard"
}

variable "labels" {
  type        = map(string)
  description = "Labels to apply to all resources"
  default     = {}
}
