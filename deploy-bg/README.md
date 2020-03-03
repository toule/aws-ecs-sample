# AWS ECS CI/CD Sample Test (Blue/Green Update)

## 가정 상황

- 앞서 진행한 ECS 클러스터(Sample-cluster)를 기반으로 진행
- 현 문서에서 role 혹은 설정이 없는 것은 이전 문서에 있는 값을 그대로 가져옴
- 루트 디렉토리에서 my-nginx와 my-tomcat을 **<u>현 디렉토리에 복사</u>**해야함
- CI/CD 파이프라인 구성은 다음 [예제](https://github.com/toule/aws-cicd-sample)를 참조

## 준비 사항

### IAM

#### ECS Task Role

- Role name: ecsTaskExecutionRole
- Attach permissions policies
  - AmazonECSTaskExecutionRolePolicy

![ecs-role](/Users/ray/Documents/Test/Container/ECS/webwas/nginx-sample/images/ecs-role.png)

