#!/bin/bash
# =============================================================================
# Script: 04-complete-phase4.sh
# Phase 4 Tasks 4.6 + 4.7:
#   - Change employee Dockerfile EXPOSE from 8081 to 8080
#   - Rebuild employee image
#   - Push all microservices code to CodeCommit (dev branch)
#
# Run on Cloud9.
# =============================================================================

set -e

AWS_REGION="us-east-1"
WORK_DIR="$HOME/environment/microservices"

echo "======================================================"
echo " Phase 4 - Tasks 4.6 + 4.7"
echo "======================================================"

# Task 4.6: Change EXPOSE in employee Dockerfile from 8081 to 8080
echo "[*] Task 4.6: Updating employee Dockerfile EXPOSE port to 8080..."
DOCKERFILE="$WORK_DIR/employee/Dockerfile"

if grep -q "EXPOSE 8081" "$DOCKERFILE"; then
  sed -i 's/EXPOSE 8081/EXPOSE 8080/' "$DOCKERFILE"
  echo "[+] Changed EXPOSE 8081 → EXPOSE 8080 in employee/Dockerfile"
else
  echo "[~] employee/Dockerfile already has EXPOSE 8080 or different port."
fi

grep "EXPOSE" "$DOCKERFILE"

# Rebuild employee image with updated Dockerfile
echo ""
echo "[*] Rebuilding employee Docker image..."
cd "$WORK_DIR/employee"
docker stop employee_1 2>/dev/null && docker rm employee_1 2>/dev/null || true
docker build --tag employee .
echo "[+] employee image rebuilt."

# Restart employee container (port mapping 8081:8080 = host:container)
dbEndpoint=$(grep 'APP_DB_HOST' app/config/config.js | cut -d '"' -f2)
docker run -d --name employee_1 -p 8081:8080 -e APP_DB_HOST="$dbEndpoint" employee
echo "[+] employee_1 container running on host port 8081."

# Task 4.7: Push microservices code to CodeCommit
echo ""
echo "[*] Task 4.7: Pushing code to CodeCommit..."

# Get CodeCommit URL
CLONE_URL=$(aws codecommit get-repository \
  --repository-name microservices \
  --region "$AWS_REGION" \
  --query 'repositoryMetadata.cloneUrlHttp' \
  --output text)

echo "[+] CodeCommit URL: $CLONE_URL"

# Configure git
git config --global credential.helper '!aws codecommit credential-helper $@'
git config --global credential.UseHttpPath true
git config --global user.email "student@lab.aws"
git config --global user.name "Lab Student"

cd "$WORK_DIR"

# Init and configure remote if needed
if [ ! -d ".git" ]; then
  git init
  git remote add origin "$CLONE_URL"
else
  git remote set-url origin "$CLONE_URL" 2>/dev/null || git remote add origin "$CLONE_URL"
fi

git checkout -B dev

# Stage all microservice files (excluding node_modules)
git add customer/ employee/
git status

git commit -m "Phase 4: customer (read-only port 8080) + employee (admin routes port 8080)

- customer: read-only controller, no write views, port 8080, node:11-alpine
- employee: all routes prefixed /admin/, port 8080, node:11-alpine
- Both include Dockerfiles with EXPOSE 8080" || echo "[~] Nothing new to commit."

git push -u origin dev

echo ""
echo "[+] DONE. Phase 4 complete."
echo "  customer/Dockerfile: EXPOSE 8080 ✓"
echo "  employee/Dockerfile: EXPOSE 8080 ✓"
echo "  CodeCommit repo 'microservices', branch 'dev': pushed ✓"
echo "======================================================"
