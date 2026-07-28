#!/bin/bash
# =============================================================================
# Script: 01-setup-security-groups.sh
# Phase 4 - Task 4.1: Open ports 8080 and 8081 on the Cloud9 security group.
# Run this from CloudShell or any machine with AWS CLI configured.
# =============================================================================

set -e

AWS_REGION="us-east-1"

echo "======================================================"
echo " Phase 4 - Task 4.1: Security Group Setup"
echo "======================================================"

# Find the Cloud9 environment ID
echo "[*] Looking for MicroservicesIDE Cloud9 environment..."
ENV_ID=$(aws cloud9 list-environments \
  --region "$AWS_REGION" \
  --query 'environmentIds[0]' \
  --output text)

if [ -z "$ENV_ID" ] || [ "$ENV_ID" == "None" ]; then
  echo "[-] ERROR: No Cloud9 environments found. Deploy phase3-infrastructure.yaml first."
  exit 1
fi

# Verify it's MicroservicesIDE
ENV_NAME=$(aws cloud9 describe-environments \
  --environment-ids "$ENV_ID" \
  --region "$AWS_REGION" \
  --query 'environments[0].name' \
  --output text)

echo "[+] Found environment: $ENV_NAME (ID: $ENV_ID)"

# Find the EC2 instance for this Cloud9 environment
echo "[*] Looking for associated EC2 instance..."
INSTANCE_ID=$(aws ec2 describe-instances \
  --region "$AWS_REGION" \
  --filters "Name=tag:aws:cloud9:environment,Values=$ENV_ID" \
            "Name=instance-state-name,Values=running" \
  --query 'Reservations[0].Instances[0].InstanceId' \
  --output text)

if [ -z "$INSTANCE_ID" ] || [ "$INSTANCE_ID" == "None" ]; then
  echo "[-] ERROR: Could not find running EC2 instance for MicroservicesIDE."
  exit 1
fi

echo "[+] Found EC2 instance: $INSTANCE_ID"

# Get the security group ID
SG_ID=$(aws ec2 describe-instances \
  --instance-ids "$INSTANCE_ID" \
  --region "$AWS_REGION" \
  --query 'Reservations[0].Instances[0].SecurityGroups[0].GroupId' \
  --output text)

echo "[+] Security Group: $SG_ID"

# Add port 8080 (ignore error if rule already exists)
echo "[*] Adding inbound rule for port 8080..."
aws ec2 authorize-security-group-ingress \
  --group-id "$SG_ID" \
  --protocol tcp \
  --port 8080 \
  --cidr 0.0.0.0/0 \
  --region "$AWS_REGION" 2>/dev/null && echo "[+] Port 8080 rule added." || echo "[~] Port 8080 rule already exists."

# Add port 8081
echo "[*] Adding inbound rule for port 8081..."
aws ec2 authorize-security-group-ingress \
  --group-id "$SG_ID" \
  --protocol tcp \
  --port 8081 \
  --cidr 0.0.0.0/0 \
  --region "$AWS_REGION" 2>/dev/null && echo "[+] Port 8081 rule added." || echo "[~] Port 8081 rule already exists."

echo ""
echo "[+] DONE. Ports 8080 and 8081 are now open on $SG_ID."
echo "======================================================"
