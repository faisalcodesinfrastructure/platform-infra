# =============================================================================
# Module: app-stack — outputs.tf
# Location: platform-infra/tofu/modules/app-stack/outputs.tf
# =============================================================================

# The name of the Secret containing database credentials.
# The Helm chart references this by name so the Deployment can
# inject the credentials as environment variables.
output "db_secret_name" {
  description = "Name of the Secret containing database credentials"
  value       = kubernetes_secret.db_credentials.metadata[0].name
}

# The name of the PVC for PostgreSQL data.
# The PostgreSQL StatefulSet mounts this PVC for its data directory.
output "postgres_pvc_name" {
  description = "Name of the PersistentVolumeClaim for PostgreSQL data"
  value       = kubernetes_persistent_volume_claim.postgres_data.metadata[0].name
}
