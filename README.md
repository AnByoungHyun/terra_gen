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