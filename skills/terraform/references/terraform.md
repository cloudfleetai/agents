# Terraform Provider Reference

Schemas for provider `terraform.cloudfleet.ai/cloudfleet/cloudfleet`, taken from the provider's generated docs (`clients/terraform/docs/` in the Cloudfleet API repository). The registry pages at https://terraform.cloudfleet.ai carry the same content for the published version.

## CLI/API JSON vs HCL

The same concept has different names in the two interfaces. Do not carry one into the other.

| Concept | CLI / API JSON | Terraform HCL |
| --- | --- | --- |
| Fleet identity | `"id": "my-fleet"` | `name = "my-fleet"` (`id` is computed) |
| Enabling a provider | `"hetzner": {"enabled": true, ...}` | the block's presence: `hetzner { ... }`, no `enabled` |
| Hetzner token | `apiKey` | `api_key` |
| AWS role | `controllerRoleArn` | `role_arn` |
| GCP project | `project` | `project_id` |
| Scaling profile | `scalingProfile` | `scaling_profile` |
| Constraints | label-keyed map: `{"kubernetes.io/arch": [...]}` | named sets: `constraints { arch = [...] }` |
| Updates | `describe` → edit → `update` (full PUT) | edit config → `apply`; removed lines reset to defaults |

Constraint keys map as `arch` → `kubernetes.io/arch`, `capacity_type` → `karpenter.sh/capacity-type`, `instance_family` → `cfke.io/instance-family`, `region` → `topology.kubernetes.io/region`.

## Provider block

All optional. Environment variables in parentheses.

| Attribute | Notes |
| --- | --- |
| `profile` | CLI profile name (`CLOUDFLEET_PROFILE`). Default `default`. |
| `organization_id` | (`CLOUDFLEET_ORGANIZATION_ID`) |
| `access_token_id` | Sensitive (`CLOUDFLEET_ACCESS_TOKEN_ID`) |
| `access_token_secret` | Sensitive (`CLOUDFLEET_ACCESS_TOKEN_SECRET`) |
| `endpoint` | API URL (`CLOUDFLEET_ENDPOINT`). Default: the profile's `api_server`, else `https://api.cloudfleet.ai/v1`. |
| `auth_server` | (`CLOUDFLEET_AUTH_SERVER`). Default `https://accounts.cloudfleet.ai`. |

## `cloudfleet_cfke_cluster` (resource)

| Attribute | Required | Change | Notes |
| --- | --- | --- | --- |
| `name` | Yes | replace | 1-63 chars, `^[a-z0-9]([-a-z0-9]*[a-z0-9])?$` |
| `region` | Yes | replace | Control plane region from the org's quota. Does not limit where nodes run. |
| `tier` | No | in place | `basic`, `pro`, `enterprise` |
| `version_channel` | No | in place | Default `1.x.x-cfke.x`. Non-default needs Pro+. |
| `release_channel` | No | in place | `rapid` (default), `stable` (Pro+), `extended` (Enterprise) |
| `features` | No | in place | Block. When set, `gpu_sharing_strategy` (`none`/`mps`/`time_slicing`) and `gpu_max_shared_clients_per_gpu` (2-48) are both required. Also `cilium_socket_lb_host_namespace_only` (bool, needed for the Tailscale operator and Istio). GPU sharing needs Pro+. |
| `networking` | No | replace | Block: `pod_cidr`, `service_cidr`, `dual_stack`, `pod_cidr_v6`, `service_cidr_v6` (v6 needs `dual_stack`). Pro+. |

Read-only: `id`, `endpoint`, `certificate_authority` (base64), `kubernetes_version`, `status`, `created_at`, `updated_at`.

Create waits for status `deployed`, polling every 30 seconds for up to 20 minutes. Import: `terraform import cloudfleet_cfke_cluster.<x> <cluster_id>`.

```hcl
resource "cloudfleet_cfke_cluster" "pro" {
  name            = "my-cluster"
  region          = "<region>"
  tier            = "pro"
  release_channel = "stable"

  features {
    gpu_sharing_strategy           = "time_slicing"
    gpu_max_shared_clients_per_gpu = 4
  }

  networking {
    pod_cidr     = "10.96.0.0/16"
    service_cidr = "10.97.0.0/16"
  }
}
```

## `cloudfleet_cfke_fleet` (resource)

| Attribute | Required | Change | Notes |
| --- | --- | --- | --- |
| `cluster_id` | Yes | replace | |
| `name` | Yes | replace | Becomes the fleet ID. |
| `hetzner` | No | in place | Block: `api_key` (sensitive, Read & Write token). |
| `aws` | No | in place | Block: `role_arn`. |
| `gcp` | No | in place | Block: `project_id`. |
| `limits` | No | in place | Block: `cpu` (cores, optional; omit for no bound). |
| `scaling_profile` | No | in place | `conservative` (default, stability) or `aggressive` (cost). |
| `constraints` | No | in place | Block of sets: `arch`, `capacity_type`, `instance_family`, `region`. Default when omitted: `arch = ["amd64"]`, `capacity_type = ["on-demand", "spot"]`. Not read back from the API. |
| `taints` | No | in place | List of `{ key, value (optional), effect }`; effect `NoSchedule`, `PreferNoSchedule` or `NoExecute`. Keys under `node.kubernetes.io`, `node.cloudprovider.kubernetes.io`, `node.cilium.io`, `karpenter.sh` and `cfke.io` are reserved. Omitting removes all taints. |

At least one of `hetzner`, `aws`, `gcp` must be present. Read-only: `id`, `ready`, `status_message` (only when not ready), `created_at`, `updated_at`. Import: `terraform import cloudfleet_cfke_fleet.<x> <cluster_id>/<fleet_name>`.

Fleets are not region-scoped: one Hetzner fleet provisions in every Hetzner location unless `constraints.region` narrows it.

```hcl
resource "cloudfleet_cfke_fleet" "aws" {
  name            = "aws-production"
  cluster_id      = cloudfleet_cfke_cluster.this.id
  scaling_profile = "conservative"

  aws {
    role_arn = "arn:aws:iam::123456789012:role/CloudFleetKarpenter"
  }

  limits {
    cpu = 50
  }

  constraints {
    arch          = ["amd64", "arm64"]
    capacity_type = ["on-demand"]
  }

  taints = [
    { key = "dedicated", value = "production", effect = "NoSchedule" },
  ]
}
```

## `cloudfleet_cfke_self_managed_node` (resource)

Installs the node agent on an existing machine over SSH.

| Attribute | Required | Notes |
| --- | --- | --- |
| `cluster_id` | Yes | |
| `region` | Yes | Becomes `topology.kubernetes.io/region`. |
| `zone` | Yes | Becomes `topology.kubernetes.io/zone`. |
| `ssh` | No | Block: `host`, `user` (required); `port` (default 22), `private_key_path` or `password`. |
| `install_nvidia_drivers` | No | Default false. |
| `node_labels` | No | Map, merged with the topology labels. |
| `node_taints` | No | List of `{ key, value, effect }`, applied at registration. |

```hcl
resource "cloudfleet_cfke_self_managed_node" "server" {
  cluster_id = cloudfleet_cfke_cluster.this.id
  region     = "datacenter-1"
  zone       = "rack-a"

  ssh {
    host             = "192.168.1.100"
    user             = "ubuntu"
    private_key_path = "~/.ssh/id_ed25519"
  }
}
```

## `cloudfleet_cfke_node_join_information` (resource)

Renders cloud-init userdata (`rendered`, sensitive) for a VM created by another provider. Takes `cluster_id`, `region`, `zone`, and optionally `install_nvidia_drivers`, `node_labels`, `gzip`, `base64_encode`.

`gzip` and `base64_encode` both default to **false**, whatever the upstream example's comment says. Match the encoding to the consumer: `aws_instance.user_data` takes plain text and encodes it itself, while `user_data_base64` takes base64 output.

```hcl
resource "cloudfleet_cfke_node_join_information" "node" {
  cluster_id = cloudfleet_cfke_cluster.this.id
  region     = "datacenter-1"
  zone       = "rack-a"
}

resource "aws_instance" "worker" {
  ami           = "<ami>"
  instance_type = "t3.medium"
  user_data     = cloudfleet_cfke_node_join_information.node.rendered
}
```

## Data sources

- `cloudfleet_cfke_cluster`: input `id`. Returns the cluster's attributes including `release_channel`, `features` and `networking`.
- `cloudfleet_cfke_fleet`: inputs `cluster_id` and `id` (the fleet name). Returns the effective configuration, including the server-applied `constraints`, plus `enabled` on each provider block. The Hetzner key is never returned.
- `cloudfleet_client_config`: no inputs. Returns `access_token`, `organization_id` and `user` for the active credentials. With `data "cloudfleet_client_config" "me" {}` declared, `echo 'data.cloudfleet_client_config.me.organization_id' | terraform console` shows which org a configuration targets without planning anything.
