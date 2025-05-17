#!/bin/bash

# 변수 정의 (필요에 따라 수정)
REGION="ap-northeast-1"
VPC_CIDR="10.20.0.0/16"
PRIVATE_SUBNET1_CIDR="10.20.1.0/24"
PRIVATE_SUBNET2_CIDR="10.20.2.0/24"
PRIVATE_SUBNET3_CIDR="10.20.3.0/24"
PUBLIC_SUBNET_CIDR="10.20.10.0/24"
AVAILABILITY_ZONE1="ap-northeast-1a"
AVAILABILITY_ZONE2="ap-northeast-1c"
AVAILABILITY_ZONE3="ap-northeast-1d"
CLUSTER_NAME="my-eks-cluster"
EKS_ROLE_ARN="arn:aws:iam::626635419731:role/eksClusterRole"

ACTION=${1:-create}
ID_FILE="eks-infra.ids"

if [ "$ACTION" = "create" ]; then
  # 1. VPC 생성
  VPC_ID=$(aws ec2 create-vpc --cidr-block $VPC_CIDR --region $REGION --query 'Vpc.VpcId' --output text)
  echo "VPC_ID: $VPC_ID"

  # 2. 서브넷 생성
  SUBNET1_ID=$(aws ec2 create-subnet --vpc-id $VPC_ID --cidr-block $PRIVATE_SUBNET1_CIDR --availability-zone $AVAILABILITY_ZONE1 --region $REGION --query 'Subnet.SubnetId' --output text)
  SUBNET2_ID=$(aws ec2 create-subnet --vpc-id $VPC_ID --cidr-block $PRIVATE_SUBNET2_CIDR --availability-zone $AVAILABILITY_ZONE2 --region $REGION --query 'Subnet.SubnetId' --output text)
  SUBNET3_ID=$(aws ec2 create-subnet --vpc-id $VPC_ID --cidr-block $PRIVATE_SUBNET3_CIDR --availability-zone $AVAILABILITY_ZONE3 --region $REGION --query 'Subnet.SubnetId' --output text)
  PUBLIC_SUBNET_ID=$(aws ec2 create-subnet --vpc-id $VPC_ID --cidr-block $PUBLIC_SUBNET_CIDR --availability-zone $AVAILABILITY_ZONE1 --region $REGION --query 'Subnet.SubnetId' --output text)
  echo "Private Subnets: $SUBNET1_ID, $SUBNET2_ID, $SUBNET3_ID"
  echo "Public Subnet: $PUBLIC_SUBNET_ID"

  # 3. 인터넷 게이트웨이 생성 및 연결
  IGW_ID=$(aws ec2 create-internet-gateway --region $REGION --query 'InternetGateway.InternetGatewayId' --output text)
  aws ec2 attach-internet-gateway --internet-gateway-id $IGW_ID --vpc-id $VPC_ID --region $REGION
  echo "IGW_ID: $IGW_ID"

  # 4. Elastic IP 생성
  EIP_ALLOC_ID=$(aws ec2 allocate-address --domain vpc --region $REGION --query 'AllocationId' --output text)
  echo "EIP_ALLOC_ID: $EIP_ALLOC_ID"

  # 5. NAT Gateway 생성
  NAT_GW_ID=$(aws ec2 create-nat-gateway --subnet-id $PUBLIC_SUBNET_ID --allocation-id $EIP_ALLOC_ID --region $REGION --query 'NatGateway.NatGatewayId' --output text)
  echo "NAT_GW_ID: $NAT_GW_ID"
  echo "NAT Gateway가 available 상태가 될 때까지 잠시 기다립니다..."
  aws ec2 wait nat-gateway-available --nat-gateway-ids $NAT_GW_ID --region $REGION

  # 6. 라우트 테이블 생성 및 라우팅
  # 퍼블릭 라우트 테이블
  PUB_RTB_ID=$(aws ec2 create-route-table --vpc-id $VPC_ID --region $REGION --query 'RouteTable.RouteTableId' --output text)
  aws ec2 create-route --route-table-id $PUB_RTB_ID --destination-cidr-block 0.0.0.0/0 --gateway-id $IGW_ID --region $REGION
  aws ec2 associate-route-table --subnet-id $PUBLIC_SUBNET_ID --route-table-id $PUB_RTB_ID --region $REGION

  # 프라이빗 라우트 테이블
  PRI_RTB_ID=$(aws ec2 create-route-table --vpc-id $VPC_ID --region $REGION --query 'RouteTable.RouteTableId' --output text)
  aws ec2 create-route --route-table-id $PRI_RTB_ID --destination-cidr-block 0.0.0.0/0 --nat-gateway-id $NAT_GW_ID --region $REGION
  aws ec2 associate-route-table --subnet-id $SUBNET1_ID --route-table-id $PRI_RTB_ID --region $REGION
  aws ec2 associate-route-table --subnet-id $SUBNET2_ID --route-table-id $PRI_RTB_ID --region $REGION
  aws ec2 associate-route-table --subnet-id $SUBNET3_ID --route-table-id $PRI_RTB_ID --region $REGION

  # 7. EKS용 보안 그룹 생성
  SG_ID=$(aws ec2 create-security-group --group-name eks-cluster-sg --description EKSClusterSG --vpc-id $VPC_ID --region $REGION --query 'GroupId' --output text)
  echo "SG_ID: $SG_ID"

  # 8. EKS 클러스터 생성
  aws eks create-cluster \
    --name $CLUSTER_NAME \
    --region $REGION \
    --kubernetes-version 1.30 \
    --role-arn $EKS_ROLE_ARN \
    --resources-vpc-config subnetIds=$SUBNET1_ID,$SUBNET2_ID,$SUBNET3_ID,securityGroupIds=$SG_ID \
   

  echo "EKS 클러스터 생성 요청 완료!"

  # 리소스 생성 및 ID 저장
  echo "VPC_ID=$VPC_ID" > $ID_FILE
  echo "SUBNET1_ID=$SUBNET1_ID" >> $ID_FILE
  echo "SUBNET2_ID=$SUBNET2_ID" >> $ID_FILE
  echo "SUBNET3_ID=$SUBNET3_ID" >> $ID_FILE
  echo "PUBLIC_SUBNET_ID=$PUBLIC_SUBNET_ID" >> $ID_FILE
  echo "IGW_ID=$IGW_ID" >> $ID_FILE
  echo "EIP_ALLOC_ID=$EIP_ALLOC_ID" >> $ID_FILE
  echo "NAT_GW_ID=$NAT_GW_ID" >> $ID_FILE
  echo "PUB_RTB_ID=$PUB_RTB_ID" >> $ID_FILE
  echo "PRI_RTB_ID=$PRI_RTB_ID" >> $ID_FILE
  echo "SG_ID=$SG_ID" >> $ID_FILE
  echo "CLUSTER_NAME=$CLUSTER_NAME" >> $ID_FILE
  echo "리소스 ID가 $ID_FILE 파일에 저장되었습니다."

  exit 0
elif [ "$ACTION" = "delete" ]; then
  if [ ! -f $ID_FILE ]; then
    echo "$ID_FILE 파일이 존재하지 않습니다. 먼저 create로 리소스를 생성하세요."
    exit 1
  fi
  # 파일에서 변수 불러오기
  source $ID_FILE
  echo "리소스 삭제를 시작합니다. (명령어는 echo로 감싸서 출력)"
  # 1. EKS 클러스터 삭제
  echo aws eks delete-cluster --name $CLUSTER_NAME --region $REGION
  # EKS 클러스터 삭제 완료 대기
  echo 'while true; do STATUS=$(aws eks describe-cluster --name $CLUSTER_NAME --region $REGION --query "cluster.status" --output text 2>/dev/null); if [ "$STATUS" = "DELETING" ] || [ "$STATUS" = "CREATING" ]; then echo "EKS 클러스터 삭제 대기 중..."; sleep 10; elif [ "$STATUS" = "ACTIVE" ]; then echo "EKS 클러스터가 아직 삭제되지 않았습니다."; sleep 10; else echo "EKS 클러스터 삭제 완료"; break; fi; done'
  # 2. 보안 그룹 삭제
  echo aws ec2 delete-security-group --group-id $SG_ID --region $REGION
  # 3. 프라이빗 라우트 테이블 삭제
  echo aws ec2 delete-route-table --route-table-id $PRI_RTB_ID --region $REGION
  # 4. 퍼블릭 라우트 테이블 삭제
  echo aws ec2 delete-route-table --route-table-id $PUB_RTB_ID --region $REGION
  # 5. NAT Gateway 삭제
  echo aws ec2 delete-nat-gateway --nat-gateway-id $NAT_GW_ID --region $REGION
  # NAT Gateway 삭제 완료 대기
  echo 'while true; do STATUS=$(aws ec2 describe-nat-gateways --nat-gateway-ids $NAT_GW_ID --region $REGION --query "NatGateways[0].State" --output text 2>/dev/null); if [ "$STATUS" = "deleting" ] || [ "$STATUS" = "pending" ]; then echo "NAT GW 삭제 대기 중..."; sleep 10; elif [ "$STATUS" = "available" ]; then echo "NAT GW가 아직 삭제되지 않았습니다."; sleep 10; else echo "NAT GW 삭제 완료"; break; fi; done'
  # 6. EIP 해제
  echo aws ec2 release-address --allocation-id $EIP_ALLOC_ID --region $REGION
  # 7. IGW Detach & 삭제
  echo aws ec2 detach-internet-gateway --internet-gateway-id $IGW_ID --vpc-id $VPC_ID --region $REGION
  echo aws ec2 delete-internet-gateway --internet-gateway-id $IGW_ID --region $REGION
  # 8. 서브넷 삭제
  echo aws ec2 delete-subnet --subnet-id $SUBNET1_ID --region $REGION
  echo aws ec2 delete-subnet --subnet-id $SUBNET2_ID --region $REGION
  echo aws ec2 delete-subnet --subnet-id $SUBNET3_ID --region $REGION
  echo aws ec2 delete-subnet --subnet-id $PUBLIC_SUBNET_ID --region $REGION
  # 9. VPC 삭제
  echo aws ec2 delete-vpc --vpc-id $VPC_ID --region $REGION
  echo "$ID_FILE 파일을 삭제합니다."
  rm -f $ID_FILE
  exit 0
else
  echo "Usage: $0 [create|delete]"
  exit 1
fi 