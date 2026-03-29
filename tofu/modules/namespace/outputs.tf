# =============================================================================
# Module: namespace — outputs.tf
# Location: platform-infra/tofu/modules/namespace/outputs.tf
#
# Outputs are values this module exposes to its caller.
# The environment (envs/local/main.tf) uses these outputs to wire
# modules together without hardcoding names.
#
# Example usage in the caller:
#   module.namespace.namespace_name
#   module.namespace.service_account_name
# =============================================================================

# The name of the namespace that was created.
# Other modules use this to place their resources in the same namespace.
output "namespace_name" {
  description = "The name of the created namespace"
  value       = kubernetes_namespace.this.metadata[0].name
}

# The name of the ServiceAccount.
# The Helm chart uses this so the app pod runs with the right identity.
output "service_account_name" {
  description = "The name of the created ServiceAccount"
  value       = kubernetes_service_account.app.metadata[0].name
}

# The name of the Role that was created.
output "role_name" {
  description = "The name of the created Role"
  value       = kubernetes_role.app.metadata[0].name
}
