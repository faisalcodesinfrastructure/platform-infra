# Phase 0 — Cluster Setup

> **Location:** `platform-infra/cluster/`
> **Prerequisite:** Root `README.md` Steps 1–10 complete

Follow every step in order. Each command is explained before you run it.

By the end you will have:
- A 4-node Kind cluster running on your Mac
- Traefik v3 installed as the ingress controller
- Traefik dashboard at `http://localhost:9090/dashboard/`
- Flux bootstrapped and watching `platform-infra` on GitHub

---

## Cluster topology

```
control-plane
  API server · scheduler · etcd
  Port mappings:
    localhost:8080  → cluster :80   (app HTTP via Traefik)
    localhost:8443  → cluster :443  (app HTTPS)
    localhost:9090  → cluster :9090 (Traefik dashboard)

worker — shared-services   label: node-role=shared-services
  TAINT: node-role=shared-services:NoSchedule
  Runs: Traefik v3, Flux controllers

worker — app-1             label: node-role=app  (no taint)
  Runs: airline API pods

worker — app-2             label: node-role=app  (no taint)
  Runs: PostgreSQL StatefulSet + PVC
```

The **taint** on the shared-services node means the Kubernetes scheduler
hard-rejects any pod that does not declare a matching toleration. App pods
never carry this toleration so they are physically blocked from landing
on the shared-services node.

---

## Step 1 — confirm Docker Desktop is running

```bash
docker info
```

Look for `Server Version:` in the output. If you see
`Cannot connect to the Docker daemon` — start Docker Desktop and retry.

---

## Step 2 — review the cluster config

Read the cluster definition before creating anything:

```bash
cat platform-infra/cluster/kind-config.yaml
```

This file defines 4 nodes and the port mappings. Nothing is created yet.

---

## Step 3 — create the Kind cluster

This starts 4 Docker containers that act as Kubernetes nodes.
Takes 2–3 minutes.

```bash
kind create cluster \
  --name platform-local \
  --config platform-infra/cluster/kind-config.yaml \
  --wait 120s
```

`--wait 120s` means the command will not return until all nodes are Ready.

When complete you will see:
```
Set kubectl context to "kind-platform-local"
```

Verify the cluster exists:
```bash
kind get clusters
```

Expected output: `platform-local`

---

## Step 4 — verify kubectl context

```bash
kubectl config current-context
```

Expected output: `kind-platform-local`

If it shows something else:
```bash
kubectl config use-context kind-platform-local
```

---

## Step 5 — verify all 4 nodes are Ready

```bash
kubectl get nodes
```

Expected — all four showing `Ready`:
```
NAME                           STATUS   ROLES           AGE
platform-local-control-plane   Ready    control-plane   2m
platform-local-worker          Ready    <none>          2m
platform-local-worker2         Ready    <none>          2m
platform-local-worker3         Ready    <none>          2m
```

If any node shows `NotReady` — wait 30 seconds and retry.

---

## Step 6 — label the nodes

Labels let workloads declare which node tier they want via `nodeSelector`.

Label the shared-services worker:
```bash
kubectl label node platform-local-worker node-role=shared-services
```

Label app worker 1:
```bash
kubectl label node platform-local-worker2 node-role=app
```

Label app worker 2:
```bash
kubectl label node platform-local-worker3 node-role=app
```

Verify all labels were applied:
```bash
kubectl get nodes --show-labels
```

Confirm `node-role=shared-services` on `platform-local-worker` and
`node-role=app` on `platform-local-worker2` and `platform-local-worker3`.

---

## Step 7 — taint the shared-services node

Labels alone are advisory. The taint is the hard enforcement layer — the
scheduler **rejects** any pod without a matching toleration.

```bash
kubectl taint node platform-local-worker \
  node-role=shared-services:NoSchedule
```

Verify the taint was applied:
```bash
kubectl describe node platform-local-worker | grep -A3 Taints
```

Expected:
```
Taints: node-role=shared-services:NoSchedule
```

Verify the app nodes have no taint:
```bash
kubectl describe node platform-local-worker2 | grep -A3 Taints
kubectl describe node platform-local-worker3 | grep -A3 Taints
```

Expected for both: `Taints: <none>`

---

## Step 8 — add the Traefik Helm repository

Helm needs to know where to find the Traefik chart. This is a one-time step.

```bash
helm repo add traefik https://traefik.github.io/charts
```

Update the local chart cache:
```bash
helm repo update
```

Verify the repo was added:
```bash
helm repo list
```

You should see `traefik` in the list.

---

## Step 9 — create the Traefik namespace

Traefik will run in its own namespace, separate from your app workloads.

```bash
kubectl create namespace traefik
```

Verify:
```bash
kubectl get namespace traefik
```

---

## Step 10 — install Traefik v3

Install Traefik using Helm with these settings:

```bash
helm install traefik traefik/traefik \
  --namespace traefik \
  --version ">=30.0.0" \
  --set "ingressClass.enabled=true" \
  --set "ingressClass.isDefaultClass=true" \
  --set "api.dashboard=true" \
  --set "api.insecure=true" \
  --set "ports.web.port=8000" \
  --set "ports.web.hostPort=80" \
  --set "ports.web.exposedPort=80" \
  --set "ports.websecure.port=4443" \
  --set "ports.websecure.hostPort=443" \
  --set "ports.websecure.exposedPort=443" \
  --set "ports.traefik.port=9090" \
  --set "ports.traefik.hostPort=9090" \
  --set "ports.traefik.expose.default=true" \
  --set "service.type=ClusterIP" \
  --set "deployment.kind=DaemonSet" \
  --set "nodeSelector.node-role=shared-services" \
  --set "tolerations[0].key=node-role" \
  --set "tolerations[0].operator=Equal" \
  --set "tolerations[0].value=shared-services" \
  --set "tolerations[0].effect=NoSchedule"
```

What the key flags do:
- `ingressClass.isDefaultClass=true` — all Ingress resources automatically use Traefik
- `api.dashboard=true` + `api.insecure=true` — dashboard on port 9090, no TLS needed locally
- `ports.web.hostPort=80` — binds to host port 80, mapped to `localhost:8080` by Kind
- `ports.traefik.hostPort=9090` — binds dashboard to `localhost:9090`
- `deployment.kind=DaemonSet` — one Traefik pod per matching node
- `nodeSelector.node-role=shared-services` — pins Traefik to the shared-services node
- `tolerations[0]...` — allows Traefik to schedule on the tainted node
- `service.type=ClusterIP` — correct for Kind (no LoadBalancer needed)

---

## Step 11 — verify Traefik pod is Running

```bash
kubectl get pods -n traefik
```

Expected:
```
NAME                       READY   STATUS    RESTARTS   AGE
traefik-xxxxxxxxxx-xxxxx   1/1     Running   0          1m
```

If the pod is `Pending` — describe it to see why:
```bash
kubectl describe pod -n traefik \
  $(kubectl get pod -n traefik -o name | head -1)
```

Read the `Events:` section at the bottom. It will tell you exactly
why the pod cannot schedule.

---

## Step 12 — verify Traefik is on the shared-services node

```bash
kubectl get pods -n traefik -o wide
```

The `NODE` column must show `platform-local-worker`.

---

## Step 13 — verify the Traefik dashboard

```bash
curl -s -o /dev/null -w "%{http_code}" http://localhost:9090/dashboard/
```

Expected output: `200`

If you get `000` or connection refused — wait 30 seconds and retry.

Open the dashboard in your browser:
```bash
open http://localhost:9090/dashboard/
```

You will see the Traefik UI with no routers yet. Routes appear in
Phase 2 when the airline app is deployed.

---

## Step 14 — verify the IngressClass

```bash
kubectl get ingressclass
```

Expected:
```
NAME      CONTROLLER                      PARAMETERS   AGE
traefik   traefik.io/ingress-controller   <none>       2m
```

Verify it is the default IngressClass:
```bash
kubectl get ingressclass traefik \
  -o jsonpath='{.metadata.annotations.ingressclass\.kubernetes\.io/is-default-class}'
```

Expected output: `true`

---

## Step 15 — run the Flux pre-flight check

Before installing Flux, confirm the cluster meets all requirements:

```bash
flux check --pre
```

All items should show `✔`. If any show `✗` the output explains
what is missing.

---

## Step 16 — bootstrap Flux

This single command does four things:
1. Installs Flux controllers into the `flux-system` namespace
2. Creates a Deploy Key on your `platform-infra` GitHub repo
3. Commits Flux manifests into `platform-infra/flux/clusters/local/`
4. Flux immediately starts watching that path in Git

First get your GitHub username:
```bash
gh api user --jq '.login'
```

Note the output — you will use it in the next command.

Now bootstrap Flux. Replace `YOUR_GITHUB_USERNAME` with your actual username:
```bash
flux bootstrap github \
  --owner=YOUR_GITHUB_USERNAME \
  --repository=platform-infra \
  --branch=main \
  --path=flux/clusters/local \
  --personal \
  --token-auth
```

When prompted for a token:
```bash
gh auth token
```

Copy the token output and paste it into the prompt.

This takes 1–2 minutes. You will see Flux installing components
and confirming reconciliation.

> **Important:** Flux commits files to your `platform-infra` repo.
> This is expected — Flux installs itself via GitOps.

---

## Step 17 — pull Flux bootstrap commits

Flux just committed to your `platform-infra` repo on GitHub.
Pull those commits down to your local copy:

```bash
cd platform-infra
git pull
cd ..
```

Check the new folder that Flux created:
```bash
ls platform-infra/flux/clusters/local/
```

You will see `flux-system/`. This is Flux managing itself.
Do not edit these files manually.

---

## Step 18 — pin Flux controllers to the shared-services node

Flux controllers need a nodeSelector and toleration to run on
the tainted shared-services node. Patch each one individually.

**source-controller** (clones Git repos and Helm chart sources):
```bash
kubectl patch deployment source-controller \
  -n flux-system \
  --type=json \
  --patch='[{"op":"add","path":"/spec/template/spec/nodeSelector","value":{"node-role":"shared-services"}},{"op":"add","path":"/spec/template/spec/tolerations","value":[{"key":"node-role","operator":"Equal","value":"shared-services","effect":"NoSchedule"}]}]'
```

**kustomize-controller** (applies YAML and Kustomize from Git):
```bash
kubectl patch deployment kustomize-controller \
  -n flux-system \
  --type=json \
  --patch='[{"op":"add","path":"/spec/template/spec/nodeSelector","value":{"node-role":"shared-services"}},{"op":"add","path":"/spec/template/spec/tolerations","value":[{"key":"node-role","operator":"Equal","value":"shared-services","effect":"NoSchedule"}]}]'
```

**helm-controller** (deploys Helm charts from HelmRelease resources):
```bash
kubectl patch deployment helm-controller \
  -n flux-system \
  --type=json \
  --patch='[{"op":"add","path":"/spec/template/spec/nodeSelector","value":{"node-role":"shared-services"}},{"op":"add","path":"/spec/template/spec/tolerations","value":[{"key":"node-role","operator":"Equal","value":"shared-services","effect":"NoSchedule"}]}]'
```

**notification-controller** (handles alerts and webhooks):
```bash
kubectl patch deployment notification-controller \
  -n flux-system \
  --type=json \
  --patch='[{"op":"add","path":"/spec/template/spec/nodeSelector","value":{"node-role":"shared-services"}},{"op":"add","path":"/spec/template/spec/tolerations","value":[{"key":"node-role","operator":"Equal","value":"shared-services","effect":"NoSchedule"}]}]'
```

Wait for the controllers to restart:
```bash
kubectl rollout status deployment/source-controller -n flux-system --timeout=120s
```

```bash
kubectl rollout status deployment/kustomize-controller -n flux-system --timeout=120s
```

---

## Step 19 — verify Flux is healthy

All four controller pods should be Running:
```bash
kubectl get pods -n flux-system
```

Expected — all Running:
```
NAME                                       READY   STATUS
helm-controller-xxxxxxxxxx                 1/1     Running
kustomize-controller-xxxxxxxxxx            1/1     Running
notification-controller-xxxxxxxxxx         1/1     Running
source-controller-xxxxxxxxxx               1/1     Running
```

Check the GitRepository is reconciling:
```bash
flux get sources git
```

Expected — READY = True:
```
NAME          REVISION    SUSPENDED  READY  MESSAGE
flux-system   main/...    False      True   stored artifact
```

Check the Kustomization is healthy:
```bash
flux get kustomizations
```

Expected — READY = True:
```
NAME          REVISION    SUSPENDED  READY  MESSAGE
flux-system   main/...    False      True   Applied revision: main/...
```

Run the full health check:
```bash
flux check
```

All items should show `✔`.

---

## Phase 0 checkpoint

Run through all of these before moving to Phase 1:

```bash
# 1. All 4 nodes Ready
kubectl get nodes

# 2. Correct context
kubectl config current-context

# 3. Node labels
kubectl get nodes --show-labels | grep node-role

# 4. Taint on shared-services
kubectl describe node platform-local-worker | grep -A3 Taints

# 5. No taint on app nodes
kubectl describe node platform-local-worker2 | grep -A3 Taints

# 6. Traefik Running on shared-services node
kubectl get pods -n traefik -o wide

# 7. Traefik dashboard responds
curl -s -o /dev/null -w "%{http_code}" http://localhost:9090/dashboard/

# 8. IngressClass is default
kubectl get ingressclass traefik \
  -o jsonpath='{.metadata.annotations.ingressclass\.kubernetes\.io/is-default-class}'

# 9. Flux controllers all Running
kubectl get pods -n flux-system

# 10. Flux GitRepository Ready
flux get sources git

# 11. Flux Kustomization Ready
flux get kustomizations
```

All green → Phase 0 complete.

Open the Traefik dashboard:
```bash
open http://localhost:9090/dashboard/
```

---

## Troubleshooting

**Node stays NotReady:**
```bash
kubectl describe node platform-local-worker
```
Read the `Conditions:` section.

**Traefik pod stays Pending:**
```bash
kubectl describe pod -n traefik \
  $(kubectl get pod -n traefik -o name | head -1)
```
Read the `Events:` section. Most common cause: taint/toleration mismatch.
Delete Traefik and reinstall from Step 8:
```bash
helm uninstall traefik -n traefik
```
Then re-run the install from Step 10.

**Flux pod stays Pending:**
```bash
kubectl describe pod -n flux-system \
  $(kubectl get pod -n flux-system -o name | head -1)
```
Most common cause: nodeSelector/toleration patch from Step 18 not applied.
Re-run the patch for the affected controller.

**Flux GitRepository not Ready:**
```bash
flux logs -n flux-system
```
Most common cause: GitHub token missing `repo` scope.
```bash
gh auth login --scopes repo,read:org
```
Then re-run bootstrap from Step 16.

**Full reset:**
```bash
kind delete cluster --name platform-local
```
Then start again from Step 1. Takes about 3 minutes.

---

## What is next

**Continue to: `platform-infra/tofu/README.md`** — Phase 1: OpenTofu modules
