# wepick-infra

wepick 서비스의 AWS 인프라 및 배포를 관리하는 레포지토리입니다.

## 구조

```
terraform/      인프라 코드 (IaC)
docker/         앱 스택 설정 (docker-compose, nginx)
.github/        CI/CD 워크플로우
docs/           전략 및 운영 문서
```

## 문서

- [IaC 전략](docs/iac-strategy.md) — Terraform 관리 방식, 상태 관리, 재현성
- [CI/CD 전략](docs/cicd-strategy.md) — 배포 파이프라인, 트리거, 알림

## 빠른 시작

초기 설정은 [IaC 전략](docs/iac-strategy.md#초기-설정)을 참고하세요.
