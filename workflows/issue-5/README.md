# Weekly Dev Summary — n8n + Claude API

An n8n workflow that automatically generates a **narrative weekly development summary** for any GitHub repository, powered by the Claude API (`claude-sonnet-4-20250514`).

---

## What It Does

Every **Monday at 9:00 AM**, the workflow:

1. **Fetches** the past week's commits, closed issues, and merged PRs from the GitHub API
2. **Aggregates** the data (counts, top contributors, key messages)
3. **Calls Claude** to generate a structured Markdown narrative summary
4. **Delivers** the summary to **Slack** (if a webhook URL is configured) or logs it to the n8n execution history

### Sample Output

> **Weekly Dev Summary — your-org/your-repo**
> _2026-05-19 → 2026-05-26_
>
> ### Overview
> This was a productive week with 23 commits across 6 contributors...
>
> ### By the Numbers
> - Commits: 23 | PRs Merged: 5 | Issues Closed: 8
>
> ### Top Contributors
> - alice (9 commits), bob (7 commits)...
>
> ### Key Changes
> - Refactored auth module (#142)
> - Added rate limiting to API (#145)
>
> ### Closed Issues
> - #138 Memory leak in worker pool
> - #140 Dashboard loading time
>
> ### Looking Ahead
> Keep up the momentum! 🚀

---

## Setup (5 Steps)

### Step 1 — Import the Workflow

In your n8n instance, go to **Workflows → Import from File** and upload `weekly-dev-summary.json`.

### Step 2 — Create GitHub API Credential

1. Go to **Credentials → New Credential → Header Auth**
2. Name it `GitHub API Token`
3. Set **Header Name** to `Authorization`
4. Set **Header Value** to `Bearer ghp_YOUR_GITHUB_TOKEN` (use a [personal access token](https://github.com/settings/tokens) with `repo` scope)
5. In the workflow, edit each **Fetch** node → select this credential

### Step 3 — Create Claude API Credential

1. Go to **Credentials → New Credential → Header Auth**
2. Name it `Claude API Key`
3. Set **Header Name** to `x-api-key`
4. Set **Header Value** to your [Anthropic API key](https://console.anthropic.com/)
5. In the **Generate Summary (Claude)** node → select this credential

> ⚠️ The Claude API request also requires an `anthropic-version` header. Open the **Generate Summary (Claude)** node → **Headers** section and add:
> - `anthropic-version` → `2023-06-01`
> - `content-type` → `application/json`

### Step 4 — Configure Variables

Edit the **Config** node and set:

| Variable | Description | Example |
|---|---|---|
| `githubOwner` | GitHub org or user | `claude-builders-bounty` |
| `githubRepo` | Repository name | `claude-builders-bounty` |
| `language` | Output language (`EN` or `FR`) | `EN` |
| `slackWebhookUrl` | Slack incoming webhook (leave empty to skip) | `https://hooks.slack.com/...` |
| `claudeApiKey` | (Override) Claude API key | Leave blank if using credential |

### Step 5 — Activate & Test

1. Click **Active** to enable the scheduled trigger
2. Click **Test Workflow** to run it manually and verify output
3. Check the **Post to Slack** or **Log Summary** node output for the generated Markdown

---

## Architecture

```
Schedule (Mon 9am)
  → Config (set repo, language, webhook)
    → Compute Date Range (last 7 days)
      → Fetch Commits ──┐
      → Fetch Issues ────┤→ Aggregate Data → Claude API → Extract Summary → Slack? → Post / Log
      → Fetch PRs ───────┘
```

## Configurable Variables

All variables are set in the **Config** node and can be overridden with environment variables:

| Env Variable | Config Field | Default |
|---|---|---|
| `GITHUB_OWNER` | `githubOwner` | `your-org` |
| `GITHUB_REPO` | `githubRepo` | `your-repo` |
| `SUMMARY_LANGUAGE` | `language` | `EN` |
| `SLACK_WEBHOOK_URL` | `slackWebhookUrl` | _(empty)_ |
| `CLAUDE_API_KEY` | `claudeApiKey` | _(empty)_ |

## Delivery Options

| Method | How |
|---|---|
| **Slack** | Set `slackWebhookUrl` in the Config node — the workflow posts the Markdown summary as a Slack message |
| **Discord** | Replace the **Post to Slack** node with a Discord webhook (same format, adjust JSON payload) |
| **Email** | Replace with n8n's built-in **Send Email** node |
| **Execution Log** | If no webhook is set, the summary is logged and visible in n8n's execution history |

## Requirements

- **n8n** 1.0+ (self-hosted or cloud)
- **GitHub** personal access token with `repo` scope
- **Anthropic** API key with access to `claude-sonnet-4-20250514`
- (Optional) **Slack** incoming webhook URL

## Troubleshooting

| Issue | Fix |
|---|---|
| GitHub returns 401 | Check your token has `repo` scope and the credential header is `Bearer ghp_...` |
| Claude returns 401 | Verify the `x-api-key` header and `anthropic-version: 2023-06-01` are set |
| Empty commits/issues | Ensure the repo has activity in the past week; check date range in the **Compute Date Range** node |
| Slack not receiving | Test the webhook URL with `curl -X POST -H 'Content-type: application/json' --data '{"text":"test"}' YOUR_WEBHOOK_URL` |

## License

MIT — same as the parent repository.
