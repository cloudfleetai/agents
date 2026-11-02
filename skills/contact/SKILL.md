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
| **Support ticket** | A problem that needs back-and-forth or debugging: something broken in the user's organization, clusters, or fleets; billing, invoices, payment, plans, quota; private-preview access; the user wants to talk to someone | A reply thread from the Cloudfleet team, open until closed | `cloudfleet tickets` | `tickets_create`, `tickets_reply`, `tickets_list`, `tickets_get`, `tickets_grant_support_access` |
| **Roadmap** | A concrete feature the user wants: see whether it is already requested, vote on it, or suggest it | Items shared with all customers; votes set what the team builds next; suggestions appear after review | `cloudfleet roadmap` | none |
| **Feedback** | Papercuts the team can act on from the note alone: typos, missing or wrong docs, undocumented behavior, confusing errors, small gaps, a rough idea, and what worked well | Delivered to the Cloudfleet team as a standalone note | `cloudfleet feedback` | `feedback_send` |

Routing:

- **Needs back-and-forth or debugging → ticket.** A feedback note starts no conversation, so a problem the user is blocked on always goes to a ticket.
- **A feature someone could vote on → roadmap.** Votes set Cloudfleet's priorities, so when a matching item exists, encourage the user to vote on it. A vague wish, or something too small for a roadmap item → feedback.
- **Platform looks down** (control plane unreachable, API errors): check https://status.cloudfleet.ai first. Open a ticket if the incident is not listed or the user is affected in a way the status page does not explain.
- One situation can need two channels: a ticket for the broken cluster, plus feedback about the error message that hid the cause. Do not send the same text to both.

Describing the channels to the user:

- Support: "A support ticket starts a conversation with the Cloudfleet team to work through the problem with you."
- Roadmap: "Votes on the roadmap decide what the Cloudfleet team builds next, so vote on anything you care about. New suggestions show up for everyone after a review, and progress is shared through the documentation and release notes."
- Feedback: "This sends a short note straight to the Cloudfleet team."

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

The roadmap shows items and votes, not progress. Cloudfleet shares progress through its documentation and release notes.

1. List first: `cloudfleet roadmap list -o json`. Each item is `{id, text, vote}`, where `vote` is the user's own vote (`null` if none). Other users' votes are not returned.
2. If an item matches, ask the user how to vote, then `cloudfleet roadmap vote <id> --value <1|2|-1>` (up, double up, down). A new vote replaces the old one; `cloudfleet roadmap unvote <id>` removes it.
3. If nothing matches, `cloudfleet roadmap suggest --text "<one or two sentences>"`. The suggestion carries the user's up vote and is reviewed before it appears. Make it concrete: what, for which provider or use case, and why.

Do not suggest something that is already listed under different wording; vote on the existing item.

## Feedback

```bash
cloudfleet feedback --sentiment <positive|neutral|negative> \
  --message "<what was useful, confusing, wrong, or missing>" \
  --context "<what the user was trying to do>" \
  --source plugin --client cloudfleet-plugin-<agent>
```

Set `<agent>` to the agent you run in: `claude`, `codex`, `copilot`, `antigravity`, `cursor`, or `kiro`.

Or the `feedback_send` MCP tool with `sentiment`, `message`, `context`, and `client`. Keep one point per message (up to 2000 characters each for message and context). Use the sentiment honestly; positive feedback is useful too. Tell the user it goes straight to the Cloudfleet team.

This plugin's hooks occasionally ask you to assess recent Cloudfleet work and offer feedback. Apply the routing above when they do: a blocking problem is a ticket, and a concrete feature request belongs on the roadmap.
