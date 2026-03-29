# =============================================================================
# Environment: local — main.tf
# Location: platform-infra/tofu/envs/local/main.tf
#
# Wires the namespace and app-stack modules together for the local
# Kind cluster environment.
#
# This is the entry point — running 'tofu apply' from this directory
# creates all resources defined by both modules.
#
# Usage:
#   cd platform-infra/tofu/envs/local
#   tofu init
#   tofu plan
#   tofu apply
# =============================================================================

# ─────────────────────────────────────────────────────────────────────────────
# Provider configuration
# ─────────────────────────────────────────────────────────────────────────────
# The kubernetes provider connects to the cluster.
# config_path points to your kubeconfig file.
# config_context tells it which cluster to use — our Kind cluster.
#
# The provider reads the same kubeconfig that kubectl uses.
# Running 'kubectl config current-context' should show kind-platform-local.
terraform {
  required_version = ">= 1.6"

  required_providers {
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.27"
    }
  }

  # Backend configuration — where OpenTofu stores state.
  # 'local' means state is stored in terraform.tfstate in this directory.
  # This file is gitignored — never commit state files.
  # In production you would use a remote backend (S3, GCS, Terraform Cloud).
  backend "local" {
    path = "terraform.tfstate"
  }
}

provider "kubernetes" {
  # Path to your kubeconfig file
  # ~/ expands to your home directory
  config_path = "~/.kube/config"

  # The context to use — must match the Kind cluster name
  # 'kind create cluster --name platform-local' creates context 'kind-platform-local'
  config_context = "kind-platform-local"
}

# ─────────────────────────────────────────────────────────────────────────────
# Module: namespace
# ─────────────────────────────────────────────────────────────────────────────
# Calls the namespace module to create the namespace, ServiceAccount,
# Role, and RoleBinding for the airline app.
#
# module "name" { source = "path/to/module" } is how you call a module.
# The source path is relative to this file.
module "namespace" {
  source = "../../modules/namespace"

  # Pass values to the module's input variables
  namespace            = var.app_name
  service_account_name = "app"

  # Common labels applied to all resources for traceability
  labels = {
    "app"         = var.app_name
    "environment" = "local"
    "managed-by"  = "opentofu"
  }
}

# ─────────────────────────────────────────────────────────────────────────────
# Module: app-stack
# ─────────────────────────────────────────────────────────────────────────────
# Calls the app-stack module to create the database Secret and PVC.
#
# Notice how we use module.namespace.namespace_name — this references
# the output from the namespace module above. OpenTofu automatically
# creates the namespace before the app-stack because of this dependency.
module "app_stack" {
  source = "../../modules/app-stack"

  # Use the namespace created by the namespace module
  # This creates an implicit dependency — OpenTofu runs namespace first
  namespace = module.namespace.namespace_name
  app_name  = var.app_name

  # Database credentials from variables (set in terraform.tfvars)
  db_name     = var.db_name
  db_username = var.db_username
  db_password = var.db_password

  # Storage configuration for Kind cluster
  storage_size  = "1Gi"
  storage_class = "standard"

  labels = {
    "app"         = var.app_name
    "environment" = "local"
    "managed-by"  = "opentofu"
  }
}

# ─────────────────────────────────────────────────────────────────────────────
# Outputs — values printed after 'tofu apply' completes
# ─────────────────────────────────────────────────────────────────────────────
# These are useful for confirming what was created and for
# referencing these values in other tools (scripts, CI pipelines).

output "namespace" {
  description = "The namespace created for the airline app"
  value       = module.namespace.namespace_name
}

output "service_account" {
  description = "The ServiceAccount the app pod will run as"
  value       = module.namespace.service_account_name
}

output "db_secret_name" {
  description = "Secret containing database credentials"
  value       = module.app_stack.db_secret_name
}

output "postgres_pvc_name" {
  description = "PVC for PostgreSQL data"
  value       = module.app_stack.postgres_pvc_name
}
