#!/usr/bin/env bash
for c in get list logs manifests terminate-op sync history rollback set unset delete patch edit wait; do
  if argocd app "$c" --help 2>/dev/null | grep -q -- '--app-namespace'; then r="yes"; else r="NO"; fi
  case "$c" in logs|manifests|terminate-op) tag="  <-- NEW in 3.5";; *) tag="";; esac
  printf "  %-14s %-4s%s\n" "$c" "$r" "$tag"
done