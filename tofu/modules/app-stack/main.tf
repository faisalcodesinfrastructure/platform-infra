# =============================================================================
# Module: app-stack — main.tf
# Location: platform-infra/tofu/modules/app-stack/main.tf
#
# Creates:
#   1. A Kubernetes Secret containing database credentials
#   2. A PersistentVolumeClaim for PostgreSQL data storage
#
# These two resources are what the airline app and PostgreSQL need
# before they can be deployed.
# =============================================================================

terraform {
  required_providers {
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.27"
    }
  }
}

# ─────────────────────────────────────────────────────────────────────────────
# 1. Database credentials Secret
# ─────────────────────────────────────────────────────────────────────────────
# A Kubernetes Secret stores sensitive data like passwords, tokens, and keys.
# Pods consume Secrets as environment variables or mounted files.
#
# The airline app reads database credentials from environment variables
# that reference this Secret — the password never appears in the Deployment
# manifest itself, only as a reference to the Secret name and key.
#
# type = "Opaque" means a generic secret (as opposed to kubernetes.io/tls
# for TLS certificates or kubernetes.io/dockerconfigjson for registry auth).
resource "kubernetes_secret" "db_credentials" {
  metadata {
    # We name it <app>-db-credentials for clarity
    name      = "${var.app_name}-db-credentials"
    namespace = var.namespace

    labels = merge(var.labels, {
      "managed-by" = "opentofu"
      "app"        = var.app_name
      "component"  = "database"
    })
  }

  type = "Opaque"

  # data contains the secret key-value pairs.
  # OpenTofu base64-encodes these values automatically before
  # storing them in Kubernetes (Kubernetes Secrets store base64 data).
  # The app decodes them automatically when reading env vars.
  data = {
    # DATABASE_URL is the full PostgreSQL connection string.
    # The Go app reads this single env var to connect to the database.
    # Format: postgres://username:password@host:port/dbname?sslmode=disable
    "DATABASE_URL" = "postgres://${var.db_username}:${var.db_password}@${var.app_name}-${var.app_name}-postgresql:5432/${var.db_name}?sslmode=disable"
    # "DATABASE_URL" = "postgres://${var.db_username}:${var.db_password}@${var.app_name}-postgresql:5432/${var.db_name}?sslmode=disable"

    # Individual fields — useful for apps that construct the connection
    # string themselves or need separate credentials
    "DB_NAME"     = var.db_name
    "DB_USERNAME" = var.db_username
    "DB_PASSWORD" = var.db_password
    "DB_HOST"     = "${var.app_name}-postgresql"
    "DB_PORT"     = "5432"
  }
}

# ─────────────────────────────────────────────────────────────────────────────
# 2. PersistentVolumeClaim for PostgreSQL
# ─────────────────────────────────────────────────────────────────────────────
# A PersistentVolumeClaim (PVC) requests storage from the cluster.
# The cluster provisions a PersistentVolume (PV) to satisfy the claim.
#
# Why PostgreSQL needs a PVC:
# Containers are ephemeral — when a pod restarts, its filesystem is wiped.
# PostgreSQL data must survive pod restarts. A PVC mounts a persistent
# volume into the pod so data persists across restarts and rescheduling.
#
# Without a PVC, every PostgreSQL pod restart would lose all data.
resource "kubernetes_persistent_volume_claim" "postgres_data" {
  metadata {
    name      = "${var.app_name}-postgres-data"
    namespace = var.namespace

    labels = merge(var.labels, {
      "managed-by" = "opentofu"
      "app"        = var.app_name
      "component"  = "database"
    })
  }

  spec {
    # access_modes defines how the volume can be mounted:
    #   ReadWriteOnce — mounted by one node at a time (correct for databases)
    #   ReadOnlyMany  — mounted read-only by many nodes (for shared config)
    #   ReadWriteMany — mounted read-write by many nodes (for shared storage)
    # PostgreSQL only ever runs on one node so ReadWriteOnce is correct.
    access_modes = ["ReadWriteOnce"]

    resources {
      requests = {
        # storage is how much disk space to request
        storage = var.storage_size
      }
    }

    # storage_class_name determines HOW the storage is provisioned.
    # Kind uses 'standard' which provisions a directory on the host node.
    # EKS would use 'gp3' for EBS volumes, GKE would use 'standard-rwo'.
    storage_class_name = var.storage_class
  }

  # wait_until_bound = false means OpenTofu does not wait for the PVC
  # to be bound to a PV before continuing. Kind provisions PVCs lazily
  # (only when a pod actually mounts them) so waiting would hang.
  wait_until_bound = false
}
