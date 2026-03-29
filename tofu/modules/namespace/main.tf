# =============================================================================
# Module: namespace — main.tf
# Location: platform-infra/tofu/modules/namespace/main.tf
#
# Creates:
#   1. A Kubernetes namespace
#   2. A ServiceAccount for the app pod to run as
#   3. A Role granting minimal permissions within the namespace
#   4. A RoleBinding connecting the ServiceAccount to the Role
#
# This follows the principle of least privilege — the app gets exactly
# the permissions it needs and nothing more.
# =============================================================================

# terraform block declares required providers.
# OpenTofu downloads the kubernetes provider when you run 'tofu init'.
# The kubernetes provider knows how to create K8s resources via the API.
terraform {
  required_providers {
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.27"
    }
  }
}

# ─────────────────────────────────────────────────────────────────────────────
# 1. Namespace
# ─────────────────────────────────────────────────────────────────────────────
# kubernetes_namespace creates a Kubernetes namespace.
# Every resource in Kubernetes lives in a namespace — it is the
# primary isolation boundary between different apps or teams.
resource "kubernetes_namespace" "this" {
  metadata {
    # var.namespace references the input variable defined in variables.tf
    name = var.namespace

    # merge() combines two maps into one.
    # We merge the caller-provided labels with our standard labels
    # so every resource is consistently tagged.
    labels = merge(var.labels, {
      "managed-by" = "opentofu"
      "phase"      = "platform-eng-workshop"
    })
  }
}

# ─────────────────────────────────────────────────────────────────────────────
# 2. ServiceAccount
# ─────────────────────────────────────────────────────────────────────────────
# A ServiceAccount is a Kubernetes identity for a pod.
# Without a ServiceAccount, pods run as the 'default' account which
# often has too many permissions (or none at all, depending on the cluster).
# We create a dedicated one so permissions are explicit and auditable.
resource "kubernetes_service_account" "app" {
  metadata {
    name      = var.service_account_name
    namespace = kubernetes_namespace.this.metadata[0].name

    labels = merge(var.labels, {
      "managed-by" = "opentofu"
    })
  }

  # depends_on tells OpenTofu to create the namespace before the
  # ServiceAccount. OpenTofu usually infers this from references
  # but explicit dependencies make the intent clear.
  depends_on = [kubernetes_namespace.this]
}

# ─────────────────────────────────────────────────────────────────────────────
# 3. Role
# ─────────────────────────────────────────────────────────────────────────────
# A Role defines what actions are allowed on which resources,
# within a specific namespace. This is Kubernetes RBAC.
#
# We grant the minimum permissions the airline app needs:
#   - Read its own ConfigMaps (for app configuration)
#   - Read Secrets (for database credentials)
#   - Read and update its own Pods (for health checks)
resource "kubernetes_role" "app" {
  metadata {
    name      = "${var.service_account_name}-role"
    namespace = kubernetes_namespace.this.metadata[0].name

    labels = merge(var.labels, {
      "managed-by" = "opentofu"
    })
  }

  # Each rule block grants permissions on a set of resources.
  # api_groups: "" means the core API group (pods, services, configmaps, secrets)
  # resources:  which resource types this rule applies to
  # verbs:      what actions are allowed (get, list, watch, create, update, delete)
  rule {
    api_groups = [""]
    resources  = ["configmaps"]
    verbs      = ["get", "list", "watch"]
  }

  rule {
    api_groups = [""]
    resources  = ["secrets"]
    verbs      = ["get", "list", "watch"]
  }

  rule {
    api_groups = [""]
    resources  = ["pods"]
    verbs      = ["get", "list", "watch"]
  }

  depends_on = [kubernetes_namespace.this]
}

# ─────────────────────────────────────────────────────────────────────────────
# 4. RoleBinding
# ─────────────────────────────────────────────────────────────────────────────
# A RoleBinding connects a ServiceAccount (who) to a Role (what they can do).
# Without this binding, the Role exists but nobody is assigned to it.
# The ServiceAccount exists but has no permissions.
# The binding is the glue between them.
resource "kubernetes_role_binding" "app" {
  metadata {
    name      = "${var.service_account_name}-rolebinding"
    namespace = kubernetes_namespace.this.metadata[0].name

    labels = merge(var.labels, {
      "managed-by" = "opentofu"
    })
  }

  # role_ref: which Role to bind to
  role_ref {
    api_group = "rbac.authorization.k8s.io"
    kind      = "Role"
    name      = kubernetes_role.app.metadata[0].name
  }

  # subject: who gets the permissions (our ServiceAccount)
  subject {
    kind      = "ServiceAccount"
    name      = kubernetes_service_account.app.metadata[0].name
    namespace = kubernetes_namespace.this.metadata[0].name
  }

  depends_on = [kubernetes_role.app, kubernetes_service_account.app]
}
