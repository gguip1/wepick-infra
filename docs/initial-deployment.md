# 초기 배포 절차

아무것도 없는 AWS 계정에서 prod까지 올리는 순서.

## 사전 준비

- AWS CLI v2 설치 + 로컬 credential 설정 (`aws sts get-caller-identity` 확인)
- Terraform >= 1.10.0

### 필요 IAM 권한

최소 권한으로 구성하려면 아래 서비스 권한을 레이어별로 부여한다.

| 레이어 | 서비스 | 주요 액션 |
|--------|--------|-----------|
| Bootstrap | S3 | `CreateBucket`, `DeleteBucket`, `PutBucketVersioning`, `PutBucketEncryption`, `PutBucketPublicAccessBlock`, `PutBucketPolicy` |
| Bootstrap | IAM | `CreateOpenIDConnectProvider`, `GetOpenIDConnectProvider`, `DeleteOpenIDConnectProvider` |
| Shared | IAM | `CreateRole`, `DeleteRole`, `GetRole`, `PutRolePolicy`, `GetRolePolicy`, `DeleteRolePolicy`, `AttachRolePolicy`, `DetachRolePolicy`, `CreateInstanceProfile`, `DeleteInstanceProfile`, `AddRoleToInstanceProfile`, `RemoveRoleFromInstanceProfile`, `PassRole` |
| Shared | ECR | `CreateRepository`, `DeleteRepository`, `DescribeRepositories`, `SetRepositoryPolicy`, `GetRepositoryPolicy`, `PutLifecyclePolicy` |
| Prod | EC2 | `RunInstances`, `TerminateInstances`, `DescribeInstances`, `CreateVpc`, `DeleteVpc`, `CreateSubnet`, `DeleteSubnet`, `CreateInternetGateway`, `AttachInternetGateway`, `CreateRouteTable`, `CreateSecurityGroup`, `AllocateAddress`, `AssociateAddress`, `ReleaseAddress` |
| Prod | S3 | Bootstrap과 동일 |
| Prod | CloudFront | `CreateDistribution`, `UpdateDistribution`, `DeleteDistribution`, `CreateCloudFrontOriginAccessControl`, `GetCloudFrontOriginAccessControl` |
| Prod | SSM | `PutParameter`, `GetParameter`, `GetParameters`, `DeleteParameter`, `DescribeParameters` |
| Prod | IAM | `PutRolePolicy` (EC2 role에 inline policy 추가) |
| 공통 | STS | `GetCallerIdentity` |

---

## 1. Bootstrap

```bash
cd terraform/envs/bootstrap
cp terraform.tfvars.example terraform.tfvars
# terraform.tfvars에 aws_account_id, github_repo 입력
terraform init && terraform apply
```

생성: tfstate S3 버킷, GitHub OIDC Provider

> `terraform.tfstate`는 로컬 파일 — 삭제하지 말 것.

---

## 2. Shared

```bash
cd terraform/envs/shared
terraform init && terraform apply
terraform output  # role ARN 저장
```

생성: EC2 IAM Role, ECR (`wepick-be`, `wepick-fe`), OIDC Deploy Role 3개

---

## 3. GitHub Secrets 등록

| 레포 | Secret | 값 |
|------|--------|----|
| wepick-infra | `AWS_ROLE_ARN` | shared output `infra_deploy_role_arn` |
| wepick-be | `AWS_ROLE_ARN_DEPLOY` | shared output `be_deploy_role_arn` |
| wepick-fe | `AWS_ROLE_ARN_DEPLOY` | shared output `fe_deploy_role_arn` |

---

## 4. Prod Apply

```bash
cd terraform/envs/prod
cp terraform.tfvars.example terraform.tfvars
# terraform.tfvars에 domain_name 입력
terraform init && terraform apply
terraform output  # elastic_ip, artifacts_bucket_name 확인
```

- wepick-infra Secret에 `AWS_S3_BUCKET_NAME = artifacts_bucket_name` 추가 등록

---

## 5. DNS 등록

```
your-domain.com      →  <elastic_ip>
api.your-domain.com  →  <elastic_ip>
```

전파 확인 후 다음 단계로 넘어간다:

```bash
dig your-domain.com +short
dig api.your-domain.com +short
```

---

## 6. SSM 파라미터 설정

Terraform이 placeholder로 생성한 값을 실제 값으로 교체:

```bash
aws ssm put-parameter --name '/wepick/mysql_password'      --value '...' --type SecureString --overwrite
aws ssm put-parameter --name '/wepick/mysql_root_password' --value '...' --type SecureString --overwrite
```

---

## 7. 초기 nginx 배포

wepick-infra Actions에서 **Sync prod artifacts to S3** 워크플로를 수동 트리거.
성공하면 **Deploy nginx** 가 자동으로 이어지면서:

1. S3 → EC2 파일 동기화
2. `.env` 생성 (SSM Parameter Store 값)
3. certbot standalone으로 TLS 인증서 발급 (최초 1회)
4. nginx 기동

---

## 8. BE/FE 첫 배포

wepick-be, wepick-fe 레포에서 main 브랜치 push 또는 Actions 수동 트리거.
이미지가 ECR에 올라가고 EC2에 배포되면 nginx 502 해소.

---

## Destroy 순서

```bash
cd terraform/envs/prod    && terraform destroy
cd terraform/envs/shared  && terraform destroy
# bootstrap은 tfstate 버킷을 지우므로 완전 초기화 시에만
cd terraform/envs/bootstrap && terraform destroy
```

> ECR에 이미지가 있으면 shared destroy 전에 먼저 삭제해야 한다.
