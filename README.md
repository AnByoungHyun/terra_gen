# Bastion Host (Terraform 실행용) + SSM 접속 안내

이 프로젝트는 AWS CloudFormation을 이용해 **VPC, Subnet 등 네트워크 인프라부터 Bastion Host EC2 인스턴스까지** 모두 자동으로 생성하며, SSM(Session Manager)으로 안전하게 접속할 수 있도록 구성합니다.

---

## 1. CloudFormation 템플릿 배포 방법

1. **템플릿 파일 준비**
   - `bestion-ssm.yaml` 파일을 확인하세요.

2. **AWS 콘솔에서 배포**
   - AWS Management Console > CloudFormation > 스택 생성
   - 템플릿 업로드 > `bestion-ssm.yaml` 선택
   - 파라미터 입력 (EC2 인스턴스 타입만 입력, 네트워크는 자동 생성)
   - 스택 생성

3. **CLI로 배포**
   ```bash
   aws cloudformation create-stack \
     --stack-name bastion-ssm \
     --template-body file://bestion-ssm.yaml \
     --parameters ParameterKey=InstanceType,ParameterValue=t3.micro
   ```

---

## 2. 생성되는 리소스
- VPC (10.10.0.0/16)
- Public Subnet (10.10.1.0/24)
- Internet Gateway, Route Table, Route Table Association
- Bastion Host EC2 (Amazon Linux 2023, Terraform 자동 설치)
- Security Group (아웃바운드만 허용)
- IAM Role (SSM 및 Terraform 실행 권한)

---

## 3. Bastion Host EC2 인스턴스 정보
- **OS**: Amazon Linux 2023
- **Terraform 설치**: UserData에서 dnf 패키지 매니저를 사용하여 자동 설치
  ```bash
  dnf update -y
  dnf install -y dnf-plugins-core
  dnf config-manager --add-repo https://rpm.releases.hashicorp.com/AmazonLinux/hashicorp.repo
  dnf -y install terraform
  terraform -install-autocomplete
  mkdir -p /home/ec2-user/terraform
  chown ec2-user:ec2-user /home/ec2-user/terraform
  ```
- **작업 디렉토리**: `/home/ec2-user/terraform`

---

## 4. SSM(Session Manager)으로 Bastion Host 접속하기

1. **IAM 권한 확인**
   - EC2 인스턴스에 `AmazonSSMManagedInstanceCore` 정책이 포함된 Role이 할당되어 있습니다.
   - 접속하는 사용자는 AWS 콘솔에서 SSM 접속 권한이 필요합니다.

2. **SSM Agent 상태 확인**
   - Amazon Linux 2023에는 SSM Agent가 기본 설치되어 있습니다.
   - 인스턴스가 정상적으로 SSM에 등록되면, Systems Manager > 세션 매니저에서 인스턴스가 보입니다.

3. **AWS 콘솔에서 접속**
   - AWS Management Console > Systems Manager > 세션 매니저 > 세션 시작
   - 인스턴스 목록에서 Bastion Host 선택 후 접속

4. **CLI로 접속**
   ```bash
   aws ssm start-session --target <Bastion-Instance-Id> --profile <사용할-프로파일-이름>
   ```
   - `--profile` 옵션에 본인이 SSM 접속용으로 설정한 AWS CLI 프로파일명을 입력하세요.
   - 예시: `aws ssm start-session --target i-0123456789abcdef0 --profile my-ssm-profile`

---

## 5. Bastion Host에서 Terraform 사용

- EC2 인스턴스가 생성되면, Terraform이 자동으로 설치됩니다.
- `/home/ec2-user/terraform` 디렉토리에서 작업을 시작할 수 있습니다.
- 예시:
  ```bash
  cd /home/ec2-user/terraform
  terraform version
  ```

---

## 6. SSM send-command로 Bastion에 Terraform 버전 확인하기

### 1) 명령 실행

```bash
aws ssm send-command \
  --instance-ids i-0c28d55ca1f21c180 \
  --document-name "AWS-RunShellScript" \
  --parameters 'commands=["terraform version"]' \
  --profile hyun-ssm
```
- 실행 후 반환되는 `CommandId`를 기록해 둡니다.

### 2) 결과 확인

```bash
aws ssm get-command-invocation \
  --command-id <CommandId> \
  --instance-id i-0c28d55ca1f21c180 \
  --profile hyun-ssm
```
- 결과의 `StandardOutputContent` 필드에서 Terraform 버전 정보를 확인할 수 있습니다.

### 3) 핵심 정보만 필터링해서 보기 (jq 활용)

```bash
aws ssm get-command-invocation \
  --command-id <CommandId> \
  --instance-id i-0c28d55ca1f21c180 \
  --profile hyun-ssm \
  | jq '{Status, StandardOutputContent, StandardErrorContent}'
```
- 위 명령을 사용하면 **상태, 표준 출력, 표준 에러**만 간결하게 확인할 수 있습니다.
- 예시 결과:
  ```json
  {
    "Status": "Success",
    "StandardOutputContent": "Terraform v1.12.0\non linux_amd64\n",
    "StandardErrorContent": ""
  }
  ```

---

## 참고 사항
- 보안 강화를 위해 Bastion Host에는 인바운드 규칙이 없습니다.
- Terraform 실행 권한은 예시로 `AdministratorAccess`가 부여되어 있으니, 실제 운영 환경에서는 최소 권한 정책을 적용하세요.
- CloudFormation 템플릿의 Description, Tags, Outputs 등에는 한글을 사용할 수 있습니다.
- 추가 문의 사항은 언제든 말씀해 주세요!

---

## 7. 새로운 VPC에 EKS 클러스터 생성(AWS CLI)

아래는 AWS CLI를 사용하여 새로운 VPC에 EKS 클러스터를 생성하는 전체 과정입니다.

### 1) VPC 및 private 서브넷, 퍼블릭 서브넷 생성

```bash
# VPC 생성
aws ec2 create-vpc --cidr-block 10.20.0.0/16 --region ap-northeast-1 --profile hyun-ssm

# 프라이빗 서브넷 3개 생성 (예시)
aws ec2 create-subnet --vpc-id <VPC_ID> --cidr-block 10.20.1.0/24 --availability-zone ap-northeast-1a --region ap-northeast-1 --profile hyun-ssm
aws ec2 create-subnet --vpc-id <VPC_ID> --cidr-block 10.20.2.0/24 --availability-zone ap-northeast-1c --region ap-northeast-1 --profile hyun-ssm
aws ec2 create-subnet --vpc-id <VPC_ID> --cidr-block 10.20.3.0/24 --availability-zone ap-northeast-1d --region ap-northeast-1 --profile hyun-ssm

# 퍼블릭 서브넷 생성 (예시)
aws ec2 create-subnet --vpc-id <VPC_ID> --cidr-block 10.20.10.0/24 --availability-zone ap-northeast-1a --region ap-northeast-1 --profile hyun-ssm

# 인터넷 게이트웨이 생성
aws ec2 create-internet-gateway --region ap-northeast-1 --profile hyun-ssm

# IGW를 VPC에 연결
aws ec2 attach-internet-gateway --internet-gateway-id <IGW_ID> --vpc-id <VPC_ID> --region ap-northeast-1 --profile hyun-ssm
```

### 2) NAT Gateway 및 라우트 테이블 구성

```bash
# Elastic IP 생성
aws ec2 allocate-address --domain vpc --region ap-northeast-1 --profile hyun-ssm

# NAT Gateway 생성
aws ec2 create-nat-gateway --subnet-id <PUBLIC_SUBNET_ID> --allocation-id <EIP_ALLOCATION_ID> --region ap-northeast-1 --profile hyun-ssm

# 퍼블릭 라우트 테이블 생성 및 IGW 라우팅
aws ec2 create-route-table --vpc-id <VPC_ID> --region ap-northeast-1 --profile hyun-ssm
aws ec2 create-route --route-table-id <PUBLIC_RTB_ID> --destination-cidr-block 0.0.0.0/0 --gateway-id <IGW_ID> --region ap-northeast-1 --profile hyun-ssm
aws ec2 associate-route-table --subnet-id <PUBLIC_SUBNET_ID> --route-table-id <PUBLIC_RTB_ID> --region ap-northeast-1 --profile hyun-ssm

# 프라이빗 라우트 테이블 생성 및 NAT GW 라우팅
aws ec2 create-route-table --vpc-id <VPC_ID> --region ap-northeast-1 --profile hyun-ssm
aws ec2 create-route --route-table-id <PRIVATE_RTB_ID> --destination-cidr-block 0.0.0.0/0 --nat-gateway-id <NAT_GW_ID> --region ap-northeast-1 --profile hyun-ssm
# 프라이빗 서브넷 각각에 연결
aws ec2 associate-route-table --subnet-id <PRIVATE_SUBNET_ID> --route-table-id <PRIVATE_RTB_ID> --region ap-northeast-1 --profile hyun-ssm
```

### 3) EKS 클러스터 생성

```bash
aws eks create-cluster \
  --name my-eks-cluster \
  --region ap-northeast-1 \
  --kubernetes-version 1.30 \
  --role-arn <EKS_ROLE_ARN> \
  --resources-vpc-config subnetIds=<PRIVATE_SUBNET_ID_1>,<PRIVATE_SUBNET_ID_2>,<PRIVATE_SUBNET_ID_3>,securityGroupIds=<SG_ID> \
  --profile hyun-ssm
```

> 각 명령의 `<...>` 부분은 실제 생성된 리소스 ID로 대체해야 합니다.
> EKS 클러스터는 프라이빗 서브넷 2개 이상, 보안 그룹, IAM Role이 필요합니다.

### EKS 클러스터 생성에 필요한 IAM Role 권한 안내

EKS 클러스터를 생성할 때 사용하는 IAM Role(예: eksClusterRole)에는 아래와 같은 권한이 필요합니다.

#### 1. AWS 공식 권장 정책 (최소 권한)
- `AmazonEKSClusterPolicy`
- `AmazonEKSServicePolicy`

#### 2. 추가적으로 필요한 경우
- VPC, 서브넷, 보안 그룹 등 네트워크 리소스 생성을 위해서는
  - `AmazonEC2FullAccess` 또는
  - EC2/VPC 관련 최소 권한 정책이 필요할 수 있습니다.
- 클러스터 로깅, CloudWatch 연동 등 추가 기능을 사용할 경우
  - `CloudWatchLogsFullAccess` 등 필요에 따라 추가

#### 3. 예시: eksClusterRole에 정책 연결
```bash
aws iam attach-role-policy --role-name eksClusterRole --policy-arn arn:aws:iam::aws:policy/AmazonEKSClusterPolicy
aws iam attach-role-policy --role-name eksClusterRole --policy-arn arn:aws:iam::aws:policy/AmazonEKSServicePolicy
```

> 실제 운영 환경에서는 최소 권한 원칙에 따라 필요한 정책만 연결하는 것이 보안상 안전합니다.

---

## 8. SSM send-command를 활용한 Bastion 자동화 실습

### 1) 실습 표준: 명령을 echo로 감싸 출력

```bash
GIT_TOKEN=$(cat ./tmp/git_token.txt)
echo $(aws ssm send-command --profile hyun-ssm --instance-ids i-0c28d55ca1f21c180 --document-name 'AWS-RunShellScript' --parameters commands='["set -e; export HOME=/home/ec2-user; cd /home/ec2-user; if [ ! -d terra_gen ]; then git clone https://${GIT_TOKEN}@github.com/AnByoungHyun/terra_gen.git; else git config --global --add safe.directory /home/ec2-user/terra_gen; cd terra_gen; git reset --hard HEAD; git pull; fi; cd /home/ec2-user/terra_gen/terraform; terraform init; terraform plan -out=tfplan; terraform apply -auto-approve tfplan"]' --comment 'EKS 인프라 자동화 실습' --output text)
```

- 실습 표준에 따라 모든 명령은 echo로 감싸 출력합니다.
- 실제 실행 시에는 echo를 제거하여 사용합니다.

### 2) 실행 결과 확인

```bash
aws ssm get-command-invocation --profile hyun-ssm --command-id <CommandId> --instance-id i-0c28d55ca1f21c180 | jq
```

- `StandardOutputContent`, `StandardErrorContent`에서 실행 결과를 확인할 수 있습니다.

### 3) 주요 트러블슈팅

- **dubious ownership 오류**  
  → `git config --global --add safe.directory /home/ec2-user/terra_gen` 명령을 git pull 전에 실행
- **$HOME not set 오류**  
  → `export HOME=/home/ec2-user` 추가
- **로컬 변경사항으로 인한 pull 실패**  
  → `git reset --hard HEAD`로 강제 pull
- **Terraform 변수 미지정 오류**  
  → `terraform plan/apply`에 `-var 'eks_role_arn=...'` 옵션 추가 필요

### 4) 실습 자동화 요약

- Bastion에서 SSM, git, Terraform을 활용해 EKS 인프라를 완전 자동화로 구축/삭제
- 모든 명령은 echo로 감싸 출력(실습 표준)
- git_token.txt는 절대 커밋하지 않음(.gitignore에 추가)
- 반복 실행, 오류, 자동화, 문서화, git 관리 등 실무에 필요한 모든 과정을 단계별로 경험

---

## 9. Bastion VPC와 EKS VPC 간 내부 통신(VPC Peering) 설정

### 1) VPC Peering 연결 생성

```bash
aws ec2 create-vpc-peering-connection \
  --vpc-id <BASTION_VPC_ID> \
  --peer-vpc-id <EKS_VPC_ID> \
  --region ap-northeast-1 \
  --profile hyun-ssm
```

### 2) 피어링 연결 승인

```bash
aws ec2 accept-vpc-peering-connection \
  --vpc-peering-connection-id <PEERING_ID> \
  --region ap-northeast-1 \
  --profile hyun-ssm
```

### 3) 라우트 테이블에 피어링 경로 추가

```bash
# Bastion VPC 라우트 테이블에 EKS VPC 경로 추가
aws ec2 create-route \
  --route-table-id <BASTION_RTB_ID> \
  --destination-cidr-block <EKS_VPC_CIDR> \
  --vpc-peering-connection-id <PEERING_ID> \
  --region ap-northeast-1 \
  --profile hyun-ssm

# EKS VPC 라우트 테이블에 Bastion VPC 경로 추가
aws ec2 create-route \
  --route-table-id <EKS_RTB_ID> \
  --destination-cidr-block <BASTION_VPC_CIDR> \
  --vpc-peering-connection-id <PEERING_ID> \
  --region ap-northeast-1 \
  --profile hyun-ssm
```

### 4) 보안 그룹 설정

- Bastion → EKS, EKS → Bastion 통신이 필요한 포트만 허용

---

> 위 명령에서 `<...>` 부분은 실제 리소스 ID 및 CIDR로 대체해야 합니다.
> VPC Endpoint 방식이 필요하다면 추가 안내 가능합니다.

---

## 9. Private 서브넷에서 인터넷 접근을 위한 NAT Gateway 구성

Helm 등 외부 인터넷 접근이 필요한 경우, NAT Gateway와 퍼블릭 서브넷을 아래와 같이 구성합니다.

### 1) 퍼블릭 서브넷 생성 (예: 10.20.10.0/24, ap-northeast-1a)

```bash
aws ec2 create-subnet --vpc-id <VPC_ID> --cidr-block 10.20.10.0/24 --availability-zone ap-northeast-1a --region ap-northeast-1 --profile hyun-ssm
```

### 2) Elastic IP 생성

```bash
aws ec2 allocate-address --domain vpc --region ap-northeast-1 --profile hyun-ssm
```

### 3) NAT Gateway 생성

```bash
aws ec2 create-nat-gateway --subnet-id <PUBLIC_SUBNET_ID> --allocation-id <EIP_ALLOCATION_ID> --region ap-northeast-1 --profile hyun-ssm
```

### 4) 라우트 테이블 구성

#### (1) 퍼블릭 라우트 테이블 생성 및 IGW 라우팅
```bash
aws ec2 create-route-table --vpc-id <VPC_ID> --region ap-northeast-1 --profile hyun-ssm
aws ec2 create-route --route-table-id <PUBLIC_RTB_ID> --destination-cidr-block 0.0.0.0/0 --gateway-id <IGW_ID> --region ap-northeast-1 --profile hyun-ssm
aws ec2 associate-route-table --subnet-id <PUBLIC_SUBNET_ID> --route-table-id <PUBLIC_RTB_ID> --region ap-northeast-1 --profile hyun-ssm
```

#### (2) 프라이빗 라우트 테이블 생성 및 NAT GW 라우팅
```bash
aws ec2 create-route-table --vpc-id <VPC_ID> --region ap-northeast-1 --profile hyun-ssm
aws ec2 create-route --route-table-id <PRIVATE_RTB_ID> --destination-cidr-block 0.0.0.0/0 --nat-gateway-id <NAT_GW_ID> --region ap-northeast-1 --profile hyun-ssm
# 프라이빗 서브넷 각각에 연결
aws ec2 associate-route-table --subnet-id <PRIVATE_SUBNET_ID> --route-table-id <PRIVATE_RTB_ID> --region ap-northeast-1 --profile hyun-ssm
```

> 각 명령의 `<...>` 부분은 실제 생성된 리소스 ID로 대체해야 합니다.
> NAT Gateway가 생성된 후 상태가 available이 될 때까지 잠시 기다려야 합니다.

---

## EKS 인프라 자동화 구축 실습 가이드

## 1. 사전 준비

- **EC2 Bastion Host**: SSM Agent가 설치된 Amazon Linux 2023, IAM Role 할당
- **GitHub Personal Access Token**: 프라이빗 리포지토리 접근용, 로컬에 `./tmp/git_token.txt`로 저장
- **AWS CLI 프로파일**: (EC2에 Role 할당 시 profile 불필요)

## 2. 쉘 스크립트 실행 방법

> **참고:**
> - 전체 인프라 자동화(스크립트 실행)는 약 2분 정도 소요됩니다.
> - EKS 클러스터가 실제로 ACTIVE 상태가 되기까지는 추가로 5분 정도 더 걸릴 수 있습니다.

### 2-1. SSM send-command로 원격 실행 (실습 표준)

1. **로컬에서 git token 준비**
   ```bash
   # Github Personal Access Token을 ./tmp/git_token.txt에 저장
   export GIT_TOKEN=$(cat ./tmp/git_token.txt)
   ```

2. **SSM send-command 명령어 (ec2-user로 실행, echo로 감싸서 출력)**
   ```bash
   GIT_TOKEN=$(cat ./tmp/git_token.txt); echo $(aws ssm send-command \
     --instance-ids i-0c28d55ca1f21c180 \
     --document-name "AWS-RunShellScript" \
     --parameters "commands=[\"cd /home/ec2-user; sudo -u ec2-user bash -c 'if [ -d terra_gen ]; then cd terra_gen && git pull https://${GIT_TOKEN}@github.com/AnByoungHyun/terra_gen.git; else git clone https://${GIT_TOKEN}@github.com/AnByoungHyun/terra_gen.git; cd terra_gen; fi; chmod +x create-eks-infra.sh; ./create-eks-infra.sh create'\"]" \
     --region ap-northeast-1 \
     --profile hyun-ssm)
   ```
   - 이미 디렉토리가 있으면 git pull, 없으면 git clone 후 스크립트 실행
   - delete 실행 시 마지막 명령만 `./create-eks-infra.sh delete`로 변경

3. **명령 실행 결과 확인**
   ```bash
   echo $(aws ssm get-command-invocation \
     --command-id <CommandId> \
     --instance-id i-0c28d55ca1f21c180 \
     --profile hyun-ssm)
   ```
   - CommandId는 send-command 결과에서 확인
   - 여러 번 반복 실행하여 Status가 Success가 될 때까지 확인

## 3. 직접 EC2에서 실행 (SSM Session Manager 등)

```bash
# ec2-user로 로그인 후
cd ~/terra_gen
chmod +x create-eks-infra.sh
./create-eks-infra.sh create   # 생성
./create-eks-infra.sh delete   # 삭제
```

## 4. 참고 및 팁

- **IAM Role**이 할당된 EC2에서는 profile 옵션 없이 실행 가능
- **실습 표준**: 모든 명령은 echo로 감싸서 출력
- **토큰 보안**: git token은 절대 git에 올리지 않고, 로컬에서만 관리
- **명령 자동화/반복**: while문, jq 등으로 결과 파싱 가능

---

궁금한 점이나 오류 발생 시 README에 있는 예시 명령을 복사해 사용하거나, 추가 문의해 주세요! 