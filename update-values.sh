#!/bin/bash
##############################################################################
# update-values.sh — patch kustomize overlay values for GitOps
#
# This script ONLY patches overlay kustomization.yaml files.
# It does NOT deploy anything. Deploy with:  ansible-playbook deploy.yaml
#
# HOW TO USE
#   1. Edit the VARIABLES section below.
#   2. Set UPDATE_GITOPS=true if you want to refresh the overlay.
#   3. Run from the repo root:
#        ./update-values.sh
#
# Backups of each touched kustomization.yaml are written next to the file
# (suffix .YYYYMMDD-HHMM) and are gitignored under gitops/.
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

###############################################################################
# GITOPS — operator overlay (connected)
# Path: gitops/operator/overlays/connected/
###############################################################################
GITOPS_SUBSCRIPTION_CHANNEL="latest"            # connected GitOps channel
GITOPS_CATALOG_SOURCE="redhat-operators"        # connected CatalogSource

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

###############################################################################
# Run
###############################################################################
echo "=========================================="
echo "update-values.sh  (patches overlays only — does not deploy)"
echo "  UPDATE_GITOPS  = ${UPDATE_GITOPS}"
echo "  Backup suffix  = .${BACKUP_SUFFIX}"
echo "=========================================="

if [[ "${UPDATE_GITOPS}" == "true" ]]; then
  update_gitops
fi

echo ""
echo "=========================================="
echo "Update completed."
echo "Deploy with:  ansible-playbook deploy.yaml"
echo "=========================================="
