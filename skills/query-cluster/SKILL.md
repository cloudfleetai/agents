---
name: query-cluster
description: This skill should be used when the user wants to check pods, services, deployments, nodes, or any Kubernetes resources on a Cloudfleet cluster.
user-invocable: true
argument-hint: "<cluster-id> <resource>"
---

# Query Cluster

Query Kubernetes resources on a Cloudfleet cluster.

kubectl enabled: **${user_config.enable_kubectl}**

## Important Notes

- `kubectl` is a separate tool from the Cloudfleet CLI — there is no `cloudfleet kubectl` command.
- If the user specifies a `--profile`, pass it to all `cloudfleet` CLI commands.
- Pass `-o json` to `cloudfleet` commands. The default `auto` already emits JSON when piped, but a per-profile default or `CLOUDFLEET_OUTPUT_FORMAT` can override it to `table`.
- Narrow large results with `-q` (JMESPath), e.g. `cloudfleet clusters list -q "[].{id:id,name:name,status:status}"`.
- The kubeconfig context name format is `{cluster-id}/{profile-name}` (e.g., `0bd317f4-.../textcortex`). Do NOT guess — run `kubectl config get-contexts` if unsure.

## Execution Steps

### 1. Determine cluster

If not provided in `$ARGUMENTS`, run `cloudfleet clusters list` (with `--profile` if specified) and ask the user which cluster to query.

### 2. Determine access method and configure

If kubectl is enabled, get an isolated kubeconfig:

```bash
KUBECONFIG="${TMPDIR:-/tmp}"; KUBECONFIG="${KUBECONFIG%/}/cloudfleet-$(id -u)/$CLUSTER_ID.kubeconfig"
mkdir -p "${KUBECONFIG%/*}" && chmod 700 "${KUBECONFIG%/*}"
[ -f "$KUBECONFIG" ] || (umask 077 && cloudfleet clusters kubeconfig "$CLUSTER_ID" --kubeconfig "$KUBECONFIG" >&2)
echo "$KUBECONFIG"
```

The directory is per-user and private, so other local users cannot read or replace the file. Add `--profile` to the `cloudfleet` command if the user named one. Shell variables do not survive between commands, so pass the printed path to later commands.

**Always use `kubectl --kubeconfig $KUBECONFIG`** — never bare `kubectl`, as the user's active context may point to a different cluster.

If kubectl is not enabled, use the Cloudfleet MCP `clusters_query` tool. Note: **MCP provides read-only (GET) access only** — no create, update, delete, exec, logs, or port-forward operations. MCP only works with the `default` CLI profile — if the user has a non-default profile, prefer kubectl with `--profile`.

### 3. Execute query

**With kubectl:**

```bash
kubectl --kubeconfig $KUBECONFIG get <resource> [-n <namespace>] [-o wide]
```

**With MCP (read-only fallback):**
Use the `clusters_query` tool with the cluster ID and Kubernetes API path:

| User request              | API path                                                             |
| ------------------------- | -------------------------------------------------------------------- |
| "show pods" / "list pods" | `/api/v1/pods` or `/api/v1/namespaces/{ns}/pods`                     |
| "show deployments"        | `/apis/apps/v1/deployments`                                          |
| "show services"           | `/api/v1/services`                                                   |
| "show nodes"              | `/api/v1/nodes`                                                      |
| "show events"             | `/api/v1/events`                                                     |
| "show namespaces"         | `/api/v1/namespaces`                                                 |
| "show ingresses"          | `/apis/networking.k8s.io/v1/ingresses`                               |
| "show fleets"             | Use `cloudfleet clusters fleets list <cluster-id>` (not via K8s API) |

When using MCP, prefer narrowing queries with namespace, label selectors, or pagination to avoid large responses.

### 4. Present results

Format the response in a readable way — tables for list results, structured details for single resources. Highlight any issues (unhealthy pods, pending resources, error events).
