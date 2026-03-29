# Phase 1 — OpenTofu IaC Modules

> **Location:** `platform-infra/tofu/`
> **Prerequisite:** Phase 0 complete — Kind cluster running with Flux bootstrapped

---

## What this phase provisions

Before the airline app can be deployed, the cluster needs a place to
put it and the infrastructure to support it. This phase creates:

| Resource | Type | Purpose |
|----------|------|---------|
| `golden-app` | Namespace | Isolation boundary for the app |
| `app` | ServiceAccount | Identity the app pod runs as |
| `app-role` | Role | Minimal RBAC permissions |
| `app-rolebinding` | RoleBinding | Connects ServiceAccount to Role |
| `golden-app-db-credentials` | Secret | Database connection credentials |
| `golden-app-postgres-data` | PVC | Persistent storage for PostgreSQL |

---

## Structure

```
tofu/
├── modules/
│   ├── namespace/          Reusable — namespace + RBAC for one app
│   │   ├── main.tf         Creates namespace, ServiceAccount, Role, RoleBinding
│   │   ├── variables.tf    Input variables
│   │   └── outputs.tf      Exposed values (namespace name, SA name)
│   └── app-stack/          Reusable — Secret + PVC for one app
│       ├── main.tf         Creates db Secret and postgres PVC
│       ├── variables.tf    Input variables (db credentials, storage size)
│       └── outputs.tf      Exposed values (secret name, pvc name)
└── envs/
    └── local/              Local Kind cluster environment
        ├── main.tf         Wires modules together, provider config
        ├── variables.tf    Variable declarations
        └── terraform.tfvars  Variable values (gitignored — contains credentials)
```

---

## Key concepts

**Provider** — OpenTofu plugin that knows how to talk to Kubernetes.
Configured in `envs/local/main.tf` with your kubeconfig path and context.

**Module** — reusable block of infrastructure. Call once per app.
Adding a second app means adding one more `module "namespace"` block.

**Variable** — input to a module. Defined in `variables.tf`,
set in `terraform.tfvars`.

**Output** — value a module exposes. Used to wire modules together
without hardcoding names.

**State** — OpenTofu tracks what it created in `terraform.tfstate`.
This file is gitignored. Never delete it while resources are running.

---

## Step 1 — verify your cluster context

```bash
kubectl config current-context
```

Expected: `kind-platform-local`

If it shows something else:
```bash
kubectl config use-context kind-platform-local
```

---

## Step 2 — navigate to the local environment

All OpenTofu commands run from the environment directory:

```bash
cd /Users/faisal.afzal/lab/pe-workshop/platform-eng/platform-infra/tofu/envs/local
```

---

## Step 3 — initialise OpenTofu

`tofu init` downloads the kubernetes provider and sets up the
working directory. Run this once, or any time you add a new provider.

```bash
tofu init
```

Expected output:
```
Initializing the backend...
Initializing provider plugins...
- Finding hashicorp/kubernetes versions matching "~> 2.27"...
- Installing hashicorp/kubernetes v2.27.x...
OpenTofu has been successfully initialized!
```

---

## Step 4 — review the plan

`tofu plan` shows exactly what OpenTofu will create, update, or destroy.
Nothing touches the cluster yet — this is read-only.

Always read the plan before applying.

```bash
tofu plan
```

You should see `Plan: 6 to add, 0 to change, 0 to destroy.`

The 6 resources are:
- 1 Namespace
- 1 ServiceAccount
- 1 Role
- 1 RoleBinding
- 1 Secret
- 1 PersistentVolumeClaim

---

## Step 5 — apply

`tofu apply` creates the resources. It shows the plan again and
asks for confirmation before making any changes.

```bash
tofu apply
```

Type `yes` when prompted.

Expected output:
```
Apply complete! Resources: 6 added, 0 changed, 0 destroyed.

Outputs:
  namespace        = "golden-app"
  service_account  = "app"
  db_secret_name   = "golden-app-db-credentials"
  postgres_pvc_name = "golden-app-postgres-data"
```

---

## Step 6 — verify with kubectl

Confirm the namespace was created:
```bash
kubectl get namespace golden-app
```

Confirm RBAC resources:
```bash
kubectl get serviceaccount,role,rolebinding -n golden-app
```

Confirm the Secret exists (values are hidden):
```bash
kubectl get secret golden-app-db-credentials -n golden-app
```

Confirm the PVC was created:
```bash
kubectl get pvc -n golden-app
```

---

## Step 7 — commit platform-infra

The `.tf` files (not `terraform.tfvars` or state) get committed:

```bash
cd /Users/faisal.afzal/lab/pe-workshop/platform-eng/platform-infra
git add tofu/
git commit -m "phase 1: opentofu modules — namespace, rbac, secret, pvc"
git push origin main
```

---

## Troubleshooting

**`Error: context "kind-platform-local" does not exist`**
Your cluster is not running. Recreate it:
```bash
kind create cluster \
  --name platform-local \
  --config cluster/kind-config.yaml \
  --wait 120s
```

**`Error: namespace already exists`**
Run `tofu state list` to see what OpenTofu already tracks.
If the namespace was created outside OpenTofu, import it:
```bash
tofu import module.namespace.kubernetes_namespace.this golden-app
```

**`tofu destroy`** — removes everything OpenTofu created:
```bash
tofu destroy
```
Use this to clean up before Phase 0 reset.

---

## What is next

**Continue to: `golden-app/README.md`** — Phase 2: Go airline app
