#!/bin/bash

# Check if commit message is provided (everything after the command)
if [ -z "$*" ]; then
    echo "Error: Commit message is required"
    echo "Usage: ./git_push.sh <your commit message>"
    exit 1
fi

COMMIT_MESSAGE="$*"

# Add all changes
echo "Adding all changes..."
git add .

# Check if there are changes to commit
if git diff --cached --quiet; then
    echo "No changes to commit"
    exit 0
fi

# Commit changes
echo "Committing changes..."
git commit -m "$COMMIT_MESSAGE"

# Get current branch name
CURRENT_BRANCH=$(git rev-parse --abbrev-ref HEAD)
echo "Current branch: $CURRENT_BRANCH"

# Check if upstream is set
if git rev-parse --abbrev-ref --symbolic-full-name @{u} > /dev/null 2>&1; then
    # Upstream exists, just push
    echo "Pushing to $CURRENT_BRANCH..."
    git push
else
    # No upstream, set it up and push
    echo "Setting up upstream and pushing to $CURRENT_BRANCH..."
    git push -u origin "$CURRENT_BRANCH"
fi

echo "Done!"
