#!/usr/bin/env bash
# Confirms every ApplicationSet is in the state the demo script expects.
set -uo pipefail

echo "=== ApplicationSets: health + generated app count ==="
kubectl get appsets -n argocd \
  -o custom-columns='NAME:.metadata.name,HEALTH:.status.health.status,MESSAGE:.status.health.message' 2>/dev/null

echo
echo "=== Generated Applications ==="
kubectl get applications -n argocd \
  -o custom-columns='NAME:.metadata.name,PROJECT:.spec.project,OWNER:.metadata.ownerReferences[0].name,SYNC:.status.sync.status,HEALTH:.status.health.status' 2>/dev/null

echo
echo "=== Expected before recording ==="
cat <<'TXT'
  envs              Healthy    -> 3 apps (env-dev, env-staging, env-prod)
  services          Healthy    -> 3 apps (svc-api, svc-worker, svc-cache)
  broken-generator  Degraded   -> 0 apps, ErrorOccurred condition
  managed-regions   Healthy    -> 2 apps (region-us-east, region-eu-west)
  parent-of-appset  (Application, OutOfSync after you edit the child appset in Git)
TXT
