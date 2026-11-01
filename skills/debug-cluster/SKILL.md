---
name: debug-cluster
description: This skill should be used when the user mentions "debug", "troubleshoot", "why is", "what's wrong", or describes CFKE cluster issues like node failures, pod crashes, or networking problems.
user-invocable: true
argument-hint: "[cluster-name-or-id]"
---

# Debug CFKE Cluster

Guided debugging workflow for Cloudfleet Kubernetes Engine clusters.

kubectl enabled: **${user_config.enable_kubectl}**

## Important Notes

- `kubectl` is a separate tool from the Cloudfleet CLI — there is no `cloudfleet kubectl` command.
- If the user specifies a `--profile`, pass it to all `cloudfleet` CLI commands.
- Pass `-o json` to `cloudfleet` commands. The default `auto` already emits JSON when piped, but a per-profile default or `CLOUDFLEET_OUTPUT_FORMAT` can override it to `table`.
- Narrow large results with `-q` (JMESPath), e.g. `cloudfleet clusters list -q "[].{id:id,name:name,status:status}"`.
- The kubeconfig context name format is `{cluster-id}/{profile-name}`. Do NOT guess — run `kubectl config get-contexts` if unsure.

## Prerequisites

- Cloudfleet CLI installed and authenticated

## Execution Steps

### 1. Identify the cluster

If a cluster name or ID was provided as `$ARGUMENTS`, use it. Otherwise, run `cloudfleet clusters list` (with `--profile` if specified) to show available clusters and ask the user which one to debug. Save the cluster ID as CLUSTER_ID.

### 2. Configure kubectl access (if kubectl enabled)

Use the `cfke-kubeconfig` helper to get an isolated kubeconfig:

```bash
KUBECONFIG=$(cfke-kubeconfig get $CLUSTER_ID)
```

Use `kubectl --kubeconfig $KUBECONFIG` for ALL subsequent kubectl commands. **Never use bare `kubectl`** — the user's active context may point to a different cluster.

### 3. Gather cluster info

**If kubectl is enabled:**

```bash
kubectl --kubeconfig $KUBECONFIG get nodes -o wide
kubectl --kubeconfig $KUBECONFIG get pods --all-namespaces --field-selector=status.phase!=Running
kubectl --kubeconfig $KUBECONFIG get events --all-namespaces --sort-by='.lastTimestamp' | tail -30
```

**If kubectl is not enabled**, use the Cloudfleet MCP `clusters_query` tool (read-only) to check:

- `/api/v1/nodes` — node status
- `/api/v1/pods?fieldSelector=status.phase!=Running` — failing pods
- `/api/v1/events?limit=30` — recent events

### 4. Systematic diagnosis

The checks below are independent. If you can run subagents, run them in parallel and have each report facts only (resource states, error messages, event timestamps), not fixes.

**With kubectl:**

Nodes: Ready/NotReady, conditions (MemoryPressure, DiskPressure, PIDPressure), taints, capacity.

```bash
kubectl --kubeconfig $KUBECONFIG describe nodes | grep -A5 "Conditions:"
kubectl --kubeconfig $KUBECONFIG top nodes
```

Pods: not Running or Succeeded, more than 5 restarts, stuck in Pending (check events for scheduling failures), in CrashLoopBackOff (read the logs of the last crash with `--previous`).

System pods: CoreDNS, Cilium and Konnectivity in kube-system, any not running or restarting.

```bash
kubectl --kubeconfig $KUBECONFIG get pods -n kube-system -o wide
```

Resource pressure: nodes above 85% CPU or memory, and the top consumers.

```bash
kubectl --kubeconfig $KUBECONFIG top pods --all-namespaces --sort-by=memory | head -20
```

Events: warnings in the last 30 minutes, failed scheduling, evictions.

**With MCP only:** Query `/api/v1/namespaces/kube-system/pods` and `/api/v1/nodes` for status details. Note that `kubectl top` equivalents are not available via MCP.

Group the findings as CRITICAL, WARNING and INFO before moving on.

### 5. Targeted investigation

Based on findings, drill into specific areas:

- **Pod failures**: Check logs with `kubectl logs` (requires kubectl), describe pod for events
- **Node issues**: Check node conditions, Cilium status
- **Networking**: Check Cilium pods, CoreDNS, Services/Endpoints
- **Scheduling**: Check resource requests vs available capacity, taints/tolerations
- **`No agent available`**: this error means two different things. If the node is `NotReady` and unreachable, it is down (see `self-managed-node-issues`). If nodes are healthy, it is a transient blip in the control plane tunnel, common right after an operator pod restarts. Retry once before investigating.
- **Storage**: A PVC stuck `Pending` usually means no CSI driver. CFKE installs none for any provider, on purpose: the driver for whichever cloud the nodes run on is yours to install and own. Check for a StorageClass and a running CSI controller before looking further.

### 6. Consult the troubleshooting docs

Once the symptom is identified, open the matching page under `https://cloudfleet.ai/docs/troubleshooting/<slug>/` and follow it. **Fetch the page and read it. Never answer from the slug alone** — these pages change often, and a plausible-sounding answer reconstructed from the URL will be wrong.

| Symptom                                                                       | Slug                            |
| ----------------------------------------------------------------------------- | ------------------------------- |
| Pods stay `Pending`, no nodes appear                                          | `pods-stuck-in-pending`         |
| `kubectl` cannot connect, cluster reported unavailable                        | `cannot-reach-cluster`          |
| API throttling, leader election flapping, GitOps reconcile storms             | `control-plane-pressure`        |
| `exec format error`, arm64/amd64 image mismatch                               | `handle-single-platform-images` |
| Request too large, data store size limits                                     | `kubernetes-api-server-quotas`  |
| LB IP changed, PROXY protocol errors, in-cluster LB access                    | `load-balancer-issues`          |
| Pod-to-pod failures, NetworkPolicy blocking the API server, Tailscale         | `network-connectivity-issues`   |
| PVC stuck `Pending`, PVs stuck attaching or mounting, disk pressure evictions | `persistent-volume-issues`      |
| Self-managed node will not join, frozen, or has host DNS problems             | `self-managed-node-issues`      |

If a fetch returns 404 the page was renamed. Fetch the index at https://cloudfleet.ai/docs/troubleshooting/ and pick from there rather than guessing a new slug.

### 7. Summary

Present findings with:

- Root cause (or most likely candidates)
- Recommended remediation steps
- Any Cloudfleet-specific guidance (e.g., fleet adjustments, version upgrades)

If the issue appears to be on the platform side (e.g., control plane unreachable, API errors), remind the user to check https://status.cloudfleet.ai/ for ongoing incidents and, if needed, offer to open a support ticket with the findings above (`technical` category). If the investigation was slowed by a misleading error, missing docs, or undocumented behavior, offer to send that as feedback as well. The `contact` skill covers both.
