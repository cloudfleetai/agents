---
name: contact
description: This skill should be used when the user wants to reach Cloudfleet - open, check, or reply to a support ticket, ask about billing, invoices, or their account, request or vote on a feature, see the roadmap, or send feedback about Cloudfleet or this plugin (typos, missing or wrong docs, undocumented behavior, confusing errors). Also use it to choose the right channel whenever something on the Cloudfleet side is broken, missing, or worth reporting.
user-invocable: true
argument-hint: "[what to tell Cloudfleet]"
---

# Contacting Cloudfleet

Cloudfleet has three channels. Choose by what the user needs back.

| Channel | Use it for | What comes back | CLI | MCP |
| --- | --- | --- | --- | --- |
| **Support ticket** | Something is broken; a problem that needs Cloudfleet to look into the user's organization, clusters, or fleets; billing, invoices, payment, plans, quota; private-preview access; the user wants to talk to someone | A reply thread from the Cloudfleet team, open until closed | `cloudfleet tickets` | `tickets_create`, `tickets_reply`, `tickets_list`, `tickets_get`, `tickets_grant_support_access` |
| **Roadmap** | A concrete feature the user wants: see whether it is already requested, vote on it, or suggest it | Items every customer can see and vote on; suggestions are reviewed before they appear | `cloudfleet roadmap` | none |
| **Feedback** | Quick one-way notes without a defined scope: typos, missing or wrong docs, undocumented behavior, confusing errors, small gaps, a rough idea for a feature or product, and what worked well | Nothing: the team reads it, but there is no reply and no status | `cloudfleet feedback` | `feedback_send` |

Routing:

- **Needs an answer or an investigation → ticket.** Feedback never gets a reply, so never route a problem the user is blocked on to feedback.
- **A feature someone could vote on → roadmap.** A vague wish, or something too small for a roadmap item → feedback.
- **Platform looks down** (control plane unreachable, API errors): check https://status.cloudfleet.ai first. Open a ticket if the incident is not listed or the user is affected in a way the status page does not explain.
- One situation can need two channels: a ticket for the broken cluster, plus feedback about the error message that hid the cause. Do not send the same text to both.

For every channel: draft the text, show it to the user, and send only after they approve it. Leave out secrets, tokens, kubeconfig contents, and customer data.

The `feedback_send` and `tickets_*` MCP tools work with any CLI version, because `cloudfleet mcp` forwards requests to the server. The `cloudfleet feedback` command needs CLI 1.10.0 or newer; if it or `cloudfleet roadmap` is an unknown command, ask the user to upgrade, and send feedback through the MCP tool meanwhile.

## Support tickets

- **Category** routes the ticket to a team:
  - `technical`: clusters, fleets, nodes, networking, registry, the CLI, Terraform, or MCP not working.
  - `billing`: invoices, payment methods, plans, quota.
  - `general`: everything else, including enabling a private-preview provider and talking to sales.
- **Body** is markdown, and its first line becomes the ticket summary, so make that line specific. Include the cluster ID, region, what was tried, the exact error, and when it happened (UTC). `properties` can carry `cluster_id`, `cluster_name`, or `region` (MCP; the CLI takes them through `-f`).
- **Attachments** are CLI only: `--attachments <file>`, repeatable, up to 3 files of 10 MB each. MCP cannot upload them, so paste the relevant log excerpt into the body instead.
- **Support access** (`--grant-support-access`, `grant_support_access`) lets Cloudfleet staff access the organization's resources while the ticket is open. It **cannot be revoked**; it ends only when the ticket is closed. Explain this and set it only when the user explicitly agrees. It can be granted later with `cloudfleet tickets grant-access-ticket <ticket-id>` or `tickets_grant_support_access`.
- **Follow-up:** `cloudfleet tickets list`, `describe-ticket <id>`, `reply-ticket <id>`, `close-ticket <id>`, or the matching MCP tools.

```bash
cloudfleet tickets create-ticket --category technical --body "$(cat <<'EOF'
Hetzner fleet nodes stay NotReady after provisioning

Cluster: <cluster-id> (europe-central-1a). Since 2026-11-01 09:00 UTC every new
node in fleet `hetzner` stays NotReady. `kubectl describe node` shows ...
EOF
)"
```

## Roadmap

1. List first: `cloudfleet roadmap list -o json`. Each item is `{id, text, vote}`, where `vote` is the user's own vote (`null` if none). Other users' votes are not returned.
2. If an item matches, ask the user how to vote, then `cloudfleet roadmap vote <id> --value <1|2|-1>` (up, double up, down). A new vote replaces the old one; `cloudfleet roadmap unvote <id>` removes it.
3. If nothing matches, `cloudfleet roadmap suggest --text "<one or two sentences>"`. The suggestion carries the user's up vote and is reviewed before it appears. Make it concrete: what, for which provider or use case, and why.

Do not suggest something that is already listed under different wording; vote on the existing item.

## Feedback

```bash
cloudfleet feedback --sentiment <positive|neutral|negative> \
  --message "<what was useful, confusing, wrong, or missing>" \
  --context "<what the user was trying to do>" \
  --source plugin --client cloudfleet-plugin-claude
```

Or the `feedback_send` MCP tool with `sentiment`, `message`, `context`, and `client`. Keep one point per message (up to 2000 characters each for message and context). Use the sentiment honestly; positive feedback is useful too. Tell the user the team reads it but does not reply.

This plugin's hooks occasionally ask you to assess recent Cloudfleet work and offer feedback. Apply the routing above when they do: a blocking problem is a ticket, and a concrete feature request belongs on the roadmap.
