---
name: terraform
description: This skill should be used when the user writes, reviews, or applies Terraform/HCL for Cloudfleet (CFKE clusters, fleets, self-managed nodes, the cloudfleet provider), or wants Cloudfleet infrastructure as code instead of the cloudfleet CLI. It is the authority for HCL; the cluster-setup skill covers the CLI and API JSON, whose field names differ.
user-invocable: true
argument-hint: "[what to provision]"
---

# Cloudfleet with Terraform

This skill covers the `cloudfleet` Terraform provider. The `cluster-setup` skill covers the CLI and API, and the two schemas differ in field names, casing and block shape. Never translate a CLI/API JSON example into HCL; write HCL from this skill and [references/terraform.md](references/terraform.md), which has every resource and data source schema.

## Provider

The provider is not on the public Terraform registry. Its source address cannot be guessed:

```hcl
terraform {
  required_providers {
    cloudfleet = {
      source  = "terraform.cloudfleet.ai/cloudfleet/cloudfleet"
      version = "~> <major.minor>"
    }
  }
}

provider "cloudfleet" {}
```

Pin the version from `curl -s https://terraform.cloudfleet.ai/v1/providers/cloudfleet/cloudfleet/versions | jq -r '.versions[].version' | sort -V`. That list is unsorted and includes pre-releases. `hashicorp/cloudfleet`, which appears in one upstream example, does not exist.

Authentication, in order of precedence:

1. `CLOUDFLEET_ACCESS_TOKEN_ID` + `CLOUDFLEET_ACCESS_TOKEN_SECRET` + `CLOUDFLEET_ORGANIZATION_ID` environment variables. This is the path for CI and for anyone who does not want the CLI involved: create an API token in https://console.cloudfleet.ai.
2. `access_token_id` / `access_token_secret` / `organization_id` in the provider block. Do not hardcode secrets there; use variables.
3. A CLI profile: `profile = "<name>"` or `CLOUDFLEET_PROFILE`, else `default`. A profile can also set `api_server`, which redirects the provider to another environment.

`CLOUDFLEET_ORGANIZATION_ID` overrides the profile's organization. A stale export applies to the wrong organization without any error.

## Before writing the cluster: get the org's real options

Regions, Kubernetes versions and tiers vary per organization and must not come from docs, blog posts or memory. There is no Terraform data source for them. Look them up once; the lookup is read-only and leaves nothing in the configuration, so it is compatible with "no CLI in the final version":

```bash
cloudfleet organization describe -o json -q 'quota.{regions: regions, versions: versions, tiers: cluster_tiers}'
```

If the user rules out the CLI even for this, ask them for the region and tier from the console rather than guessing. Empty lists mean billing is not set up, and no cluster can be created until it is.

## Tier gates

All of these are schema-valid, so `terraform plan` passes. They fail at **apply**, when the API rejects them:

| Attribute | Basic | Pro | Enterprise |
| --- | --- | --- | --- |
| `release_channel` | omit it (default `rapid`) | `rapid`, `stable` | `rapid`, `stable`, `extended` |
| `version_channel` | omit it | from org `versions` | from org `versions` |
| `networking` | not allowed | allowed, immutable | allowed, immutable |
| `features` GPU sharing | not allowed | allowed | allowed |

`tier` changes in place, up or down. A downgrade that leaves a now-forbidden value (e.g. `extended` on Pro) is rejected.

## Fleet pitfalls

- **`name` is the fleet's ID.** There is no `id` input. Import is `terraform import cloudfleet_cfke_fleet.<x> <cluster_id>/<fleet_name>`; the `cloudfleet_cfke_fleet` data source takes the fleet name as `id`.
- **Provider blocks have no `enabled` field.** The block's presence enables the provider: `hetzner { api_key = var.hetzner_api_key }`, `aws { role_arn = ... }`, `gcp { project_id = ... }`. At least one is required, which is checked at apply.
- **Set `constraints` explicitly.** Omitting the block applies `arch = ["amd64"]` and `capacity_type = ["on-demand", "spot"]`. An amd64-only fleet never provisions arm64, which on Hetzner excludes the CAX line, often the cheapest capacity. Unless the user wants amd64 only:

  ```hcl
  constraints {
    arch = ["amd64", "arm64"]
  }
  ```

  Each key omitted inside the block resets to its default. `constraints` are not read back from the API, so drift does not show in `plan`; read the effective values from the `cloudfleet_cfke_fleet` data source.
- **`taints` is a list attribute, not a block**: `taints = [{ key = "...", value = "...", effect = "NoSchedule" }]`.
- **Fleet apply returns before the fleet is ready.** The cluster resource waits for `deployed` (up to 20 minutes), so the fleet can depend on it directly. The fleet resource does not wait for `ready`: the `<fleet-name>-secrets` secret in `kube-system` appears about a minute later. Resources that need that secret, a CSI driver in particular, fail if applied in the same run. Put them in a later apply or a separate root module.
- **The Hetzner token is in state.** `api_key` is marked sensitive, but Terraform state stores it in plain text. Use a remote backend with encryption.

## Updates are a full overwrite

Removing an attribute from the configuration resets it to its default on the next apply: cluster `release_channel` returns to `rapid`, fleet `scaling_profile` to `conservative`, `taints` to none, and `constraints` to the defaults above. `plan` shows this as `"old" -> "default"` for everything except `constraints`. Treat a deleted line as a change, not a no-op.

Changing cluster `name`, `region` or `networking`, or fleet `name` or `cluster_id`, replaces the resource. Replacing a cluster deletes it and its workloads.

## Before apply

- Check `~/.terraformrc` (or `$TF_CLI_CONFIG_FILE`) for a `dev_overrides` entry for `terraform.cloudfleet.ai/cloudfleet/cloudfleet`. It silently outranks the pinned version and the lock file, so a local development build runs against real infrastructure. The plugin's PreToolUse hook flags this and asks before `apply`/`destroy`.
- Confirm which organization the credentials resolve to (see Authentication).

## Connecting Kubernetes and Helm providers

```hcl
data "cloudfleet_client_config" "me" {}

provider "kubernetes" {
  host                   = cloudfleet_cfke_cluster.this.endpoint
  cluster_ca_certificate = base64decode(cloudfleet_cfke_cluster.this.certificate_authority)
  token                  = data.cloudfleet_client_config.me.access_token
}
```

The token is a short-lived OAuth access token fetched during the run. Do not write it to outputs or files.

## Self-managed nodes

`cloudfleet_cfke_self_managed_node` joins an existing machine over SSH. `cloudfleet_cfke_node_join_information` renders cloud-init userdata for a VM another provider creates. Both are in [references/terraform.md](references/terraform.md).

## Complete example: cluster plus Hetzner fleet

```hcl
variable "hetzner_api_key" {
  type      = string
  sensitive = true
}

resource "cloudfleet_cfke_cluster" "this" {
  name   = "production"
  region = "<region from org quota>"
  tier   = "basic"
}

resource "cloudfleet_cfke_fleet" "hetzner" {
  name       = "hetzner"
  cluster_id = cloudfleet_cfke_cluster.this.id

  hetzner {
    api_key = var.hetzner_api_key
  }

  limits {
    cpu = 24
  }

  constraints {
    arch = ["amd64", "arm64"]
  }
}
```
