# =============================================================================
# Environment: local — variables.tf
# Location: platform-infra/tofu/envs/local/variables.tf
#
# Variables for the local (Kind cluster) environment.
# Values are set in terraform.tfvars which is gitignored.
# =============================================================================

variable "app_name" {
  type        = string
  description = "Name of the application"
  default     = "golden-app"
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

variable "db_name" {
  type        = string
  description = "PostgreSQL database name"
  default     = "airlinedb"
}
