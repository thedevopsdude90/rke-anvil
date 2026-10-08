#!/bin/bash
# Renders each upstream Helm chart to plain YAML under apps/<name>/, since
# Anvil syncs plain manifests from Git and doesn't render Helm itself yet.
# Edit values/<name>.yaml (or a version below), re-run this, commit apps/,
# push - Anvil picks up the change on its next poll (spec.interval).
#
#   ./render.sh            # all apps
#   ./render.sh grafana    # one app
set -euo pipefail
cd "$(dirname "$0")"

# name|namespace|repo URL|chart|version
APPS=(
  "prometheus|prometheus|https://prometheus-community.github.io/helm-charts|prometheus|29.29.0"
  "grafana|grafana|https://grafana-community.github.io/helm-charts|grafana|13.2.4"
  "loki|loki|https://grafana-community.github.io/helm-charts|loki|18.13.0"
  # Promtail is deprecated and was never moved to grafana-community.
  "promtail|promtail|https://grafana.github.io/helm-charts|promtail|6.17.1"
)

for entry in "${APPS[@]}"; do
  IFS='|' read -r name ns repo chart version <<<"$entry"
  if [ $# -gt 0 ] && [[ ! " $* " =~ " $name " ]]; then continue; fi
  echo "Rendering $name ($chart $version) -> apps/$name/"
  mkdir -p "apps/$name"
  # --skip-tests: test Pods are Helm hooks; Anvil has no hooks, so they'd
  # just be applied as ordinary Pods and run once.
  helm template "$name" "$chart" \
    --repo "$repo" --version "$version" \
    --namespace "$ns" \
    --values "values/$name.yaml" \
    --include-crds --skip-tests \
    >"apps/$name/manifests.yaml"
  # Fail if any other hook slipped through - it would be applied as a
  # normal object rather than at the hook's intended point.
  if grep -q 'helm.sh/hook' "apps/$name/manifests.yaml"; then
    echo "  $name: rendered output contains Helm hooks; review before committing" >&2
    exit 1
  fi
done
