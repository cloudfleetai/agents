# Cloudfleet Plugin for Claude Code

[Claude Code](https://claude.ai/code) plugin by [Cloudfleet](https://cloudfleet.ai) — operate Cloudfleet Kubernetes Engine (CFKE) and Cloudfleet Container Registry (CFCR) with guided workflows, debugging aids, and preconfigured MCP access.

## Features

- **Preconfigured MCP server** — query clusters, list resources, and get cluster info without local setup
- **Feedback prompts**: modelled on the Stripe plugin. When a Cloudfleet skill, MCP tool or CLI command fails, and occasionally after Cloudfleet work, hooks ask Claude to assess it and offer to send feedback through the `feedback_send` MCP tool, or `cloudfleet feedback` on CLI 1.10.0+. Claude shows the draft and sends only after you approve.
- **Reaching Cloudfleet**: the `contact` skill routes between support tickets (anything that needs an answer or an investigation), the roadmap (see, vote on, or suggest concrete features), and feedback (quick one-way notes).
- **Background knowledge** — CFKE architecture, CFCR usage, best practices (resource requests, load balancers, node placement) auto-triggered when relevant
- **Guided workflows** — cluster setup via the CLI or Terraform, fleet configuration, self-managed nodes, debugging

## Configuration

| Option | Type | Description |
|--------|------|-------------|
| `enable_kubectl` | boolean | Enable kubectl for direct cluster access. When disabled, read-only MCP access is used. |

## Installation

### From GitHub

```
/plugin marketplace add cloudfleetai/cloudfleet-plugin-claude
/plugin install cloudfleet@cloudfleet
/reload-plugins
```

### Local development

```bash
claude --plugin-dir /path/to/cloudfleet-plugin-claude
```

Use `/reload-plugins` to pick up changes without restarting.

Validate and lint before submitting changes:

```bash
claude plugin validate .
npx markdownlint-cli 'skills/**/*.md' 'agents/**/*.md' --config .markdownlint.json
scripts/test-feedback-hook
```

## Getting Started

Once installed, try these prompts:

- `I'm getting started with Cloudfleet` — walks you through CLI setup and authentication
- `What clusters do I have?` — lists your clusters with status and details
- `Create a new cluster on Hetzner` — guided cluster and fleet setup
- `Write Terraform for a CFKE cluster with a Hetzner fleet`: HCL against the Cloudfleet provider
- `Check if my cluster follows best practices` — audits deployments for resource requests, LB policy, node placement
- `Debug my cluster, pods are stuck in Pending` — systematic debugging workflow
- `Is anyone else asking for ARM nodes on Hetzner?`: checks the roadmap, votes, or suggests it
- `Push my app image to CFCR` — container registry guidance
- `Add a self-managed node to my cluster` — join any Linux server

## Requirements

- [Cloudfleet CLI](https://cloudfleet.ai/docs/introduction/getting-started/) v1.2+ (write commands changed their input model in 1.0)
- A Cloudfleet account with at least one configured authentication profile
- (Optional) `kubectl` for full cluster access
- `jq`, required by the feedback hook. Without it the hook stays silent.

## Documentation

- [Cloudfleet Docs](https://cloudfleet.ai/docs)
- [MCP Server](https://cloudfleet.ai/docs/introduction/mcp-server/)
- [Getting Started](https://cloudfleet.ai/docs/introduction/getting-started/)

## Skills

| Skill            | Invocable | Description                                                  |
| ---------------- | --------- | ------------------------------------------------------------ |
| `setup`          | Yes       | Install CLI, authenticate, configure access                  |
| `cluster-info`   | Yes       | List and inspect Cloudfleet clusters                         |
| `query-cluster`  | Yes       | Query Kubernetes resources (kubectl or MCP)                  |
| `debug-cluster`  | Yes       | Guided cluster debugging workflow                            |
| `cluster-setup`  | Yes       | Create clusters, fleets, add self-managed nodes with the CLI |
| `terraform`      | Yes       | Clusters, fleets and nodes with the Terraform provider       |
| `best-practices` | Auto      | Resource requests, LB policy, node placement                 |
| `cfke-overview`  | Auto      | CFKE architecture and concepts                               |
| `cfcr-overview`  | Auto      | Container registry usage                                     |
| `contact`        | Yes       | Support tickets, roadmap, and feedback                       |

## Disclaimer

This plugin is provided as-is. AI-generated output may be inaccurate or incomplete — always review commands before executing them, especially those that create or modify infrastructure. LLMs may have outdated knowledge about Cloudfleet pricing, policies, and features — refer to https://cloudfleet.ai/docs for current information. Cloudfleet is not responsible for unintended changes made through AI-assisted workflows.
