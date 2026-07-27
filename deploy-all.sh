#!/bin/bash
# ============================================================
# AWS Academy Microservices Lab - Master Deployment Script
# Run this from the Cloud9 terminal to recreate all infrastructure
# if the lab environment is reset.
# ============================================================
set -euo pipefail

REGION="us-east-1"
CF_DIR="$(dirname "$0")/cloudformation"

# -------------------------------------------------------
# FILL THESE VALUES before running
# -------------------------------------------------------
VPC_ID=""                   # e.g. vpc-0abc123
SUBNET1_ID=""               # PublicSubnet1 ID
SUBNET2_ID=""               # PublicSubnet2 ID
OWNER_ARN=""                # ARN of the Cloud9 owner (LabRole assumed-role ARN)
LAB_ROLE_ARN=""             # ARN of LabRole, used for ECS/CodeDeploy/CodePipeline
ARTIFACT_BUCKET=""          # S3 bucket name for pipeline artifacts (create manually)
CUSTOMER_TASK_DEF_ARN=""    # Filled after Phase 5 task definition registration
EMPLOYEE_TASK_DEF_ARN=""    # Filled after Phase 5 task definition registration

# -------------------------------------------------------
# Helper
# -------------------------------------------------------
deploy_stack() {
  local stack_name="$1"
  local template="$2"
  shift 2
  local params=("$@")

  echo ""
  echo "====> Deploying stack: $stack_name"
  aws cloudformation deploy \
    --region "$REGION" \
    --stack-name "$stack_name" \
    --template-file "$template" \
    --capabilities CAPABILITY_NAMED_IAM \
    --parameter-overrides "${params[@]}"
  echo "====> Stack $stack_name deployed successfully."
}

# -------------------------------------------------------
# Phase 3: Cloud9 + CodeCommit microservices repo
# -------------------------------------------------------
deploy_stack "lab-phase3" \
  "$CF_DIR/phase3-cloud9-codecommit.yaml" \
  "VpcId=$VPC_ID" \
  "PublicSubnet1Id=$SUBNET1_ID" \
  "OwnerArn=$OWNER_ARN"

# -------------------------------------------------------
# Phase 5: ECR + ECS cluster + CodeCommit deployment repo
# -------------------------------------------------------
deploy_stack "lab-phase5" \
  "$CF_DIR/phase5-ecr-ecs-codecommit.yaml" \
  "VpcId=$VPC_ID" \
  "PublicSubnet1Id=$SUBNET1_ID" \
  "PublicSubnet2Id=$SUBNET2_ID"

echo ""
echo "====> PAUSE: Complete Phase 4 and 5 manual steps now:"
echo "      1. Copy monolithic code to Cloud9 (scp)"
echo "      2. Modify customer and employee source code"
echo "      3. Build Docker images and push to ECR"
echo "      4. Register task definitions and AppSpec files in CodeCommit"
echo "      5. Fill CUSTOMER_TASK_DEF_ARN and EMPLOYEE_TASK_DEF_ARN above"
echo "      Then run this script again starting from Phase 6 (comment out phases above)."
echo ""
read -p "Press Enter when ready to continue with Phase 6..."

# -------------------------------------------------------
# Phase 6: ALB + target groups
# -------------------------------------------------------
deploy_stack "lab-phase6" \
  "$CF_DIR/phase6-alb-targetgroups.yaml" \
  "VpcId=$VPC_ID" \
  "PublicSubnet1Id=$SUBNET1_ID" \
  "PublicSubnet2Id=$SUBNET2_ID"

# -------------------------------------------------------
# Phase 7: ECS services
# -------------------------------------------------------
deploy_stack "lab-phase7" \
  "$CF_DIR/phase7-ecs-services.yaml" \
  "VpcId=$VPC_ID" \
  "PublicSubnet1Id=$SUBNET1_ID" \
  "PublicSubnet2Id=$SUBNET2_ID" \
  "CustomerTaskDefinitionArn=$CUSTOMER_TASK_DEF_ARN" \
  "EmployeeTaskDefinitionArn=$EMPLOYEE_TASK_DEF_ARN" \
  "ECSTaskExecutionRoleArn=$LAB_ROLE_ARN"

# -------------------------------------------------------
# Phase 8: CodeDeploy + CodePipeline
# -------------------------------------------------------
deploy_stack "lab-phase8" \
  "$CF_DIR/phase8-codedeploy-codepipeline.yaml" \
  "CodeDeployRoleArn=$LAB_ROLE_ARN" \
  "CodePipelineRoleArn=$LAB_ROLE_ARN" \
  "ECSTaskExecutionRoleArn=$LAB_ROLE_ARN" \
  "ArtifactBucketName=$ARTIFACT_BUCKET"

echo ""
echo "====> All stacks deployed successfully!"
echo "      ALB DNS: $(aws cloudformation list-exports --region $REGION \
        --query 'Exports[?Name==`MicroservicesALBDnsName`].Value' --output text)"
