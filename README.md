# ocp-external-secret

Deploy **OpenShift GitOps**, then use Argo CD to install the **External Secrets Operator**.

## Quick start

```bash
# 1. Configure GitOps channel / catalog (optional)
vim update-values.sh
./update-values.sh

# 2. Optional: add Argo CD admin users
vim gitops/instance/overlays/connected/gitops-admins-group.yaml

# 3. Login and kubeconfig
oc login --server=<api-url> --token=<token>
oc config view --raw > "$HOME/ocpkubeconfig"

# 4. Install Ansible collection
ansible-galaxy collection install kubernetes.core

# 5. Deploy
ansible-playbook deploy.yaml
```

| Flag | Effect |
|------|--------|
| `-e deploy_gitops=false` | Skip OpenShift GitOps |
| `-e deploy_external_secrets=false` | Skip ESO AppProject / Application |
| `--tags gitops` | Only GitOps |
| `--tags external-secrets` | Only ESO Argo CD resources |

## What gets installed

| Stage | Where |
|-------|--------|
| GitOps operator | `openshift-gitops-operator` |
| Argo CD instance | `openshift-gitops` |
| ESO AppProject + Application | `openshift-gitops` → syncs External Secrets |

## Layout

```
.
├── update-values.sh              # patch GitOps channel / catalog
├── deploy.yaml                   # Ansible playbook
├── gitops/                       # OpenShift GitOps kustomize
└── external-secrets-operator/    # ESO manifests + Argo CD app
```

| Path | Guide |
|------|--------|
| [`gitops/`](gitops/) | [gitops/README.md](gitops/README.md) |
| [`external-secrets-operator/`](external-secrets-operator/) | [external-secrets-operator/README.md](external-secrets-operator/README.md) |

## Verify

```bash
oc get csv -n openshift-gitops-operator
oc get argocd,route -n openshift-gitops
oc get appproject,application -n openshift-gitops
oc get application external-secrets -n openshift-gitops
```

Push this repo to `main` before Argo CD can sync External Secrets.
