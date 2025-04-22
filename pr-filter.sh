#!/bin/bash

# --- Disable pager ---
export GH_PAGER=cat

# --- Load .env file if it exists ---
ENV_FILE="${1:-.env}"
if [ -f "$ENV_FILE" ]; then
  echo "📄 Loading environment from $ENV_FILE"
  set -o allexport
  # shellcheck source=/dev/null
  source "$ENV_FILE"
  set +o allexport
else
  echo "⚠️  No .env file found at '$ENV_FILE'. Falling back to current environment."
fi

# --- Check required env vars ---
if [[ -z "$REPOS" ]]; then
  echo "❌ Missing REPOS. Please set it in .env or environment"
  exit 1
fi

# Default to 6 months if not set
PR_LOOKBACK_DAYS="${PR_LOOKBACK_DAYS:-180}"

# Default to skipping already approved PRs
SKIP_ALREADY_APPROVED="${SKIP_ALREADY_APPROVED:-true}"

echo "ℹ️  REVIEW_USERS: $REVIEW_USERS"
echo "ℹ️  REVIEW_TEAMS: $REVIEW_TEAMS"
echo "ℹ️  REPOS: $REPOS"
echo "ℹ️  PR_LOOKBACK_DAYS: $PR_LOOKBACK_DAYS"
echo "ℹ️  SKIP_ALREADY_APPROVED: $SKIP_ALREADY_APPROVED"

# --- Compute cutoff date ---
CUTOFF_DATE=$(date -u -v-"$PR_LOOKBACK_DAYS"d +%Y-%m-%dT%H:%M:%SZ 2>/dev/null || date -u -d "$PR_LOOKBACK_DAYS days ago" +%Y-%m-%dT%H:%M:%SZ)

# --- Convert inputs to arrays ---
USER_LIST=($REVIEW_USERS)
TEAM_SLUGS=()
for team in $REVIEW_TEAMS; do
  TEAM_SLUGS+=("${team##*/}")
done

for REPO in $REPOS; do
  echo
  echo "🔍 Checking repo: $REPO"

  while read -r pr; do
    # Decode base64 JSON
    _jq() {
      echo "$pr" | base64 --decode | jq -r "$1"
    }

    PR_TITLE=$(_jq '.title')
    PR_URL=$(_jq '.html_url')
    PR_NUM=$(_jq '.number')
    PR_REVIEWERS=$(_jq '.reviewers[]?')
    PR_TEAMS=$(_jq '.teams[]?')

    MATCHED=0
    REVIEW_USER=""

    # Match users
    for user in "${USER_LIST[@]}"; do
      if grep -q "^$user$" <<<"$PR_REVIEWERS"; then
        MATCHED=1
        REVIEW_USER="$user"
        break
      fi
    done

    # Match teams
    if [[ "$MATCHED" -eq 0 ]]; then
      for team in "${TEAM_SLUGS[@]}"; do
        if grep -q "^$team$" <<<"$PR_TEAMS"; then
          MATCHED=1
          REVIEW_USER="$GITHUB_USER" # fallback if team match
          break
        fi
      done
    fi

    # Skip PRs already approved by you, if flag is enabled
    if [[ "$MATCHED" -eq 1 && "$SKIP_ALREADY_APPROVED" == "true" && -n "$REVIEW_USER" ]]; then
      reviews=$(gh api "repos/$REPO/pulls/$PR_NUM/reviews")
      already_approved=$(echo "$reviews" | jq -r --arg login "$REVIEW_USER" '
        map(select(.user.login == $login and .state == "APPROVED")) | length > 0')

      if [[ "$already_approved" == "true" ]]; then
        continue
      fi
    fi

    # Output result
    if [[ "$MATCHED" -eq 1 ]]; then
      echo
      echo "- [$PR_TITLE]($PR_URL) ($REPO#$PR_NUM)"
    fi
  done < <(
    gh api --paginate "repos/$REPO/pulls?state=open&per_page=100" |
      jq -r --arg cutoff "$CUTOFF_DATE" --arg repo "$REPO" '
      .[] |
      select(.created_at >= $cutoff) |
      {
        number: .number,
        title: .title,
        html_url: .html_url,
        reviewers: [.requested_reviewers[]?.login],
        teams: [.requested_teams[]?.slug]
      } | @base64'
  )

done
