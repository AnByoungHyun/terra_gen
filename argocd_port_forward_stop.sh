#!/bin/bash

INSTANCE_ID="i-0c28d55ca1f21c180"
REGION="ap-northeast-1"
PROFILE="hyun-ssm"

# 1. 포트포워드 프로세스 종료 명령 실행 및 CommandId 추출
CMD_ID=$(aws ssm send-command \
  --instance-ids "$INSTANCE_ID" \
  --document-name "AWS-RunShellScript" \
  --parameters "commands=[\"sudo su ec2-user -c \\\"pkill -f 'kubectl port-forward svc/argocd-server -n argocd 8080:80'\\\"\"]" \
  --region "$REGION" \
  --profile "$PROFILE" \
  --query "Command.CommandId" \
  --output text)

echo "[INFO] 종료 명령 전달 완료. CommandId: $CMD_ID"
sleep 2

# 2. 명령 실행 결과 확인
aws ssm get-command-invocation \
  --command-id "$CMD_ID" \
  --instance-id "$INSTANCE_ID" \
  --region "$REGION" \
  --profile "$PROFILE" \
  --query '{Status:Status, StandardOutputContent:StandardOutputContent, StandardErrorContent:StandardErrorContent}'

