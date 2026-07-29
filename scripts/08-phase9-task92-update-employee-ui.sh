#!/bin/bash
# =============================================================================
# Script: 08-phase9-task92-update-employee-ui.sh
# Phase 9 - Task 9.2:
#   1. Change navbar-dark bg-dark → navbar-light bg-light in employee nav.html
#   2. Rebuild employee Docker image
#   3. Tag and push updated image to ECR
#      (pushing triggers the update-employee-microservice pipeline automatically)
#
# Run on Cloud9.
# =============================================================================

set -e

AWS_REGION="us-east-1"
EMPLOYEE_DIR="$HOME/environment/microservices/employee"

echo "======================================================"
echo " Phase 9 - Task 9.2: Update employee UI + Push to ECR"
echo "======================================================"

# ============================================================
# Step 1: Edit nav.html - change navbar color
# ============================================================
echo ""
echo "[*] Step 1: Updating employee nav.html..."

NAV_FILE="$EMPLOYEE_DIR/views/nav.html"

if grep -q "navbar-dark bg-dark" "$NAV_FILE"; then
  sed -i 's/navbar-dark bg-dark/navbar-light bg-light/g' "$NAV_FILE"
  echo "[+] Changed navbar-dark bg-dark → navbar-light bg-light"
else
  echo "[~] navbar-dark bg-dark not found — already changed or different value."
fi

echo "[+] Line 1 of nav.html:"
head -1 "$NAV_FILE"

# ============================================================
# Step 2: Remove old container and rebuild Docker image
# ============================================================
echo ""
echo "[*] Step 2: Rebuilding employee Docker image..."

docker rm -f employee_1 2>/dev/null && echo "[+] Removed old employee_1 container." \
  || echo "[~] employee_1 container not running."

cd "$EMPLOYEE_DIR"
docker build --tag employee .
echo "[+] employee Docker image rebuilt."

# ============================================================
# Step 3: Tag image with ECR URI
# ============================================================
echo ""
echo "[*] Step 3: Tagging image for ECR..."

ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
ECR_URI="$ACCOUNT_ID.dkr.ecr.$AWS_REGION.amazonaws.com/employee:latest"

echo "[+] Account ID : $ACCOUNT_ID"
echo "[+] ECR URI    : $ECR_URI"

docker tag employee:latest "$ECR_URI"
echo "[+] Image tagged."

# ============================================================
# Step 4: Login to ECR and push image
# ============================================================
echo ""
echo "[*] Step 4: Pushing image to ECR..."

aws ecr get-login-password --region "$AWS_REGION" | \
  docker login --username AWS --password-stdin "$ACCOUNT_ID.dkr.ecr.$AWS_REGION.amazonaws.com"

docker push "$ECR_URI"

echo ""
echo "[+] TASK 9.2 COMPLETE."
echo "  nav.html updated: navbar-light bg-light ✓"
echo "  Docker image rebuilt ✓"
echo "  Image pushed to ECR: $ECR_URI ✓"
echo ""
echo "  The update-employee-microservice pipeline will now trigger automatically."
echo "  Monitor it with:"
echo "  aws codepipeline get-pipeline-state --name update-employee-microservice --region us-east-1"
echo "======================================================"
