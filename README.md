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

## 3-1. Bastion Host에 kubectl 설치 및 EKS kubeconfig 셋팅 방법

### 1) kubectl 설치 (공식 최신 버전)
- Bastion Host는 CloudFormation UserData에서 **kubectl이 자동 설치**됩니다.
- 수동 설치가 필요하다면 아래 명령을 실행하세요.
  ```bash
  curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
  sudo install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl
  rm -f kubectl
  kubectl version --client
  ```

### 2) EKS kubeconfig 셋팅 (ec2-user 기준)
- Bastion에서 EKS 클러스터에 kubectl로 접속하려면 **ec2-user 계정 기준**으로 kubeconfig를 셋팅해야 합니다.
- 아래 명령을 사용하세요.
  ```bash
  sudo -u ec2-user aws eks update-kubeconfig \
    --region <EKS_리전> \
    --name <EKS_클러스터_이름>
  ```
  - 예시:
    ```bash
    sudo -u ec2-user aws eks update-kubeconfig --region ap-northeast-1 --name my-eks-cluster
    ```
- 정상적으로 셋팅되면 아래와 같이 클러스터 정보를 조회할 수 있습니다.
  ```bash
  sudo -u ec2-user kubectl get nodes -o wide
  ```

### 3) SSM send-command로 자동화 실습 (표준)
- SSM 명령은 반드시 **echo로 감싸서 출력**하고, 실제 실행은 echo를 제거해 사용합니다.
- 예시: ec2-user 기준 kubeconfig 셋팅
  ```bash
  echo $(aws ssm send-command --profile hyun-ssm --instance-ids <Bastion-Instance-Id> --document-name 'AWS-RunShellScript' --parameters commands='["sudo -u ec2-user aws eks update-kubeconfig --region ap-northeast-1 --name my-eks-cluster && echo ec2-user kubeconfig 재설정 완료"]' --comment 'ec2-user kubeconfig 재설정' --output text)
  ```
- kubectl 명령도 ec2-user 기준으로 실행해야 하며, 예시:
  ```bash
  echo $(aws ssm send-command --profile hyun-ssm --instance-ids <Bastion-Instance-Id> --document-name 'AWS-RunShellScript' --parameters commands='["sudo -u ec2-user kubectl get nodes -o wide || echo 노드 조회 실패"]' --comment 'ec2-user로 kubectl get nodes 최종 확인' --output text)
  ```

### 4) 주요 트러블슈팅 및 실습 팁
- kubeconfig가 /root/.kube/config에만 생성되면 ec2-user로 kubectl이 동작하지 않으니 반드시 ec2-user 기준으로 셋팅 필요
- "The connection to the server localhost:8080 was refused" 오류 시, kubeconfig 경로/권한/사용자 확인
- EKS 클러스터에 노드가 없으면 "No resources found"가 출력되며, 이는 정상 연결 상태임
- SSM 명령 실행 후에는 get-command-invocation으로 결과를 꼭 확인
- 실습 표준: 모든 명령 echo로 감싸 출력, git_token.txt는 절대 커밋하지 않음, 반복 실행/오류/자동화/문서화/git 관리 등 실무에 필요한 모든 과정 단계별 경험

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

## 5-1. Terraform으로 EKS 인프라 배포 및 삭제

### 1) EKS 인프라 배포 (적용)

Bastion Host에서 아래 명령을 실행하세요. (ec2-user 환경)

```bash
cd /home/ec2-user/terraform
terraform init
terraform plan
terraform apply -auto-approve
```

- 실습 표준에 따라 SSM send-command로 echo로 감싸서 실행 예시:

```bash
echo $(aws ssm send-command \
  --instance-ids "i-0c28d55ca1f21c180" \
  --document-name "AWS-RunShellScript" \
  --parameters 'commands=["cd /home/ec2-user/terraform && terraform init && terraform plan && terraform apply -auto-approve"]' \
  --region ap-northeast-1 \
  --profile hyun-ssm)
```

### 2) EKS 인프라 삭제 (파괴)

아래 명령으로 모든 리소스를 삭제할 수 있습니다.

```bash
cd /home/ec2-user/terraform
terraform destroy -auto-approve
```

- 실습 표준에 따라 SSM send-command로 echo로 감싸서 실행 예시:

```bash
echo $(aws ssm send-command \
  --instance-ids "i-0c28d55ca1f21c180" \
  --document-name "AWS-RunShellScript" \
  --parameters 'commands=["cd /home/ec2-user/terraform && terraform destroy -auto-approve"]' \
  --region ap-northeast-1 \
  --profile hyun-ssm)
```

- destroy 명령 실행 전, 반드시 중요한 리소스가 없는지 확인하세요.

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

## 8. Argo CD 대시보드 접근 방법 (포트포워딩)

EKS가 프라이빗 서브넷에 있고, Bastion Host를 통해서만 접근 가능한 환경에서 Argo CD 대시보드에 접속하는 방법입니다.

### 1) Bastion Host에서 포트포워딩 실행

Bastion Host(ec2-user)에서 아래 명령을 실행하여,  
EKS 내 argocd-server 서비스의 80번 포트를 Bastion Host의 8080 포트로 포워딩합니다.

```bash
sudo su ec2-user -c "kubectl port-forward svc/argocd-server -n argocd 8080:80"
```

### 2) 로컬 PC에서 SSM 포트포워딩 세션 시작

로컬 PC에서 아래 명령을 실행하면,  
내 PC의 8080 포트가 Bastion Host의 8080 포트로 안전하게 터널링됩니다.

```bash
aws ssm start-session \
  --target i-0c28d55ca1f21c180 \
  --document-name AWS-StartPortForwardingSession \
  --parameters '{"portNumber":["8080"],"localPortNumber":["8080"]}' \
  --region ap-northeast-1 \
  --profile hyun-ssm
```

### 3) 웹 브라우저에서 접속

이제 로컬 PC에서 아래 주소로 접속하면 Argo CD 대시보드에 접근할 수 있습니다.

```
http://localhost:8080
```

### 4) 초기 관리자 비밀번호 확인

아래 명령으로 Argo CD의 admin 초기 비밀번호를 확인할 수 있습니다.

```bash
sudo su ec2-user -c "kubectl get secret argocd-initial-admin-secret -n argocd -o jsonpath=\"{.data.password}\" | base64 --decode"
```

---

이렇게 하면 Bastion Host와 SSM 포트포워딩을 활용해  
로컬 PC에서 안전하게 Argo CD 대시보드에 접근할 수 있습니다.

---

## 9. Helm을 이용한 Argo CD 설치 및 자동 배포 실습

### 1) Helm 저장소 추가 및 업데이트
```bash
helm repo add argo https://argoproj.github.io/argo-helm
helm repo update
```

### 2) Argo CD 네임스페이스 생성
```bash
kubectl create namespace argocd
```

### 3) Helm Chart로 Argo CD 설치
```bash
helm install argocd argo/argo-cd -n argocd
```
- `argocd`는 릴리스 이름(원하는 이름으로 변경 가능)
- `-n argocd`는 설치할 네임스페이스

### 4) 설치 확인
```bash
kubectl get all -n argocd
```
- Argo CD 관련 파드, 서비스 등이 정상적으로 생성되었는지 확인

### 5) (선택) values.yaml로 커스터마이징 설치
```bash
helm install argocd argo/argo-cd -n argocd -f values.yaml
```

### 6) Argo CD UI 접속 (포트포워딩)
```bash
kubectl port-forward svc/argocd-server -n argocd 8080:443
```
- 브라우저에서 https://localhost:8080 접속

### 7) 초기 관리자 비밀번호 확인
```bash
kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d; echo
```
- 사용자명: admin
- 위 명령으로 나온 비밀번호로 로그인

### 8) SSM send-command로 Bastion에서 자동 설치 예시
```bash
echo $(aws ssm send-command \
  --instance-ids "i-0c28d55ca1f21c180" \
  --document-name "AWS-RunShellScript" \
  --parameters 'commands=["helm repo add argo https://argoproj.github.io/argo-helm && helm repo update && kubectl create namespace argocd --dry-run=client -o yaml | kubectl apply -f - && helm install argocd argo/argo-cd -n argocd"]' \
  --region ap-northeast-1 \
  --profile hyun-ssm)
```

### 참고
- Helm Chart의 다양한 옵션은 공식 문서([argo-helm/argo-cd values.yaml](https://github.com/argoproj/argo-helm/blob/main/charts/argo-cd/values.yaml))에서 확인할 수 있습니다.
- 실무에서는 Ingress, 인증, 리소스 제한 등 values.yaml로 세부 설정을 조정하는 것이 일반적입니다.

---

## 10. Private Subnet 환경에서 Argo CD 대시보드 안전하게 접근하기 (SSM + kubectl port-forward)

### 1) 개요
- 쿠버네티스(EKS 등)가 프라이빗 서브넷에 있을 때, 외부에서 Argo CD 대시보드(웹 UI)에 안전하게 접근하는 대표적인 방법입니다.
- **SSM Session Manager 포트포워딩**과 **kubectl port-forward**를 조합하여, Bastion Host를 통해 외부 노출 없이 안전하게 접근할 수 있습니다.

### 2) 전체 흐름
```
[로컬PC:8080] --(SSM 포트포워딩)--> [Bastion:8080] --(kubectl port-forward)--> [ArgoCD:443]
```

### 3) 단계별 명령 예시

#### (1) SSM Session Manager로 Bastion Host에 포트포워딩
```bash
aws ssm start-session \
  --target <Bastion-Instance-Id> \
  --document-name AWS-StartPortForwardingSession \
  --parameters '{"portNumber":["8080"],"localPortNumber":["8080"]}' \
  --profile <profile>
```
- 위 명령을 실행하면, 로컬PC의 8080 포트가 Bastion Host의 8080 포트로 포워딩됩니다.

#### (2) Bastion Host에서 kubectl port-forward 실행
```bash
kubectl port-forward svc/argocd-server -n argocd 8080:443
```
- Bastion Host의 8080 포트가 쿠버네티스 argocd-server 서비스(443)로 포워딩됩니다.

#### (3) 로컬 브라우저에서 접속
- 브라우저에서 https://localhost:8080 으로 접속하면 Argo CD 대시보드에 접근할 수 있습니다.

### 4) 장점 및 실무 팁
- **보안성**: 외부에 직접 노출하지 않고, IAM 권한만 있으면 SSH 키 없이도 안전하게 접근 가능
- **간편성**: 별도의 VPN, Ingress, ALB 등 추가 인프라 없이 바로 사용 가능
- **임시/운영 모두 활용 가능**: 실습, PoC, 운영 환경에서 임시 접근, 트러블슈팅, 긴급 운영 등에 매우 유용
- 여러 명이 동시에 접근할 경우, 포트 번호(8081, 8082 등)를 다르게 할 수 있음

### 5) 참고
- 상시 서비스(여러 사용자, 외부 연동 등)에는 Ingress+ALB+인증 방식이 더 적합
- SSM 포트포워딩은 AWS CLI v2 이상에서 지원

--- 