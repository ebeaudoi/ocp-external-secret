# External Secrets Operator

GitOps-ready install of the community **External Secrets Operator** on OpenShift, plus a default `OperatorConfig` instance.

This deploys:

1. The OLM **Subscription** (operator) into `openshift-operators`
2. The **OperatorConfig** instance into the `external-secrets` namespace

After this is running, you can create `SecretStore` / `ClusterSecretStore` and `ExternalSecret` resources for your apps.

---

## Folder layout

```
external-secrets-operator/
├── operator/                 # OLM Subscription
│   ├── base/
│   └── overlays/stable/      # channel: stable
├── instance/                 # Namespace + OperatorConfig
│   ├── base/
│   └── overlays/default/
├── overlays/full/            # Operator + instance together
├── argocd/                   # AppProject + Application
└── README.md
```

---

## Prerequisites

- OpenShift cluster with **OLM** and the **community-operators** catalog
- Cluster-admin (or equivalent) access
- For GitOps: **OpenShift GitOps** (Argo CD) installed — namespace `openshift-gitops`

---

## What gets deployed

| Piece | Kind | Namespace | Purpose |
| --- | --- | --- | --- |
| Operator | `Subscription` | `openshift-operators` | Installs ESO from `community-operators` (`stable` channel) |
| Namespace | `Namespace` | `external-secrets` | Home for the ESO instance |
| Instance | `OperatorConfig` (`cluster`) | `external-secrets` | Deploys the external-secrets controllers |

Sync order (Argo CD waves):

1. Wave `0` — Subscription  
2. Wave `1` — Namespace  
3. Wave `2` — OperatorConfig (waits for the CRD from the operator)

---

## Deploy with Argo CD (recommended)

### 0. Install OpenShift GitOps (if needed)

From the repo root, the Ansible playbook installs GitOps and then applies the ESO AppProject + Application:

```bash
cd ..   # repo root
./update-values.sh
ansible-playbook deploy.yaml
```

GitOps only:

```bash
ansible-playbook deploy.yaml -e deploy_external_secrets=false --tags gitops
```

### 1. Push this repo

Make sure `main` on GitHub includes these manifests.

Repo used by the Application:

`https://github.com/ebeaudoi/ocp-external-secret.git`

### 2. Apply the Argo CD project + app

If GitOps is already installed and you only need the ESO Application:

```bash
# from repo root via playbook
ansible-playbook deploy.yaml -e deploy_gitops=false --tags external-secrets

# or manually
oc apply -k external-secrets-operator/argocd
```

That creates:

- **AppProject** `external-secrets` — only this solution can deploy to the needed namespaces
- **Application** `external-secrets` — syncs `overlays/full` with auto-sync, prune, and self-heal

### 3. Watch the sync

```bash
# Argo CD application
oc get application external-secrets -n openshift-gitops

# Operator CSV
oc get csv -n openshift-operators | grep external-secrets

# Instance
oc get operatorconfig -n external-secrets
oc get pods -n external-secrets
```

Wait until the Application is `Synced` / `Healthy`, the CSV is `Succeeded`, and pods in `external-secrets` are running.

---

## Deploy without Argo CD (manual)

Useful for a quick test on a cluster:

```bash
# Operator only
oc apply -k external-secrets-operator/operator/overlays/stable

# Wait until the operator CSV is Succeeded
oc get csv -n openshift-operators | grep external-secrets

# Then the instance
oc apply -k external-secrets-operator/instance/overlays/default

# Or both at once (OperatorConfig may fail once until the CRD exists — re-apply)
oc apply -k external-secrets-operator/overlays/full
```

---

## Verify

```bash
oc get subscription external-secrets-operator -n openshift-operators
oc get operatorconfig cluster -n external-secrets
oc get pods -n external-secrets
oc get crd | grep external-secrets
```

You should see CRDs such as `externalsecrets.external-secrets.io` and `secretstores.external-secrets.io`.

---

## Next steps (after install)

1. Create a `SecretStore` or `ClusterSecretStore` for your backend (Vault, AWS, Azure, etc.).
2. Create `ExternalSecret` objects in app namespaces to sync secrets into Kubernetes `Secret`s.

Those app-level resources are **not** part of this repo yet — add them per environment or application.

---

## Customize

| Change | Where |
| --- | --- |
| Operator channel | `operator/overlays/stable/kustomization.yaml` |
| Operator package / catalog | `operator/base/subscription.yaml` |
| Instance resources / Prometheus | `instance/base/default-operatorconfig.yaml` |
| Git repo URL or branch | `argocd/application.yaml` and `argocd/appproject.yaml` |

---

## Notes

- Uses the **community** operator (`community-operators`), not the Red Hat certified `openshift-external-secrets-operator`.
- `openshift-operators` already has a global OperatorGroup — no extra OperatorGroup is required.
- The first sync of `OperatorConfig` needs the CRD from the operator. The Argo CD Application retries and uses `SkipDryRunOnMissingResource`.
