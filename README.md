# github_pr_monitor

A simple Bash tool to query and filter GitHub pull requests across multiple repositories.

You can filter PRs by:
- Reviewers: one or more GitHub usernames
- Teams: one or more GitHub teams (e.g. org/team-slug)
- Created date: only show PRs opened within the last N days
- Approval status: skip PRs you've already approved (enabled by default)

---

## Setup

1. Install GitHub CLI (gh) and authenticate:

gh auth login

2. Install jq

3. Create a `.env` file in the project root:

REVIEW_USERS="your-username another-user"  
REVIEW_TEAMS="your-org/team-slug another-org/another-team"  
REPOS="org1/repo1 org2/repo2"  
PR_LOOKBACK_DAYS=180
SKIP_ALREADY_APPROVED=true

- `REVIEW_USERS` — space-separated GitHub usernames to match as reviewers  
- `REVIEW_TEAMS` — space-separated team slugs in org/team format  
- `REPOS` — space-separated org/repo names  
- `PR_LOOKBACK_DAYS` — optional; defaults to 180  
- `SKIP_ALREADY_APPROVED` - optional; defaults to true. Set to false to include PRs you've already approved

---

## Usage

Run the script:

./pr-filter.sh

Optionally specify a different .env file:

./pr-filter.sh path/to/your.env

---

## What It Does

For each repo in REPOS:

- Queries all open PRs (via GitHub CLI and pagination)
- Filters PRs opened within the last PR_LOOKBACK_DAYS
- Matches PRs where any of the usernames or teams are explicitly requested as reviewers

---

## Example Output

🔍 Checking repo: org/repo-a

- [Fix login bug](https://github.com/org/repo-a/pull/42) (org/repo-a#42)

🔍 Checking repo: org/repo-b

- [Improve onboarding flow](https://github.com/org/repo-b/pull/1337) (org/repo-b#1337)

---

## License

MIT — free to use, modify, and distribute.
