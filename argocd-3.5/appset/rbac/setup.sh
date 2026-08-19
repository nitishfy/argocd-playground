#!/usr/bin/env bash
# Sets up the 'viewer' account for the Preview permission-denied beat.
set -euo pipefail
cd "$(dirname "$0")"

kubectl patch cm argocd-cm -n argocd --patch-file argocd-cm-patch.yaml
kubectl patch cm argocd-rbac-cm -n argocd --patch-file argocd-rbac-cm-patch.yaml
kubectl rollout restart deploy/argocd-server -n argocd
kubectl rollout status deploy/argocd-server -n argocd

echo
echo "Now set a password for the viewer account:"
echo "  argocd account update-password --account viewer --new-password <password>"
echo
echo "Then log in as 'viewer' in a second browser profile."
