#!/bin/bash

# 변수 설정
INSTANCE_ID="i-0c28d55ca1f21c180"
REGION="ap-northeast-1"
PROFILE="hyun-ssm"
LOCAL_PORT=8080
REMOTE_PORT=8080

# 1. Bastion Host에서 ec2-user로 kubectl port-forward를 백그라운드로 실행
aws ssm send-command \
  --instance-ids "$INSTANCE_ID" \
  --document-name "AWS-RunShellScript" \
  --parameters "commands=[\"sudo su ec2-user -c 'nohup kubectl port-forward svc/argocd-server -n argocd 8080:80 > /tmp/argocd_port_forward.log 2>&1 &' \"]" \
  --region "$REGION" \
  --profile "$PROFILE"

sleep 2

# 2. 로컬에서 SSM 포트포워딩 세션 실행 (포그라운드)
aws ssm start-session \
  --target "$INSTANCE_ID" \
  --document-name AWS-StartPortForwardingSession \
  --parameters "{\"portNumber\":[\"$REMOTE_PORT\"],\"localPortNumber\":[\"$LOCAL_PORT\"]}" \
  --region "$REGION" \
  --profile "$PROFILE"

echo "[INFO] SSM 포트포워딩 세션이 백그라운드에서 실행되었습니다."
echo "[INFO] 브라우저에서 http://localhost:$LOCAL_PORT 으로 접속하세요." 