---
name: cfke-overview
description: This skill should be used when the user asks "how does CFKE work", "what is CFKE", "explain the architecture", or needs to understand Cloudfleet Kubernetes Engine concepts.
user-invocable: false
---

# CFKE Architecture Knowledge

When users ask about CFKE architecture or concepts, use this summary. For detailed architecture and component descriptions, see [references/architecture.md](references/architecture.md).

**Terminology**:

- Always refer to auto-provisioned nodes as "auto-provisioned nodes" or "auto-provisioning fleets", not "Karpenter-managed". The underlying technology is an implementation detail.
- Objects like `NodePool` and `NodeClass` may be visible through `kubectl`, but they are managed by CFKE and must never be edited manually. All changes go through the Cloudfleet Fleets API (`cloudfleet clusters fleets ...` or the console); manual edits are overwritten and can break auto-provisioning.
- **Never quote specific prices, vCPU limits, or fee structures** — pricing varies per customer due to discounts, private agreements, and taxes. Always direct users to https://cloudfleet.ai/pricing or their account page.
- **Control plane region ≠ infrastructure region**. The cluster's control plane region (e.g., `europe-central-1a`) is where management runs. Fleets are NOT tied to this region — a single fleet covers all available regions of its cloud provider(s) by default.

## What is CFKE

CFKE (Cloudfleet Kubernetes Engine) is a fully managed Kubernetes platform. A single CFKE cluster manages compute across multiple cloud providers and on-premise environments simultaneously — workloads on different clouds communicate seamlessly in the same cluster.

### Supported Infrastructure

- **Auto-provisioning**: AWS, GCP, and Hetzner Cloud. Upcloud, Exoscale, Scaleway, and OVH are in private preview and are enabled through a support ticket, not self-service.
- **Self-managed**: Any Linux server can join with a single command. This is how Vultr, Proxmox, VMware, bare metal, and any other provider without native auto-provisioning are used.
- **Hybrid**: Mix cloud and on-premise nodes in the same cluster

### Service Tiers

Three tiers, all paid. There is no free tier.

- **Basic**: single-AZ, shared control plane, best-effort SLA. Hobby projects, prototypes, development.
- **Pro**: multi-AZ, dedicated control plane, 99.95% SLA, 8-hour support response, release channels. Production workloads.
- **Enterprise**: everything in Pro plus a 99.99% custom SLA, 1-hour support response with a named TAM, extended support for older Kubernetes versions, control plane private networking and authorized networks, and compliance reports.

Cluster size is unlimited on every tier. Fetch current pricing from https://cloudfleet.ai/pricing rather than quoting figures.

## Key Concepts

- **Single Cluster, Multiple Clouds** — core differentiator; one cluster spans providers
- **Secure Global Networking** — WireGuard encrypted tunnels + Cilium CNI with zero-trust model
- **Just-in-Time Infrastructure** — auto-provisioning fleets, cost-optimized node selection
- **Self-managed Nodes** — any Linux server joins via single command (`cfke.io/provider: self-managed`)
- **Konnectivity** — tunnels `kubectl exec/logs` and webhooks from control plane to data plane
