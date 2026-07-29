#!/bin/bash
# =============================================================================
# Script: 07-phase9-task91-ip-restriction.sh
# Phase 9 - Task 9.1:
#   Step 1: Restore listener 8080 to proper TG associations (customer-tg-one
#           as default, employee-tg-two for /admin/*) — CodeDeploy detached them
#   Step 2: Add source IP restriction to /admin/* rules on ports 80 and 8080
#
# Run from Mac with profile LabMicroservices.
# Update MY_IP if your public IP changes.
# =============================================================================

set -e

MY_IP="181.56.52.254"
AWS_REGION="us-east-1"
PROFILE="LabMicroservices"

echo "======================================================"
echo " Phase 9 - Task 9.1: Reassociate TGs + IP Restriction"
echo " Public IP : $MY_IP/32"
echo "======================================================"

# ============================================================
# Auto-detect ARNs
# ============================================================
echo ""
echo "[*] Detecting ARNs..."

ALB_ARN=$(aws elbv2 describe-load-balancers \
  --profile "$PROFILE" --names microservicesLB --region "$AWS_REGION" \
  --query 'LoadBalancers[0].LoadBalancerArn' --output text)

LISTENER_80_ARN=$(aws elbv2 describe-listeners \
  --profile "$PROFILE" --load-balancer-arn "$ALB_ARN" --region "$AWS_REGION" \
  --query 'Listeners[?Port==`80`].ListenerArn' --output text)

LISTENER_8080_ARN=$(aws elbv2 describe-listeners \
  --profile "$PROFILE" --load-balancer-arn "$ALB_ARN" --region "$AWS_REGION" \
  --query 'Listeners[?Port==`8080`].ListenerArn' --output text)

CUSTOMER_TG_ONE_ARN=$(aws elbv2 describe-target-groups \
  --profile "$PROFILE" --names customer-tg-one --region "$AWS_REGION" \
  --query 'TargetGroups[0].TargetGroupArn' --output text)

EMPLOYEE_TG_ONE_ARN=$(aws elbv2 describe-target-groups \
  --profile "$PROFILE" --names employee-tg-one --region "$AWS_REGION" \
  --query 'TargetGroups[0].TargetGroupArn' --output text)

EMPLOYEE_TG_TWO_ARN=$(aws elbv2 describe-target-groups \
  --profile "$PROFILE" --names employee-tg-two --region "$AWS_REGION" \
  --query 'TargetGroups[0].TargetGroupArn' --output text)

echo "[+] Listener 80  ARN : $LISTENER_80_ARN"
echo "[+] Listener 8080 ARN: $LISTENER_8080_ARN"
echo "[+] customer-tg-one  : $CUSTOMER_TG_ONE_ARN"
echo "[+] employee-tg-one  : $EMPLOYEE_TG_ONE_ARN"
echo "[+] employee-tg-two  : $EMPLOYEE_TG_TWO_ARN"

# ============================================================
# Step 1: Fix listener 8080 — restore missing TG associations
# ============================================================
echo ""
echo "[*] Step 1: Restoring listener 8080 TG associations..."

# Listener 8080 default → customer-tg-one
aws elbv2 modify-listener \
  --profile "$PROFILE" \
  --listener-arn "$LISTENER_8080_ARN" \
  --region "$AWS_REGION" \
  --default-actions Type=forward,TargetGroupArn="$CUSTOMER_TG_ONE_ARN" > /dev/null
echo "[+] Listener 8080 default → customer-tg-one ✓"

# Get /admin/* rule ARN on listener 8080
RULE_8080_ADMIN_ARN=$(aws elbv2 describe-rules \
  --profile "$PROFILE" \
  --listener-arn "$LISTENER_8080_ARN" \
  --region "$AWS_REGION" \
  --query 'Rules[?Conditions[0].Field==`path-pattern`].RuleArn' --output text)

# Listener 8080 /admin/* → employee-tg-two (without IP restriction yet)
aws elbv2 modify-rule \
  --profile "$PROFILE" \
  --rule-arn "$RULE_8080_ADMIN_ARN" \
  --region "$AWS_REGION" \
  --actions Type=forward,TargetGroupArn="$EMPLOYEE_TG_TWO_ARN" > /dev/null
echo "[+] Listener 8080 /admin/* → employee-tg-two ✓"

# ============================================================
# Step 2: Add source IP restriction to /admin/* on port 80 and 8080
# ============================================================
echo ""
echo "[*] Step 2: Adding source IP restriction ($MY_IP/32) to /admin/* rules..."

# Get /admin/* rule ARN on listener 80
RULE_80_ADMIN_ARN=$(aws elbv2 describe-rules \
  --profile "$PROFILE" \
  --listener-arn "$LISTENER_80_ARN" \
  --region "$AWS_REGION" \
  --query 'Rules[?Conditions[0].Field==`path-pattern`].RuleArn' --output text)

# Listener 80 /admin/* → employee-tg-one + source IP restriction
aws elbv2 modify-rule \
  --profile "$PROFILE" \
  --rule-arn "$RULE_80_ADMIN_ARN" \
  --region "$AWS_REGION" \
  --conditions \
    "Field=path-pattern,PathPatternConfig={Values=[/admin/*]}" \
    "Field=source-ip,SourceIpConfig={Values=[$MY_IP/32]}" \
  --actions Type=forward,TargetGroupArn="$EMPLOYEE_TG_ONE_ARN" > /dev/null
echo "[+] Listener 80 /admin/* → employee-tg-one restricted to $MY_IP/32 ✓"

# Listener 8080 /admin/* → employee-tg-two + source IP restriction
aws elbv2 modify-rule \
  --profile "$PROFILE" \
  --rule-arn "$RULE_8080_ADMIN_ARN" \
  --region "$AWS_REGION" \
  --conditions \
    "Field=path-pattern,PathPatternConfig={Values=[/admin/*]}" \
    "Field=source-ip,SourceIpConfig={Values=[$MY_IP/32]}" \
  --actions Type=forward,TargetGroupArn="$EMPLOYEE_TG_TWO_ARN" > /dev/null
echo "[+] Listener 8080 /admin/* → employee-tg-two restricted to $MY_IP/32 ✓"

echo ""
echo "[+] TASK 9.1 COMPLETE."
echo "  Listener 80   default  → customer-tg-two (unchanged)"
echo "  Listener 80   /admin/* → employee-tg-one (IP: $MY_IP/32 only)"
echo "  Listener 8080 default  → customer-tg-one (reassociated)"
echo "  Listener 8080 /admin/* → employee-tg-two (IP: $MY_IP/32 only)"
echo "======================================================"
