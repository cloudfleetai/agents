---
name: setup
description: This skill should be used when the user mentions "setup", "install", "configure", "authenticate", "login", or is getting started with Cloudfleet.
user-invocable: true
---

# Cloudfleet Setup

Guide users through installing and configuring the Cloudfleet CLI.

## Execution Steps

### 1. Check current state

```bash
which cloudfleet && cloudfleet --version || echo "NOT_INSTALLED"
```

This plugin requires CLI **1.2 or newer**. Write commands changed their input model in 1.0, so older versions reject the syntax the other skills use. If the reported version is older, tell the user to upgrade before continuing:

An older CLI also advertises an older feature set. If a field or flag the docs describe is missing from `--help`, treat that as an out-of-date binary, not a missing feature, and upgrade before telling the user something is unsupported.

```bash
brew upgrade cloudfleet-cli                                    # macOS
sudo apt-get update && sudo apt-get install --only-upgrade cloudfleet  # Debian/Ubuntu
sudo dnf upgrade cloudfleet                                    # Red Hat-based
winget upgrade Cloudfleet.CLI                                  # Windows
```

### 2. Install if needed

If not installed, guide the user based on their platform:

**macOS (Homebrew):**

```bash
brew install cloudfleetai/tap/cloudfleet-cli
```

**Linux (Debian/Ubuntu):**

```bash
curl -fsSL https://downloads.cloudfleet.ai/apt/pubkey.gpg | sudo tee /usr/share/keyrings/cloudfleet-archive-keyring.gpg >/dev/null
echo "deb [signed-by=/usr/share/keyrings/cloudfleet-archive-keyring.gpg] https://downloads.cloudfleet.ai/apt stable main" | sudo tee /etc/apt/sources.list.d/cloudfleet.list
sudo apt-get update && sudo apt-get install cloudfleet
```

**Linux (Red Hat-based):** Cloudfleet CLI is available at Cloudfleet's YUM repository for x64 and ARM architectures:

```bash
sudo tee /etc/yum.repos.d/cloudfleet.repo << 'EOF'
[cloudfleet]
name=Cloudfleet
baseurl=https://downloads.cloudfleet.ai/yum
enabled=1
gpgcheck=1
gpgkey=https://downloads.cloudfleet.ai/yum/pubkey.gpg
EOF
sudo dnf install cloudfleet
```

**Windows (winget):**

```
winget install Cloudfleet.CLI
```

For other platforms, direct to https://cloudfleet.ai/docs/introduction/getting-started/

### 3. Add a profile

The user needs their Organization ID (found in Console under Billing → Payment):

```bash
cloudfleet auth add-profile user default <ORGANIZATION_ID>
```

This only registers the profile. Authentication happens automatically when the user first runs a command that requires it (e.g., listing clusters), which will open a browser for login.

### 4. Verify

Check that a profile exists:

```bash
cloudfleet auth list-profiles
```

Then verify the credentials work:

```bash
cloudfleet organization describe
```

This returns info about the user's Cloudfleet organization, confirming authentication is working.

### 5. Configure kubectl (optional)

If the user wants to use kubectl with a cluster:

```bash
cloudfleet clusters kubeconfig <CLUSTER_ID>
```

This writes a kubeconfig that can be used with `kubectl cluster-info` and `kubectl get nodes`.

### 6. MCP server

Let the user know that the Cloudfleet MCP server is already configured via this plugin. They can verify it's working by asking about their clusters.

**Note**: The MCP server currently uses the `default` CLI profile only. If the user has a non-default profile, they should either configure a `default` profile pointing to the same organization, or use kubectl with `--profile` for CLI commands instead.

### 7. Reaching Cloudfleet

Let the user know there are three ways to reach Cloudfleet, and that you can use any of them for them (see the `contact` skill):

- **Support ticket** for anything that needs an answer: something broken, a problem in their environment, billing, or wanting to talk to the team.
- **Roadmap** to see requested features, vote on them, or suggest a concrete new one.
- **Feedback** for quick one-way notes, such as typos, missing docs, confusing errors, undocumented behavior, or an idea. It gets no reply.
