---
name: cluster-setup
description: This skill should be used when the user wants to create a CFKE cluster, set up fleets, connect cloud providers (AWS, GCP, Hetzner), add self-managed nodes, or get a new Cloudfleet environment running using the cloudfleet CLI or API. For Terraform/HCL use the terraform skill instead; the schemas differ.
user-invocable: true
argument-hint: "[cluster-name]"
---

# Cluster Setup

Guide users through the full process of getting a Cloudfleet cluster up and running — from creating the cluster through connecting cloud accounts to deploying a first workload. See [references/cluster-setup.md](references/cluster-setup.md) for detailed CLI commands and all provider examples.

**This skill covers the `cloudfleet` CLI and API JSON only.** If the user is writing Terraform or does not want the CLI, use the `terraform` skill. The Terraform provider names the same fields differently (fleet `name` not `id`, `api_key` not `apiKey`, no `enabled` flag, named `constraints` attributes), so the JSON examples below are wrong as HCL. The product rules here (tier gates, the amd64 arch default, async fleet readiness) apply to both.

## Setup Flow

1. **Create a cluster** — the managed Kubernetes control plane
2. **Create a fleet** — connect a cloud provider account so nodes can be auto-provisioned
3. **Add self-managed nodes** (optional) — join any Linux server to the cluster
4. **Configure kubectl** — set up local access
5. **Deploy a workload** — verify everything works end-to-end

## 1. Create a Cluster

First, fetch available options from the user's organization:

```bash
cloudfleet organization describe -o json -q 'quota.{regions: regions, versions: versions, tiers: cluster_tiers}'
```

Use these values — do NOT hardcode regions or versions. The projection matters: these lists live under `quota`, and the table renderer collapses nested objects to `{...}`, so the bare command returns nothing usable when a profile pins table output.

**If the lists come back empty or missing, the organization has no billing address or payment method.** Quota is only set once billing is complete. This is not a permissions or CLI problem and no cluster can be created until it is fixed in the console at https://console.cloudfleet.ai. Say so instead of retrying or falling back to hardcoded values.

A payment method is required at signup, so every tier is billable from the start. If a tier the user asked for is missing from the list while others are present, tell them rather than silently picking another one.

Then create the cluster:

```bash
cloudfleet clusters create --name <name> --tier <tier> --region <region>
```

Named flags cover top-level scalar fields. For nested fields (`features`, `networking`) pass a document instead, with `-f -` for stdin or `-f <file>`:

```bash
cloudfleet clusters create -f - <<EOF
name: <name>
tier: <tier from quota.cluster_tiers>
region: <region from quota.regions>
version_channel: <version id from quota.versions>
EOF
```

Optional at create time, all Pro/Enterprise only: `release_channel` (`rapid`/`stable`/`extended`, how fast the control plane adopts new versions), `features` (GPU sharing via time-slicing or MPS), and `networking` (custom pod/service CIDRs, IPv4/IPv6 dual-stack). `networking` is immutable once the cluster exists. See [references/cluster-setup.md](references/cluster-setup.md).

Control plane provisions in 2-3 minutes. The cluster starts with zero worker nodes — they provision on-demand when workloads are scheduled.

**Important**: The control plane region is where the management layer runs. It does NOT restrict where worker nodes can be provisioned — fleets cover all available regions of their cloud providers by default.

## 2. Create a Fleet

A fleet connects a cloud provider account so CFKE can auto-provision nodes. At least one provider must be configured for auto-provisioning to work.

Wait for the cluster to reach status `deployed` first. Creating a fleet while the cluster is still provisioning returns 409.

**Fleets are not region-scoped** — a single Hetzner fleet can provision nodes in any Hetzner region (nbg1, fsn1, hel1, ash, sin, etc.). The same applies to AWS and GCP. Use node labels (`topology.kubernetes.io/region`) and placement constraints to control where workloads land.

```bash
cloudfleet clusters fleets create <cluster-id> -f - <<EOF
{
  "id": "my-fleet",
  "hetzner": { "enabled": true, "apiKey": "<hetzner-api-token>" },
  "limits": { "cpu": 24 }
}
EOF
```

Every provider block needs `"enabled": true` alongside its credentials.

**Omitting `constraints` does not mean "no restriction".** The server applies defaults, and the arch default is `["amd64"]`, so a fleet created without constraints will never provision arm64. On Hetzner that silently excludes the CAX line, which is often the cheapest capacity available. Set the constraint explicitly when arm64 is wanted:

```json
"constraints": { "kubernetes.io/arch": ["amd64", "arm64"] }
```

**Fleet creation is asynchronous.** The command returns a fleet ID immediately, but the fleet comes back `ready: false` with `status_message: "object is awaiting reconciliation"`, and the `<fleet-id>-secrets` secret it creates in `kube-system` does not exist until reconciliation finishes (roughly a minute). Anything consuming that secret, a CSI driver in particular, fails until then. Wait for it:

```bash
until [ "$(cloudfleet clusters fleets describe <cluster-id> <fleet-id> -o json -q ready)" = "true" ]; do sleep 5; done
```

Auto-provisioning providers: Hetzner (API token), AWS (IAM role ARN), GCP (project ID). These are the only three in the public fleet schema; Upcloud, Exoscale, Scaleway, and OVH are in private preview: enabling one takes a `general` support ticket (see the `contact` skill). For anything else, join nodes as self-managed. A single fleet can span multiple providers. See [references/cluster-setup.md](references/cluster-setup.md) for all provider examples.

**Updates replace the whole resource.** `clusters update` and `fleets update` are full PUTs: any field left out resets to its default, and a flags-only update is rejected client-side. Read the current state, edit it, pipe it back. See [references/cluster-setup.md](references/cluster-setup.md).

## 3. Add Self-Managed Nodes (Optional)

Any Ubuntu 22.04/24.04 Linux server can join the cluster — bare metal, VMs, edge devices:

```bash
cloudfleet clusters add-self-managed-node <cluster-id> \
  --host <ip-address> \
  --region <datacenter-region> \
  --zone <datacenter-zone>
```

For GPU nodes, add `--install-nvidia-drivers`.

## 4. Configure kubectl

```bash
cloudfleet clusters kubeconfig <cluster-id>
```

## 5. Deploy and Verify

Deploy a test workload to trigger node provisioning:

```bash
kubectl create deployment nginx --image=nginx:latest --replicas=2
kubectl get pods -w
```

Pods transition Pending → ContainerCreating → Running as the auto-provisioner creates nodes. This confirms the full setup — cluster, fleet, and auto-provisioning — is working.
