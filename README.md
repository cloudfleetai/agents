# Cloudfleet Plugin for Claude Code

[Claude Code](https://claude.ai/code) plugin by [Cloudfleet](https://cloudfleet.ai) — operate Cloudfleet Kubernetes Engine (CFKE) and Cloudfleet Container Registry (CFCR) with guided workflows, debugging aids, and preconfigured MCP access.

## Features

- **Preconfigured MCP server** — query clusters, list resources, and get cluster info without local setup
- **Feedback prompts**: modelled on the Stripe plugin. When a Cloudfleet skill, MCP tool or CLI command fails, and occasionally after Cloudfleet work, hooks ask the agent to assess it and offer to send feedback through the `feedback_send` MCP tool, or `cloudfleet feedback` on CLI 1.10.0+. The agent shows the draft and sends only after you approve. Works in Claude Code, Codex and Copilot CLI.
- **Reaching Cloudfleet**: the `contact` skill routes between support tickets (anything that needs an answer or an investigation), the roadmap (see, vote on, or suggest concrete features), and feedback (quick one-way notes).
- **Background knowledge** — CFKE architecture, CFCR usage, best practices (resource requests, load balancers, node placement) auto-triggered when relevant
- **Guided workflows** — cluster setup via the CLI or Terraform, fleet configuration, self-managed nodes, debugging

## Installation

### Claude Code

```
/plugin marketplace add cloudfleetai/cloudfleet-plugin-claude
/plugin install cloudfleet@cloudfleet
/reload-plugins
```

### Codex

```bash
codex plugin marketplace add cloudfleetai/cloudfleet-plugin-claude
codex plugin add cloudfleet@cloudfleet
```

Codex runs the feedback hooks only after you trust them: it asks on the next launch, or review them under `/hooks`. Codex asks again after every plugin update, because trust covers the installed plugin's contents.

### Copilot CLI

```bash
copilot plugin marketplace add cloudfleetai/cloudfleet-plugin-claude
copilot plugin install cloudfleet@cloudfleet
```

### Local development

Claude Code loads the working copy directly:

```bash
claude --plugin-dir /path/to/cloudfleet-plugin-claude
```

Use `/reload-plugins` to pick up changes without restarting.

Codex installs a copy, so reinstall after each change:

```bash
codex plugin marketplace add /path/to/cloudfleet-plugin-claude
codex plugin remove cloudfleet@cloudfleet && codex plugin add cloudfleet@cloudfleet
```

Each reinstall invalidates hook trust. For non-interactive test runs of hooks you have reviewed, pass `--dangerously-bypass-hook-trust` to `codex exec`.

Copilot CLI loads a plugin from a local marketplace live from the working copy, so changes take effect in the next session:

```bash
copilot plugin marketplace add /path/to/cloudfleet-plugin-claude
copilot plugin install cloudfleet@cloudfleet
```

`tests/uninstall` removes the plugin and marketplace from every installed harness (and Codex's stored hook trust) before a manual test; `--dry-run` shows what is there.

How each harness finds the plugin:

| Harness | Manifest | Hooks |
| --- | --- | --- |
| Claude Code | `.claude-plugin/plugin.json` | PascalCase events in `hooks/hooks.json` |
| Codex | `.codex-plugin/plugin.json` | `hooks/codex.json` |
| Copilot CLI | `.claude-plugin/plugin.json` | camelCase events in `hooks/hooks.json`; it also fires the PascalCase entries, which the hook ignores there |

The harnesses have different hook events and payloads, so `scripts/feedback-hook` takes the harness as its first argument. A root `plugin.json` (Agent Plugins format) would stop Codex 0.166 from loading any plugin hooks, so there is none.

### Harness tests

`tests/run` checks the working copy in every agent harness it has an adapter for (`tests/harness/*.sh`). It runs locally only, not in CI.

```bash
tests/run                 # discovery: install, skills, MCP server, hooks; no model calls
tests/run --live          # also prompts each harness on its cheapest model (cents per run)
tests/run --live codex    # one harness
tests/run --live --record # after a harness update changed its hook input on purpose
```

Live runs check that the feedback hook sees MCP calls, prompts when a `cloudfleet` command fails, and assesses the next turn, then compare each hook input's fields and types with `tests/shapes/<harness>.json`. Each harness runs against a throwaway home (Codex, Copilot CLI) or with user settings and plugins left out (Claude Code), and cannot send real feedback. To add a harness, write an adapter with the same functions as `tests/harness/codex.sh`.

Validate and lint before submitting changes:

```bash
claude plugin validate .
npx markdownlint-cli 'skills/**/*.md' --config .markdownlint.json
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
