#!/bin/bash
##############################################################################
# update-values.sh — patch kustomize overlay values for GitOps and ESO
#
# This script ONLY patches overlay kustomization.yaml files.
# It does NOT deploy anything. Deploy with:  ansible-playbook deploy.yaml
#
# HOW TO USE
#   1. Edit the VARIABLES sections below.
#   2. Set UPDATE_*=true for the projects you want to refresh.
#   3. Run from the repo root:
#        ./update-values.sh
#
# Backups of each touched kustomization.yaml are written next to the file
# (suffix .YYYYMMDD-HHMM) and are gitignored.
##############################################################################
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "${REPO_ROOT}"

###############################################################################
# TOGGLE — which projects to update (true / false)
# These UPDATE_* flags only control this script — not deploy.yaml.
# Deploy toggles are: -e deploy_gitops / deploy_external_secrets
###############################################################################
UPDATE_GITOPS=true
UPDATE_EXTERNAL_SECRETS=true

###############################################################################
# GITOPS — operator overlay (connected)
# Path: gitops/operator/overlays/connected/
###############################################################################
GITOPS_SUBSCRIPTION_CHANNEL="latest"            # connected GitOps channel
GITOPS_CATALOG_SOURCE="redhat-operators"        # connected CatalogSource

###############################################################################
# EXTERNAL SECRETS — operator / instance / argocd overlays
# Paths:
#   external-secrets-operator/operator/overlays/stable/
#   external-secrets-operator/instance/overlays/default/
#   external-secrets-operator/argocd/
###############################################################################
# Operator Subscription
ESO_SUBSCRIPTION_CHANNEL="stable"               # community-operators channel
ESO_CATALOG_SOURCE="redhat-operators"        # CatalogSource name

# OperatorConfig (instance)
ESO_PROMETHEUS_ENABLED="true"                   # true | false
ESO_PROMETHEUS_PORT="8080"
ESO_REQUESTS_CPU="10m"
ESO_REQUESTS_MEMORY="96Mi"
ESO_LIMITS_CPU="100m"
ESO_LIMITS_MEMORY="256Mi"

# Argo CD Application / AppProject source
ESO_GIT_REPO_HTTPS="https://github.com/ebeaudoi/ocp-external-secret.git"
ESO_GIT_REPO_SSH="git@github.com:ebeaudoi/ocp-external-secret.git"
ESO_GIT_TARGET_REVISION="main"

###############################################################################
# Helpers (do not edit)
###############################################################################
BACKUP_SUFFIX="$(date +%Y%m%d-%H%M)"

replace_json6902_value() {
  local file="$1"
  local path="$2"
  local value="$3"
  python3 - "$file" "$path" "$value" <<'PY'
import pathlib, sys

path = pathlib.Path(sys.argv[1])
json_path = sys.argv[2]
value = sys.argv[3]
lines = path.read_text().splitlines()
updated = False
i = 0
while i < len(lines):
    if lines[i].strip() == f"path: {json_path}":
        j = i + 1
        while j < len(lines) and lines[j].strip() == "":
            j += 1
        if j < len(lines) and lines[j].lstrip().startswith("value:"):
            indent = lines[j][: len(lines[j]) - len(lines[j].lstrip())]
            lines[j] = f"{indent}value: {value}"
            updated = True
            i = j
    i += 1
if not updated:
    raise SystemExit(f"Failed to update path {json_path} in {path}")
path.write_text("\n".join(lines) + "\n")
PY
}

update_gitops() {
  local op="gitops/operator/overlays/connected/kustomization.yaml"

  echo ""
  echo "------------------------------------------"
  echo "[GitOps] Updating operator overlay..."
  echo "  Channel: ${GITOPS_SUBSCRIPTION_CHANNEL}"
  echo "  Catalog: ${GITOPS_CATALOG_SOURCE}"
  echo "------------------------------------------"

  cp "${op}"{,."${BACKUP_SUFFIX}"}
  replace_json6902_value "${op}" "/spec/channel" "${GITOPS_SUBSCRIPTION_CHANNEL}"
  replace_json6902_value "${op}" "/spec/source" "${GITOPS_CATALOG_SOURCE}"
  echo "    Done."
}

update_external_secrets() {
  local op="external-secrets-operator/operator/overlays/stable/kustomization.yaml"
  local inst="external-secrets-operator/instance/overlays/default/kustomization.yaml"
  local argocd="external-secrets-operator/argocd/kustomization.yaml"

  echo ""
  echo "------------------------------------------"
  echo "[External Secrets] Updating overlays..."
  echo "  Channel:          ${ESO_SUBSCRIPTION_CHANNEL}"
  echo "  Catalog:          ${ESO_CATALOG_SOURCE}"
  echo "  Prometheus:       ${ESO_PROMETHEUS_ENABLED} (port ${ESO_PROMETHEUS_PORT})"
  echo "  Requests:         cpu=${ESO_REQUESTS_CPU} memory=${ESO_REQUESTS_MEMORY}"
  echo "  Limits:           cpu=${ESO_LIMITS_CPU} memory=${ESO_LIMITS_MEMORY}"
  echo "  Git HTTPS:        ${ESO_GIT_REPO_HTTPS}"
  echo "  Git SSH:          ${ESO_GIT_REPO_SSH}"
  echo "  Target revision:  ${ESO_GIT_TARGET_REVISION}"
  echo "------------------------------------------"

  cp "${op}"{,."${BACKUP_SUFFIX}"}
  cp "${inst}"{,."${BACKUP_SUFFIX}"}
  cp "${argocd}"{,."${BACKUP_SUFFIX}"}

  # Operator Subscription
  replace_json6902_value "${op}" "/spec/channel" "${ESO_SUBSCRIPTION_CHANNEL}"
  replace_json6902_value "${op}" "/spec/source" "${ESO_CATALOG_SOURCE}"

  # OperatorConfig instance
  replace_json6902_value "${inst}" "/spec/prometheus/enabled" "${ESO_PROMETHEUS_ENABLED}"
  replace_json6902_value "${inst}" "/spec/prometheus/service/port" "${ESO_PROMETHEUS_PORT}"
  replace_json6902_value "${inst}" "/spec/resources/requests/cpu" "${ESO_REQUESTS_CPU}"
  replace_json6902_value "${inst}" "/spec/resources/requests/memory" "${ESO_REQUESTS_MEMORY}"
  replace_json6902_value "${inst}" "/spec/resources/limits/cpu" "${ESO_LIMITS_CPU}"
  replace_json6902_value "${inst}" "/spec/resources/limits/memory" "${ESO_LIMITS_MEMORY}"

  # Argo CD Application + AppProject
  replace_json6902_value "${argocd}" "/spec/source/repoURL" "${ESO_GIT_REPO_HTTPS}"
  replace_json6902_value "${argocd}" "/spec/source/targetRevision" "${ESO_GIT_TARGET_REVISION}"
  replace_json6902_value "${argocd}" "/spec/sourceRepos/0" "${ESO_GIT_REPO_HTTPS}"
  replace_json6902_value "${argocd}" "/spec/sourceRepos/1" "${ESO_GIT_REPO_SSH}"

  echo "    Done."
}

###############################################################################
# Run
###############################################################################
echo "=========================================="
echo "update-values.sh  (patches overlays only — does not deploy)"
echo "  UPDATE_GITOPS            = ${UPDATE_GITOPS}"
echo "  UPDATE_EXTERNAL_SECRETS  = ${UPDATE_EXTERNAL_SECRETS}"
echo "  Backup suffix            = .${BACKUP_SUFFIX}"
echo "=========================================="

if [[ "${UPDATE_GITOPS}" == "true" ]]; then
  update_gitops
fi

if [[ "${UPDATE_EXTERNAL_SECRETS}" == "true" ]]; then
  update_external_secrets
fi

echo ""
echo "=========================================="
echo "Update completed."
echo "Deploy with:  ansible-playbook deploy.yaml"
echo "=========================================="
