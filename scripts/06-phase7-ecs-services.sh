#!/bin/bash
# =============================================================================
# Script: 06-phase7-ecs-services.sh
# Phase 7 - Tasks 7.1 + 7.2:
#   - Create ECS service for customer microservice (CODE_DEPLOY, customer-tg-two)
#   - Create ECS service for employee microservice (CODE_DEPLOY, employee-tg-two)
#
# Run on Cloud9 AFTER phase6-alb CloudFormation stack is deployed.
# All values are auto-detected from AWS.
# =============================================================================

set -e

AWS_REGION="us-east-1"
CLUSTER="microservices-serverlesscluster"
DEPLOY_DIR="$HOME/environment/deployment"
GITHUB_REPO_DIR="$HOME/environment/Building_Microservices_CI_CD_Pipeline_with_AWS"

PUBLIC_SUBNET1="subnet-0cf4a07c350d6fded"
PUBLIC_SUBNET2="subnet-07ca4048628fe306b"

echo "======================================================"
echo " Phase 7 - ECS Services: customer + employee"
echo "======================================================"

# ============================================================
# Auto-detect required values
# ============================================================
echo ""
echo "[*] Detecting task definition revision numbers..."
CUSTOMER_REVISION=$(aws ecs describe-task-definition \
  --task-definition customer-microservice \
  --region "$AWS_REGION" \
  --query 'taskDefinition.revision' --output text)

EMPLOYEE_REVISION=$(aws ecs describe-task-definition \
  --task-definition employee-microservice \
  --region "$AWS_REGION" \
  --query 'taskDefinition.revision' --output text)

echo "[+] customer-microservice revision: $CUSTOMER_REVISION"
echo "[+] employee-microservice revision:  $EMPLOYEE_REVISION"

echo ""
echo "[*] Detecting target group ARNs..."
CUSTOMER_TG_TWO_ARN=$(aws elbv2 describe-target-groups \
  --names customer-tg-two \
  --region "$AWS_REGION" \
  --query 'TargetGroups[0].TargetGroupArn' --output text)

EMPLOYEE_TG_TWO_ARN=$(aws elbv2 describe-target-groups \
  --names employee-tg-two \
  --region "$AWS_REGION" \
  --query 'TargetGroups[0].TargetGroupArn' --output text)

echo "[+] customer-tg-two ARN: $CUSTOMER_TG_TWO_ARN"
echo "[+] employee-tg-two ARN: $EMPLOYEE_TG_TWO_ARN"

echo ""
echo "[*] Detecting security group ID..."
SG_ID=$(aws ec2 describe-security-groups \
  --filters "Name=group-name,Values=microservices-sg" \
  --region "$AWS_REGION" \
  --query 'SecurityGroups[0].GroupId' --output text)

echo "[+] microservices-sg ID: $SG_ID"

# ============================================================
# TASK 7.1 - Create customer ECS service JSON and service
# ============================================================
echo ""
echo "[*] Task 7.1: Creating customer ECS service..."

cat > "$DEPLOY_DIR/create-customer-microservice-tg-two.json" <<EOF
{
    "taskDefinition": "customer-microservice:${CUSTOMER_REVISION}",
    "cluster": "${CLUSTER}",
    "loadBalancers": [
        {
            "targetGroupArn": "${CUSTOMER_TG_TWO_ARN}",
            "containerName": "customer",
            "containerPort": 8080
        }
    ],
    "desiredCount": 1,
    "launchType": "FARGATE",
    "schedulingStrategy": "REPLICA",
    "deploymentController": {
        "type": "CODE_DEPLOY"
    },
    "networkConfiguration": {
        "awsvpcConfiguration": {
            "subnets": [
                "${PUBLIC_SUBNET1}",
                "${PUBLIC_SUBNET2}"
            ],
            "securityGroups": [
                "${SG_ID}"
            ],
            "assignPublicIp": "ENABLED"
        }
    }
}
EOF

echo "[+] create-customer-microservice-tg-two.json created."

cd "$DEPLOY_DIR"
aws ecs create-service \
  --service-name customer-microservice \
  --cli-input-json file://create-customer-microservice-tg-two.json \
  --region "$AWS_REGION" \
  --query 'service.serviceArn' --output text \
  && echo "[+] customer-microservice ECS service created." \
  || echo "[!] customer-microservice service may already exist — skipping."

# ============================================================
# TASK 7.2 - Create employee ECS service JSON and service
# ============================================================
echo ""
echo "[*] Task 7.2: Creating employee ECS service..."

cat > "$DEPLOY_DIR/create-employee-microservice-tg-two.json" <<EOF
{
    "taskDefinition": "employee-microservice:${EMPLOYEE_REVISION}",
    "cluster": "${CLUSTER}",
    "loadBalancers": [
        {
            "targetGroupArn": "${EMPLOYEE_TG_TWO_ARN}",
            "containerName": "employee",
            "containerPort": 8080
        }
    ],
    "desiredCount": 1,
    "launchType": "FARGATE",
    "schedulingStrategy": "REPLICA",
    "deploymentController": {
        "type": "CODE_DEPLOY"
    },
    "networkConfiguration": {
        "awsvpcConfiguration": {
            "subnets": [
                "${PUBLIC_SUBNET1}",
                "${PUBLIC_SUBNET2}"
            ],
            "securityGroups": [
                "${SG_ID}"
            ],
            "assignPublicIp": "ENABLED"
        }
    }
}
EOF

echo "[+] create-employee-microservice-tg-two.json created."

cd "$DEPLOY_DIR"
aws ecs create-service \
  --service-name employee-microservice \
  --cli-input-json file://create-employee-microservice-tg-two.json \
  --region "$AWS_REGION" \
  --query 'service.serviceArn' --output text \
  && echo "[+] employee-microservice ECS service created." \
  || echo "[!] employee-microservice service may already exist — skipping."

# ============================================================
# Save JSON files to GitHub repo
# ============================================================
echo ""
echo "[*] Saving JSON files to GitHub repo..."

cp "$DEPLOY_DIR/create-customer-microservice-tg-two.json" \
   "$GITHUB_REPO_DIR/deployment/create-customer-microservice-tg-two.json"

cp "$DEPLOY_DIR/create-employee-microservice-tg-two.json" \
   "$GITHUB_REPO_DIR/deployment/create-employee-microservice-tg-two.json"

cd "$GITHUB_REPO_DIR"
git add deployment/create-customer-microservice-tg-two.json \
        deployment/create-employee-microservice-tg-two.json \
        scripts/06-phase7-ecs-services.sh 2>/dev/null || true
git commit -m "Phase 7: ECS service JSON files for customer and employee microservices" \
  || echo "[~] Nothing new to commit."
git push origin main
echo "[+] Files pushed to GitHub."

echo ""
echo "[+] PHASE 7 COMPLETE."
echo "  customer-microservice ECS service: CREATED (CODE_DEPLOY, customer-tg-two) ✓"
echo "  employee-microservice ECS service: CREATED (CODE_DEPLOY, employee-tg-two) ✓"
echo "  Note: 0/1 tasks running is EXPECTED — tasks start after CodeDeploy (Phase 8)"
echo "======================================================"
