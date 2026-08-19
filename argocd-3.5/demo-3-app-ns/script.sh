#!/usr/bin/env bash
# Enables Applications-in-any-namespace so there's a non-argocd app to target.
set -euo pipefail
 
echo "==> allow apps in team-* namespaces"
kubectl patch cm argocd-cmd-params-cm -n argocd --type merge \
  -p '{"data":{"application.namespaces":"team-*"}}'
 
echo "==> let the default project accept apps from those namespaces"
kubectl patch appproject default -n argocd --type merge \
  -p '{"spec":{"sourceNamespaces":["team-*"]}}'
 
kubectl rollout restart deploy/argocd-server statefulset/argocd-application-controller -n argocd
kubectl rollout status deploy/argocd-server -n argocd
 
kubectl create namespace team-a --dry-run=client -o yaml | kubectl apply -f -
echo "Ready."
 