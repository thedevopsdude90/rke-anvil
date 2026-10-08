# rke-anvil

Monitoring and logging for the RKE2/Rancher lab cluster, deployed by
[Anvil](../anvil-go/anvil). Ported from the Argo CD Applications in
`airgapped-gke/argocd-gke/charts/`.

| App | Chart | Namespace |
| --- | --- | --- |
| prometheus | prometheus-community/prometheus 29.29.0 | prometheus |
| grafana | grafana-community/grafana 13.2.4 | grafana |
| loki | grafana-community/loki 18.13.0 | loki |
| promtail | grafana/promtail 6.17.1 | promtail |

## Layout

- `values/` - Helm values, the part you edit.
- `apps/<name>/` - plain YAML rendered from the chart by `render.sh`, plus
  hand-written extras (`grafana/admin-secret.yaml`, `grafana/gateway.yaml`). Anvil
  doesn't render Helm yet, so this is what it syncs. Don't hand-edit
  `manifests.yaml`; change the values and re-render.
- `applications/` - the Anvil `Application` for each app, pointing at
  `apps/<name>` in this repo.

## Changes from the GKE version

- Images come from upstream registries, not the Artifact Registry mirror.
  Prometheus's config-reloader and Loki's gateway metrics sidecar are back
  on, since the cluster can reach quay.io and ghcr.io.
- Storage uses the default `nfs` StorageClass instead of `standard-rwo`.
  Prometheus, Grafana's SQLite and Loki all warn against NFS. Acceptable
  for this lab, not for anything that matters.
- Loki stores chunks on a 5Gi PVC (`filesystem`) instead of GCS with
  Workload Identity, so it runs as a single Monolithic replica.
- Grafana's admin login comes from Anvil's vault (`grafana/admin`) through
  `apps/grafana/admin-secret.yaml`.
- Dropped: HashiCorp Vault, External Secrets and vault-eso-connector
  (Anvil's vault replaces them), and csi-driver-nfs (the cluster already
  has nfs-subdir-external-provisioner).

## Deploy

1. Unseal Anvil and store the Grafana login (from `anvil-go/anvil/examples`):

   ```bash
   ./add-secret.sh grafana/admin username=admin password=@random
   ```

2. Push this repo to `github.com/thedevopsdude90/rke-anvil`. For a private
   repo, add a GitHub connection in Anvil (namespace `anvil-system`, name
   `github`) and uncomment `credentialsRef` in each Application.

3. Apply the Applications:

   ```bash
   kubectl apply -f applications/
   kubectl -n anvil-system get applications.anvil.dev
   ```

## Updating

Edit `values/<name>.yaml` or a chart version in `render.sh`, then:

```bash
./render.sh            # or: ./render.sh grafana
git add -A && git commit -m "..." && git push
```

Anvil picks up the change within `spec.interval` (3m).

## Access

Grafana: http://192.168.122.202 (Cilium Gateway, `apps/grafana/gateway.yaml`).
Log in with the `grafana/admin` credentials from Anvil's vault.
