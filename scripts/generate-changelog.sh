#!/bin/bash

CENTRAL_REPO="/home/okayjosh/Documents/antigravity/fervent-darwin/website"
CHANGELOGS_DIR="$CENTRAL_REPO/changelogs"

# ===== CONFIG =====
if [ -z "$1" ]; then
  COUNT=$(python3 -c "import json, os; print(len(json.load(open('$CHANGELOGS_DIR/index.json')))) if os.path.exists('$CHANGELOGS_DIR/index.json') else print(0)" 2>/dev/null || echo "0")
  NEXT_ID=$((COUNT + 1))
  JIRA_TICKET="Deploy-$NEXT_ID"
else
  JIRA_TICKET="$1"
fi

BRANCH_NAME=$(git rev-parse --abbrev-ref HEAD 2>/dev/null)

if [ -z "$BRANCH_NAME" ]; then
  echo "Error: Not currently in a git repository."
  exit 1
fi

BASE_BRANCH="main"
if ! git rev-parse --verify origin/main >/dev/null 2>&1; then
  if git rev-parse --verify origin/master >/dev/null 2>&1; then
    BASE_BRANCH="master"
  fi
fi

DATE_STR=$(date +'%Y-%m-%d')
TIME_STR=$(date +'%H-%M')
DOC_FILENAME="Deployment_${JIRA_TICKET}_${DATE_STR}_${TIME_STR}.md"
LOCAL_DOC_FILE="$PWD/$DOC_FILENAME"

# Ensure the central repo exists
if [ ! -d "$CENTRAL_REPO/.git" ]; then
  echo "Error: Central repository not found at $CENTRAL_REPO"
  echo "Please check if it is a valid git repository."
  exit 1
fi

# Ensure changelogs dir exists in central repo
mkdir -p "$CHANGELOGS_DIR"

# ===== FETCH & PREPARE DIFF =====
echo "Fetching origin/$BASE_BRANCH..."
git fetch origin $BASE_BRANCH
DIFF_CONTENT=$(git diff origin/$BASE_BRANCH...HEAD)

# ===== BUILD PROMPT =====
PROMPT=$(cat <<EOF
You are an expert software architect and documentation generator.
Using the Git diff below between branch '$BRANCH_NAME' and $BASE_BRANCH, generate a comprehensive Markdown engineering change log in the following format. 

# {Feature / Fix Title}
**Tracking Ticket:** {ticket link if in commits or branch name}
**Reporter:** {commit author or blank if unknown}
**Department:** Tech
**Prod branch:** $BRANCH_NAME
**Staging branch:** ${BRANCH_NAME}-staging
**Deployment status:** QA

## Keywords
{comma-separated keywords from diff and branch name}

## Summary
{plain English description of change}

## Architecture Decision Record (ADR)
{Include a brief ADR based on the changes. Outline the Context (why the change was made), the Decision (what was implemented), and the Consequences (impact of this change).}

## System Flow (Mermaid Diagram)
{Generate a Mermaid block diagram representing the architectural flow, component interaction, or data flow changed in this update. Use a \`\`\`mermaid block.}

## Thought Process
{step-by-step reasoning for the change}

## Files Changed
NOTE: The following lines of code were added/removed/modified.

| File Directory | Line number | Function / Class | Notes |
| --- | --- | --- | --- |
| {file_path} | {line_numbers} | {function_or_class} | {brief note} |

## How To Test
{steps}

## Expected Criteria
{expected outcomes}

## How to Roll Back
{rollback method}

--- Git Diff ---
$DIFF_CONTENT
EOF
)

# ===== WRITE DOCUMENT HEADER LOCALLY =====
echo "# Deployment Summary: $JIRA_TICKET" > "$LOCAL_DOC_FILE"
echo "**Branch:** $BRANCH_NAME" >> "$LOCAL_DOC_FILE"
echo "**Base Branch:** $BASE_BRANCH" >> "$LOCAL_DOC_FILE"
echo "**Date:** $(date +'%d %B %Y')" >> "$LOCAL_DOC_FILE"

# ===== ADD PROMPT SECTION =====
echo -e "\n## ChatGPT Prompt for AI-Generated Change Log\n" >> "$LOCAL_DOC_FILE"
echo '```' >> "$LOCAL_DOC_FILE"
echo "$PROMPT" >> "$LOCAL_DOC_FILE"
echo '```' >> "$LOCAL_DOC_FILE"

# ===== ADD FILE-BY-FILE DIFF =====
echo -e "\n## Code Changes" >> "$LOCAL_DOC_FILE"
git diff $BASE_BRANCH --name-only | while read -r file; do
  changes=$(git diff $BASE_BRANCH --shortstat -- "$file" | awk '{print $1 " additions, " $2 " deletions"}')
  
  echo "### $file" >> "$LOCAL_DOC_FILE"
  echo "**Changes:** $changes" >> "$LOCAL_DOC_FILE"
  
  git diff $BASE_BRANCH --unified=0 -- "$file" | grep -o '@@ .* @@' | while read -r range; do
    clean_range=$(echo "$range" | sed 's/@@ //g; s/ @@//g')
    echo "- **Lines:** $clean_range" >> "$LOCAL_DOC_FILE"
  done
  
  echo '```diff' >> "$LOCAL_DOC_FILE"
  git diff $BASE_BRANCH -- "$file" | head -n 15 >> "$LOCAL_DOC_FILE"
  echo '```' >> "$LOCAL_DOC_FILE"
  echo "" >> "$LOCAL_DOC_FILE"
done

echo "✅ Local deployment document generated: $LOCAL_DOC_FILE"

# ===== COPY TO WEBSITE REPO =====
cp "$LOCAL_DOC_FILE" "$CHANGELOGS_DIR/$DOC_FILENAME"

# ===== UPDATE JSON INDEX IN WEBSITE REPO =====
INDEX_FILE="$CHANGELOGS_DIR/index.json"

# Check if index.json exists, create if not
if [ ! -f "$INDEX_FILE" ]; then
  echo "[]" > "$INDEX_FILE"
fi

# Use node or python to safely append to JSON. Here we use python since it's generally available.
python3 -c "
import json
import sys

index_file = sys.argv[1]
ticket = sys.argv[2]
date_str = sys.argv[3]
filename = sys.argv[4]

try:
    with open(index_file, 'r') as f:
        data = json.load(f)
except Exception:
    data = []

# Title can be derived later, for now just use Ticket ID
entry = {
    'id': ticket,
    'date': date_str,
    'file': 'changelogs/' + filename,
    'title': f'Deployment {ticket}'
}

# Insert at the beginning to maintain chronological order (newest first)
data.insert(0, entry)

with open(index_file, 'w') as f:
    json.dump(data, f, indent=2)
" "$INDEX_FILE" "$JIRA_TICKET" "$DATE_STR" "$DOC_FILENAME"

# ===== PUSH TO GITHUB =====
echo "Commiting and pushing to $CENTRAL_REPO..."
cd "$CENTRAL_REPO" || exit 1
git add "changelogs/$DOC_FILENAME" "changelogs/index.json"
git commit -m "docs: Add deployment log for $JIRA_TICKET" || true
WEBSITE_BRANCH=$(git rev-parse --abbrev-ref HEAD)
git push origin "$WEBSITE_BRANCH"

echo "✅ Deployment document copied to website and pushed to GitHub!"
