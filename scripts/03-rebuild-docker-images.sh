#!/bin/bash
# =============================================================================
# Script: 03-rebuild-docker-images.sh
# Phase 4 - Rebuild and run customer + employee Docker containers on Cloud9.
# Run this on Cloud9 if containers are lost (e.g., after environment restart).
#
# Prerequisites:
#   - Code already pushed to CodeCommit (Task 4.7)
#   - Git credentials configured on Cloud9
#   - RDS endpoint accessible from Cloud9
#
# Usage: bash 03-rebuild-docker-images.sh
# =============================================================================

set -e

AWS_REGION="us-east-1"
CODECOMMIT_REPO="microservices"
WORK_DIR="$HOME/environment/microservices"

echo "======================================================"
echo " Phase 4 - Rebuild Docker Images on Cloud9"
echo "======================================================"

# Get RDS endpoint from CodeCommit source (customer config)
echo "[*] Detecting RDS endpoint..."
if [ -f "$WORK_DIR/customer/app/config/config.js" ]; then
  DB_ENDPOINT=$(grep 'APP_DB_HOST' "$WORK_DIR/customer/app/config/config.js" | cut -d '"' -f2)
  echo "[+] DB endpoint: $DB_ENDPOINT"
else
  echo "[-] ERROR: Config file not found. Clone from CodeCommit first:"
  CLONE_URL=$(aws codecommit get-repository \
    --repository-name "$CODECOMMIT_REPO" \
    --region "$AWS_REGION" \
    --query 'repositoryMetadata.cloneUrlHttp' \
    --output text)
  echo "    git clone $CLONE_URL $WORK_DIR"
  exit 1
fi

# ---- CUSTOMER microservice ----
echo ""
echo "[*] Building customer Docker image..."
cd "$WORK_DIR/customer"
docker build --tag customer .
echo "[+] customer image built."

# Stop and remove existing container if running
docker stop customer_1 2>/dev/null && docker rm customer_1 2>/dev/null || true

echo "[*] Starting customer_1 container on port 8080..."
docker run -d \
  --name customer_1 \
  -p 8080:8080 \
  -e APP_DB_HOST="$DB_ENDPOINT" \
  customer
echo "[+] customer_1 running."

# ---- EMPLOYEE microservice ----
echo ""
echo "[*] Building employee Docker image..."
cd "$WORK_DIR/employee"
docker build --tag employee .
echo "[+] employee image built."

# Stop and remove existing container if running
docker stop employee_1 2>/dev/null && docker rm employee_1 2>/dev/null || true

echo "[*] Starting employee_1 container on port 8081..."
docker run -d \
  --name employee_1 \
  -p 8081:8080 \
  -e APP_DB_HOST="$DB_ENDPOINT" \
  employee
echo "[+] employee_1 running."

# ---- Summary ----
echo ""
echo "[*] Running containers:"
docker ps --format "table {{.Names}}\t{{.Image}}\t{{.Ports}}\t{{.Status}}"

# Get public IP
TOKEN=$(curl -s -X PUT "http://169.254.169.254/latest/api/token" \
  -H "X-aws-ec2-metadata-token-ttl-seconds: 21600")
PUBLIC_IP=$(curl -s -H "X-aws-ec2-metadata-token: $TOKEN" \
  http://169.254.169.254/latest/meta-data/public-ipv4)

echo ""
echo "[+] DONE. Test the microservices:"
echo "    Customer:  http://$PUBLIC_IP:8080"
echo "    Employee:  http://$PUBLIC_IP:8081/admin/suppliers/"
echo "======================================================"
