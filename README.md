# platform-infra

Platform infrastructure for the Platform Engineering Golden Path workshop.

**Owned by the platform team.** Flux watches this repo and applies
everything committed here to the cluster automatically.

---

## Structure

```
platform-infra/
├── cluster/          Phase 0 — Kind cluster, Traefik, Flux bootstrap
├── tofu/             Phase 1 — OpenTofu IaC modules (added in Phase 1)
└── flux/             Auto-created by Flux — do not edit manually
    └── clusters/local/
        ├── flux-system/    Flux self-management
        └── apps/           Phase 3: one HelmRelease per app
```

---

## Phase 0 — start here

Open `cluster/README.md` and follow every step in order.
