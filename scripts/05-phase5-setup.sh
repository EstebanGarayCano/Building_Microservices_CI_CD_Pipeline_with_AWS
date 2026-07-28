#!/bin/bash
# =============================================================================
# Script: 05-phase5-setup.sh
# Phase 5 - Tasks 5.1, 5.3, 5.4, 5.5, 5.6:
#   5.1 - Create ECR repos, set permissions, tag and push Docker images
#   5.3 - Init deployment directory as git repo
#   5.4 - Create and register ECS task definitions
#   5.5 - Create AppSpec files for CodeDeploy
#   5.6 - Update taskdef files with IMAGE1_NAME placeholder, push to CodeCommit
#
# Run on Cloud9 AFTER phase5-ecs-cluster.yaml CloudFormation stack is deployed.
# =============================================================================

set -e

AWS_REGION="us-east-1"
WORK_DIR="$HOME/environment"
DEPLOY_DIR="$WORK_DIR/deployment"
MICROSERVICES_DIR="$WORK_DIR/microservices"

# Auto-detect account ID and RDS endpoint
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
DB_HOST=$(grep 'APP_DB_HOST' "$MICROSERVICES_DIR/customer/app/config/config.js" | cut -d '"' -f2)
ECR_BASE="$ACCOUNT_ID.dkr.ecr.$AWS_REGION.amazonaws.com"

echo "======================================================"
echo " Phase 5 - ECR + Task Definitions + AppSpec + Deploy"
echo " Account ID : $ACCOUNT_ID"
echo " ECR Base   : $ECR_BASE"
echo " DB Host    : $DB_HOST"
echo "======================================================"

# ============================================================
# TASK 5.1 - ECR repos, permissions, tag and push images
# ============================================================
echo ""
echo "[*] Task 5.1: Creating ECR repositories..."

for REPO in customer employee; do
  aws ecr create-repository --repository-name "$REPO" --region "$AWS_REGION" 2>/dev/null \
    && echo "[+] Created ECR repo: $REPO" \
    || echo "[~] ECR repo '$REPO' already exists."

  aws ecr set-repository-policy \
    --repository-name "$REPO" \
    --region "$AWS_REGION" \
    --policy-text '{
      "Version": "2008-10-17",
      "Statement": [{"Effect": "Allow","Principal": "*","Action": "ecr:*"}]
    }' > /dev/null
  echo "[+] Permissions set on: $REPO"
done

echo "[*] Logging in to ECR..."
aws ecr get-login-password --region "$AWS_REGION" | \
  docker login --username AWS --password-stdin "$ECR_BASE"

echo "[*] Tagging images..."
docker tag customer:latest "$ECR_BASE/customer:latest"
docker tag employee:latest "$ECR_BASE/employee:latest"

echo "[*] Pushing customer image to ECR..."
docker push "$ECR_BASE/customer:latest"

echo "[*] Pushing employee image to ECR..."
docker push "$ECR_BASE/employee:latest"

echo "[+] Task 5.1 complete. Images pushed to ECR."

# ============================================================
# TASK 5.3 - Create deployment directory and init git
# ============================================================
echo ""
echo "[*] Task 5.3: Setting up deployment directory..."

mkdir -p "$DEPLOY_DIR"
cd "$DEPLOY_DIR"

DEPLOY_CLONE_URL=$(aws codecommit get-repository \
  --repository-name deployment \
  --region "$AWS_REGION" \
  --query 'repositoryMetadata.cloneUrlHttp' \
  --output text)

git config --global credential.helper '!aws codecommit credential-helper $@'
git config --global credential.UseHttpPath true
git config --global user.email "student@lab.aws"
git config --global user.name "Lab Student"

if [ ! -d ".git" ]; then
  git init
  git remote add origin "$DEPLOY_CLONE_URL"
else
  git remote set-url origin "$DEPLOY_CLONE_URL" 2>/dev/null || true
fi

git checkout -B dev
echo "[+] Task 5.3 complete. Deployment repo initialized."

# ============================================================
# TASK 5.4 - Create task definitions with real image URIs
# ============================================================
echo ""
echo "[*] Task 5.4: Creating task definition files (with real ECR URIs)..."

cat > "$DEPLOY_DIR/taskdef-customer.json" <<EOF
{
    "containerDefinitions": [
        {
            "name": "customer",
            "image": "$ECR_BASE/customer:latest",
            "environment": [
                {
                    "name": "APP_DB_HOST",
                    "value": "$DB_HOST"
                }
            ],
            "essential": true,
            "portMappings": [
                {
                    "hostPort": 8080,
                    "protocol": "tcp",
                    "containerPort": 8080
                }
            ],
            "logConfiguration": {
                "logDriver": "awslogs",
                "options": {
                    "awslogs-create-group": "true",
                    "awslogs-group": "awslogs-capstone",
                    "awslogs-region": "us-east-1",
                    "awslogs-stream-prefix": "awslogs-capstone"
                }
            }
        }
    ],
    "requiresCompatibilities": ["FARGATE"],
    "networkMode": "awsvpc",
    "cpu": "512",
    "memory": "1024",
    "executionRoleArn": "arn:aws:iam::$ACCOUNT_ID:role/PipelineRole",
    "family": "customer-microservice"
}
EOF

cat > "$DEPLOY_DIR/taskdef-employee.json" <<EOF
{
    "containerDefinitions": [
        {
            "name": "employee",
            "image": "$ECR_BASE/employee:latest",
            "environment": [
                {
                    "name": "APP_DB_HOST",
                    "value": "$DB_HOST"
                }
            ],
            "essential": true,
            "portMappings": [
                {
                    "hostPort": 8080,
                    "protocol": "tcp",
                    "containerPort": 8080
                }
            ],
            "logConfiguration": {
                "logDriver": "awslogs",
                "options": {
                    "awslogs-create-group": "true",
                    "awslogs-group": "awslogs-capstone",
                    "awslogs-region": "us-east-1",
                    "awslogs-stream-prefix": "awslogs-capstone"
                }
            }
        }
    ],
    "requiresCompatibilities": ["FARGATE"],
    "networkMode": "awsvpc",
    "cpu": "512",
    "memory": "1024",
    "executionRoleArn": "arn:aws:iam::$ACCOUNT_ID:role/PipelineRole",
    "family": "employee-microservice"
}
EOF

echo "[*] Registering customer-microservice task definition..."
aws ecs register-task-definition \
  --cli-input-json "file://$DEPLOY_DIR/taskdef-customer.json" \
  --region "$AWS_REGION" \
  --query 'taskDefinition.taskDefinitionArn' --output text

echo "[*] Registering employee-microservice task definition..."
aws ecs register-task-definition \
  --cli-input-json "file://$DEPLOY_DIR/taskdef-employee.json" \
  --region "$AWS_REGION" \
  --query 'taskDefinition.taskDefinitionArn' --output text

echo "[+] Task 5.4 complete. Task definitions registered."

# ============================================================
# TASK 5.5 - Create AppSpec files
# ============================================================
echo ""
echo "[*] Task 5.5: Creating AppSpec files..."

cat > "$DEPLOY_DIR/appspec-customer.yaml" <<'EOF'
version: 0.0
Resources:
  - TargetService:
      Type: AWS::ECS::Service
      Properties:
        TaskDefinition: <TASK_DEFINITION>
        LoadBalancerInfo:
          ContainerName: "customer"
          ContainerPort: 8080
EOF

cat > "$DEPLOY_DIR/appspec-employee.yaml" <<'EOF'
version: 0.0
Resources:
  - TargetService:
      Type: AWS::ECS::Service
      Properties:
        TaskDefinition: <TASK_DEFINITION>
        LoadBalancerInfo:
          ContainerName: "employee"
          ContainerPort: 8080
EOF

echo "[+] Task 5.5 complete. AppSpec files created."

# ============================================================
# TASK 5.6 - Replace image URIs with IMAGE1_NAME placeholder
# ============================================================
echo ""
echo "[*] Task 5.6: Updating taskdef files with <IMAGE1_NAME> placeholder..."

sed -i "s|\"$ECR_BASE/customer:latest\"|\"<IMAGE1_NAME>\"|g" "$DEPLOY_DIR/taskdef-customer.json"
sed -i "s|\"$ECR_BASE/employee:latest\"|\"<IMAGE1_NAME>\"|g" "$DEPLOY_DIR/taskdef-employee.json"

echo "[+] Placeholders set. Pushing all 4 files to CodeCommit deployment repo..."

cd "$DEPLOY_DIR"
git add taskdef-customer.json taskdef-employee.json appspec-customer.yaml appspec-employee.yaml
git commit -m "Phase 5: task definitions and AppSpec files for customer and employee microservices"
git push -u origin dev

echo ""
echo "[+] PHASE 5 SETUP COMPLETE."
echo "  ECR repos created and images pushed ✓"
echo "  Task definitions registered in ECS ✓"
echo "  AppSpec files created ✓"
echo "  All files pushed to CodeCommit deployment/dev ✓"
echo ""
echo "  Next: Deploy phase5-ecs-cluster.yaml CloudFormation stack (Task 5.2)"
echo "======================================================"
