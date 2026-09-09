#!/usr/bin/env bash
# Fetches all unresolved inline review threads for the PR on the current branch.
# Outputs JSON array of threads with: id, path, line, startLine, isOutdated, and comments.
set -euo pipefail

OWNER=$(gh repo view --json owner -q .owner.login)
REPO=$(gh repo view --json name -q .name)
PR=$(gh pr view --json number -q .number)

# $endCursor plus the pageInfo block are what let `gh api graphql --paginate` walk
# every page. Without them only the first 100 threads are returned, which silently
# hides unresolved threads on PRs with more than 100 threads.
QUERY='query($owner: String!, $repo: String!, $pr: Int!, $endCursor: String) {
  repository(owner: $owner, name: $repo) {
    pullRequest(number: $pr) {
      reviewThreads(first: 100, after: $endCursor) {
        pageInfo {
          hasNextPage
          endCursor
        }
        nodes {
          id
          isResolved
          isOutdated
          path
          line
          startLine
          comments(first: 100) {
            nodes {
              author { login }
              body
              url
            }
          }
        }
      }
    }
  }
}'

# --jq runs once per page and emits one thread per line, so `jq -s` collects the
# results from all pages back into the single JSON array this script promises.
gh api graphql --paginate -f query="$QUERY" -f owner="$OWNER" -f repo="$REPO" -F pr="$PR" \
  --jq '.data.repository.pullRequest.reviewThreads.nodes[] | select(.isResolved == false)' \
  | jq -s '.'
