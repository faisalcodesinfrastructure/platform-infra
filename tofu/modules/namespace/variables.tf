# =============================================================================
# Module: namespace — variables.tf
# Location: platform-infra/tofu/modules/namespace/variables.tf
#
# Defines the inputs this module accepts.
# Every variable has a type, description, and optional default.
# Variables without defaults are required — the caller must provide them.
# =============================================================================

# The name of the namespace to create.
# This becomes the Kubernetes namespace name and is used to name
# all other resources (ServiceAccount, Role, RoleBinding) for consistency.
variable "namespace" {
  type        = string
  description = "Name of the Kubernetes namespace to create"

  # Validation block — OpenTofu checks this before creating anything.
  # Kubernetes namespace names must be lowercase alphanumeric with hyphens.
  validation {
    condition     = can(regex("^[a-z0-9-]+$", var.namespace))
    error_message = "Namespace must be lowercase alphanumeric with hyphens only."
  }
}

# Labels applied to all resources created by this module.
# Labels are key-value pairs used for filtering and organisation.
# map(string) means a map where both keys and values are strings.
variable "labels" {
  type        = map(string)
  description = "Labels to apply to all resources in this namespace"

  # default means this variable is optional — the caller can omit it
  default = {}
}

# The name of the ServiceAccount to create inside the namespace.
# The app pod will run as this ServiceAccount, giving it only
# the permissions defined in the Role below — nothing more.
variable "service_account_name" {
  type        = string
  description = "Name of the ServiceAccount to create in the namespace"
  default     = "app"
}
