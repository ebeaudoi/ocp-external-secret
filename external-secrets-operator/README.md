# External Secrets Operator

GitOps-ready install of the **External Secrets Operator for Red Hat OpenShift**, plus a default `ExternalSecretsConfig` instance.

This deploys:

1. Namespace + OperatorGroup + OLM **Subscription** into `external-secrets-operator`
2. Operand namespace `external-secrets` + **ExternalSecretsConfig** (`cluster`)

After this is running, you can create `SecretStore` / `ClusterSecretStore` and `ExternalSecret` resources for your apps.

---

## Folder layout

```
external-secrets-operator/
├── operator/                 # Namespace, OperatorGroup, Subscription
│   ├── base/
│   └── overlays/stable/      # channel: stable-v1, catalog: redhat-operators
├── instance/                 # Operand namespace + ExternalSecretsConfig
│   ├── base/
│   └── overlays/default/
├── overlays/full/            # Operator + instance together
├── argocd/                   # AppProject + Application
└── README.md
```

---

## Prerequisites

- OpenShift cluster with **OLM** and the **redhat-operators** catalog
- Cluster-admin (or equivalent) access
- For GitOps: **OpenShift GitOps** (Argo CD) installed — namespace `openshift-gitops`

---

## What gets deployed

| Piece | Kind | Namespace | Purpose |
| --- | --- | --- | --- |
| Operator NS | `Namespace` + `OperatorGroup` | `external-secrets-operator` | Home for the Red Hat operator |
| Operator | `Subscription` | `external-secrets-operator` | Package `openshift-external-secrets-operator`, channel `stable-v1` |
| Operand NS | `Namespace` | `external-secrets` | Controllers / webhooks |
| Instance | `ExternalSecretsConfig` (`cluster`) | `external-secrets-operator` | Deploys the external-secrets operand |

Sync order (Argo CD waves):

1. Wave `0` — Operator Namespace / OperatorGroup / Subscription  
2. Wave `1` — Operand Namespace  
3. Wave `2` — ExternalSecretsConfig (waits for the CRD from the operator)

---

## Deploy with Argo CD (recommended)

### 0. Install OpenShift GitOps (if needed)

From the repo root:

```bash
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
ansible-playbook deploy.yaml -e deploy_gitops=false --tags external-secrets

# or manually
oc apply -k external-secrets-operator/argocd
```

That creates:

- **AppProject** `external-secrets`
- **Application** `external-secrets` — syncs `overlays/full` with auto-sync, prune, and self-heal

### 3. Watch the sync

```bash
oc get application external-secrets -n openshift-gitops
oc get csv -n external-secrets-operator
oc get externalsecretsconfig -n external-secrets-operator
oc get pods -n external-secrets
```

Wait until the Application is `Synced` / `Healthy`, the CSV is `Succeeded`, and pods in `external-secrets` are running.

---

## Deploy without Argo CD (manual)

```bash
oc apply -k external-secrets-operator/operator/overlays/stable
oc get csv -n external-secrets-operator

oc apply -k external-secrets-operator/instance/overlays/default

# Or both at once (ExternalSecretsConfig may fail once until the CRD exists — re-apply)
oc apply -k external-secrets-operator/overlays/full
```

---

## Verify

```bash
oc get subscription,csv -n external-secrets-operator
oc get externalsecretsconfig cluster -n external-secrets-operator
oc get pods -n external-secrets
oc get crd | grep external-secrets
```

---

## Next steps (after install)

1. Create a `SecretStore` or `ClusterSecretStore` for your backend (Vault, AWS, Azure, etc.).
2. Create `ExternalSecret` objects in app namespaces to sync secrets into Kubernetes `Secret`s.

Those app-level resources are **not** part of this repo yet — add them per environment or application.

---

## Customize

Edit variables in [`../update-values.sh`](../update-values.sh), set `UPDATE_EXTERNAL_SECRETS=true`, then run `./update-values.sh`.

| Variable | What it patches |
| --- | --- |
| `ESO_SUBSCRIPTION_CHANNEL` | Must be `stable-v1` for the Red Hat operator |
| `ESO_CATALOG_SOURCE` | Usually `redhat-operators` |
| `ESO_GIT_REPO_HTTPS` / `ESO_GIT_REPO_SSH` | Argo CD Application + AppProject repos |
| `ESO_GIT_TARGET_REVISION` | Argo CD Application branch / tag |

| Change (manual) | Where |
| --- | --- |
| Operand / network policy | `instance/base/externalsecretsconfig.yaml` |

---

## Notes

- Uses the **Red Hat** operator (`openshift-external-secrets-operator` from `redhat-operators`).
- Channel is **`stable-v1`** — there is no `stable` channel for this package (that causes the OLM “constraints not satisfiable” error).
- If a broken Subscription was already created in `openshift-operators`, delete it before re-syncing:

```bash
oc delete subscription external-secrets-operator -n openshift-operators --ignore-not-found
oc delete csv -n openshift-operators -l operators.coreos.com/openshift-external-secrets-operator.openshift-operators --ignore-not-found
```
