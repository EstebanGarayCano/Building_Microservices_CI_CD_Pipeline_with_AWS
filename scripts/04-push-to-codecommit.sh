#!/bin/bash
# =============================================================================
# Script: 04-push-to-codecommit.sh
# Phase 4 - Task 4.7: Push microservices code to CodeCommit (dev branch).
# Run this on Cloud9 after all code changes are complete.
#
# Usage: bash 04-push-to-codecommit.sh
# =============================================================================

set -e

AWS_REGION="us-east-1"
REPO_NAME="microservices"
BRANCH="dev"
WORK_DIR="$HOME/environment/microservices"

echo "======================================================"
echo " Phase 4 - Task 4.7: Push to CodeCommit"
echo "======================================================"

# Get CodeCommit HTTPS clone URL
CLONE_URL=$(aws codecommit get-repository \
  --repository-name "$REPO_NAME" \
  --region "$AWS_REGION" \
  --query 'repositoryMetadata.cloneUrlHttp' \
  --output text)

echo "[+] CodeCommit URL: $CLONE_URL"

# Configure git credential helper for CodeCommit
git config --global credential.helper \
  '!aws codecommit credential-helper $@'
git config --global credential.UseHttpPath true
git config --global user.email "student@lab.aws"
git config --global user.name "Lab Student"

cd "$WORK_DIR"

# Initialize git if not already done
if [ ! -d ".git" ]; then
  echo "[*] Initializing git repository..."
  git init
  git remote add origin "$CLONE_URL"
else
  echo "[+] Git repository already initialized."
  # Update remote URL in case it changed
  git remote set-url origin "$CLONE_URL"
fi

# Checkout dev branch
git checkout -B "$BRANCH"

# Stage all changes
git add customer/ employee/
git status

# Commit
echo "[*] Committing changes..."
git commit -m "Phase 4: Split monolith into customer and employee microservices

- customer: read-only (findAll, findOne), port 8080
- employee: full CRUD with /admin/ route prefix, port 8080
- Both services include Dockerfiles using node:11-alpine" \
  || echo "[~] Nothing new to commit."

# Push to dev branch
echo "[*] Pushing to CodeCommit ($BRANCH branch)..."
git push -u origin "$BRANCH"

echo ""
echo "[+] DONE. Code pushed to CodeCommit repo '$REPO_NAME' on branch '$BRANCH'."
echo "======================================================"
