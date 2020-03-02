# AWS ECS(Elastic Container Service) Sample Test

## 가정 상황

- Container에 대한 기본적인 지식을 가지고 있음
- AWS에 대한 기초적인 지식을 가지고 있음
- 리전: Seoul (ap-northeast-2)

## 참고 사항

- 환경: macOS Catalina Version 10.15.3
- 비용이 발생할 수 있음
- CI/CD -> ECS 배포 : deploy-ecs ***(현재 작업 중)***
- CI/CD -> CodeDeploy 배포(Blue/Green) : deploy-bg ***(현재 작업 중)***

## 아키텍처 (Architecture)

![arch](./images/arch.png)

## 사전 설정

### VPC

- Default VPC를 활용

### NAT Gateway

- ECS 인스턴스는 Private Subnet에 위치하기 때문에 ECS Agent와 ECS Management Engine과 통신하기 위해 NAT Gateway가 필요

![nat](./images/natgateway.png)

### IAM Role

- name : ecsInstanceRole

![iam-role-1](./images/ecsInstanceRole.png)

### Secret Group

#### Load Balancer Security Goup

- name: WEB-LB (로드 밸런서의 SG 설정)
- Inbound: HTTP (TCP: 80)

![iam1](./images/lb-sg.png)

#### ECS Instance Security Goup

- name: ECS-Instance-SG
- Inbound: Custom TCP Rule(TCP: 32768-65535, Dynamic Porting), SSH(TCP: 22)

![iam2](./images/ECS-SG.png)

### Load Balancer

#### ECS Nginx Load Balancer (External)

##### Load Balancer Type (Select: Application Load Balancer)

![alb-1](./images/alb-type.png)

##### WEB(NGINX)

###### ALB Configure

- name: ECS-Nginx-ALB
- Scheme: Internet-facing
- IP address type: ipv4
- Listeners: HTTP
- VPC: Default VPC
- Available Zones: Public Subnet (A,B,C)
- Security Goups : http-lb-sg (custom-sg)

![alb-2](./images/alb-conf.png)

###### Target Configure

- name: ECS-Nginx-tg
- Target type: Instance
- Protocol: HTTP (port: 80)
- Register Target: Pass

![alb-3](./images/tg-conf.png)

##### WAS (Tomcat)

###### ALB Configure

- name: ECS-Tomcat-ALB
- Scheme: Internal
- IP address type: ipv4
- Listeners: HTTP
- VPC: Default VPC
- Available Zones: Private Subnet (A,B,C)
- Security Goups : http-lb-sg (custom-sg)

###### Target Configure

- name: ECS-Tomcat-tg
- Target type: Instance
- Protocol: HTTP (port: 80)
- Register Target: Pass

## ECR(Elastic Container Registry)

### Custom Nginx Container

#### Path

```tex
folder path : ./my-nginx (Do not paste!!!)
```

##### Dockerfile

- nginx로 들어오는 트래픽을 tomcat으로 proxy

```dockerfile
FROM nginx:latest
MAINTAINER Ray.H.Li <lhs6395@gmail.com>

COPY default.conf /etc/nginx/conf.d/default.conf

EXPOSE 80
```

- Internal DNS 확인

```bash
aws elbv2 describe-load-balancers | jq -r '.[][1].DNSName'
-> internal-ECS-Tomcat-ALB-1760153505.ap-northeast-2.elb.amazonaws.com (Do not Paste!!!)
```

- 문자열 교환 (제대로 되지 않는 경우 수동으로 바꿔줘야함): tomcat-internal-dns -> ALB internal DNS

```bash
sed -i '' "s/tomcat-internal-dns/$(aws elbv2 describe-load-balancers | jq -r '.[][1].DNSName')/g" default.conf
```

- default.conf

![ECS-Cluster-1](./images/default-conf.png)

### Nginx Repository

```bash
aws ecr create-repository --repository-name my-nginx --image-scanning-configuration scanOnPush=true
```

- Build Container

```bash
docker build -t my-nginx:v1 .
```

- 계정 확인

```bash
export Account=$(aws sts get-caller-identity | jq -r .Account)
```

- ECR 로그인

```bash
aws ecr get-login-password | docker login --username AWS --password-stdin $Account.dkr.ecr.ap-northeast-2.amazonaws.com/my-nginx
```

- ECR Container Push

```bash
docker tag my-nginx:v1 $Account.dkr.ecr.ap-northeast-2.amazonaws.com/my-nginx:v1
```

```bash
docker push $Account.dkr.ecr.ap-northeast-2.amazonaws.com/my-nginx:v1
```

### Custom Tomcat Container

#### Path

```tex
folder path : ./my-tomcat (Do not paste!!!)
```

##### Dockerfile

- tomcat default 구동

```dockerfile
FROM tomcat:latest
MAINTAINER Ray.H.Li <lhs6395@gmail.com>

RUN cp -a webapps.dist/* webapps/
RUN ./bin/startup.sh

EXPOSE 8080
```

### Tomcat Repository

```bash
aws ecr create-repository --repository-name my-tomcat --image-scanning-configuration scanOnPush=true
```

- Build Container

```bash
docker build -t my-tomcat:v1 .
```

- 계정 확인 (이전에서 했다면 하지 않아도 됨)

```bash
export Account=$(aws sts get-caller-identity | jq -r .Account)
```

- ECR 로그인 (이전에서 했다면 하지 않아도 됨)

```bash
aws ecr get-login-password | docker login --username AWS --password-stdin $Account.dkr.ecr.ap-northeast-2.amazonaws.com/my-nginx
```

- ECR Container Push

```bash
docker tag my-tomcat:v1 $Account.dkr.ecr.ap-northeast-2.amazonaws.com/my-tomcat:v1
```

```bash
docker push $Account.dkr.ecr.ap-northeast-2.amazonaws.com/my-tomcat:v1
```

## TASK Definition

- Console (ECS -> Task Definition -> Create new Task Definition)
- launch type compatibility: EC2

### Configure task and container definitions

#### Nginx

- Task Definition Name: web-task
- Network Mode: Bridge

![nginx-task](./images/web-task-1.png)

### Container Definition

#### Add container

- Container name: nginx-container
- Image: {my-account-id}.dkr.ecr.ap-northeast-2.amazonaws.com/my-nginx:v1
- Memory Limits (Soft limit): 300
- Port mappings: (Host port: 0), (Container port: 80), Protocol(tcp)

![add-container](./images/container-conf.png)

#### Tomcat

- Task Definition Name: was-task
- Network Mode: Bridge

![tomcat-task](./images/was-task-1.png)

### Container Definition

#### Add container

- Container name: tomcat-container
- Image: {my-account-id}.dkr.ecr.ap-northeast-2.amazonaws.com/my-nginx:v1
- Memory Limits (Soft limit): 300
- Port mappings: (Host port: 0), (Container port: 8080), Protocol(tcp)

![add-container](./images/tomcat-container.png)



## ECS Cluster 생성

- Select cluster template : EC2 Linux + Networking (가장 기본적인 인스턴스 기반으로 동작하는 것으로 진행)
- Cluster name: Sample-cluster
- Provisioning Model : On-Demand Instance
- EC2 Instance type: t3.medium
- Number of instances: 1
- 나머지: Default

![ECS-Cluster-1](./images/configure-cluster-1.png)

- VPC: Default VPC
- Subnet: Private Subnet (인스턴스를 private subnet에 배치)
- Security group: ECS-Insatnce-SG

![ECS-Cluster-2](./images/configure-cluster-2.png)

- Container instance IAM role: ecsInstanceRole

- CloudWatch Container Insights: Enable

  ![ECS-Cluster-3](./images/configure-cluster-3.png)

## Service 생성

### Nginx Service

- Lauch type: EC2
- Task Definition: web-task
- Service name: nginx-SVC
- Service type: REPLICA
- Number of tasks: 3

![nginx-SVC-1](./images/nginx-svc-conf-1.png)

- 참고사항
  - Minimum healthy percent: 배포시 Running 상태를 유지해야하는 서비스 내 작업수에 대한 하한을 원하는 작업수에 대한 백분율로 지정 -> 50%인경우 원하는 태스크가 4개일 때 새로운 태스크가 2개가 올라올때 2개를 내려서 용량을 확보할 수 있음(가까운 정수로 올림)
  - Maximum healthy percent: 배포시 Running 또는 Pending 상태가 허용되는 서비스 내 작업 수에 대해 상한선을 지정 -> 200%인 경우 태스크가 4개이면 기존 작업을 중지하기전에 4개까지 동작시킬 수 있음 (스케쥴링 과정에서 늘어날 수 있는 태스크 수를 지정, 가까운 정수로 내림)

- Rolling update: Enable
- Placement Templates: AZ Balanced Spread

![nginx-SVC-2](./images/nginx-svc-conf-2.png)



- Load balancer type: Application Load Balancer
- Service IAM role: ecsServiceRole (사전에 만든 IAM Role)
- Load balancer name: ECS-Nginx-ALB (사전에 만든 ALB)

![nginx-SVC-3](./images/nginx-svc-conf-3.png)



- Production listener port: 80:HTTP
- Target Group: ECS-Nginx-tg (사전에 만든 Target Group)
- Service discovery: Disabled
- AutoScaling: Disabled

![nginx-SVC-4](./images/nginx-svc-conf-4.png)

### Tomcat Service

- Lauch type: EC2
- Task Definition: was-task
- Service name: tomcat-SVC
- Service type: REPLICA
- Number of tasks: 4
- Rolling update: Enable
- Placement Templates: AZ Balanced Spread
- Load balancer type: Application Load Balancer
- Service IAM role: ecsServiceRole (사전에 만든 IAM Role)
- Load balancer name: ECS-Tomcat-ALB (사전에 만든 ALB)
- Production listener port: 80:HTTP
- Target Group: ECS-Tomcat-tg (사전에 만든 Target Group)
- Service discovery: Disabled
- AutoScaling: Disabled



## Result

### Target Group 확인 (ex: Nginx)

![result-tg](./images/result-tg.png)

### ALB DNS 확인

![result-browser](./images/result.png)



### 추가: CloudWatch Container Insight

#### Overview

![overview](./images/insight-overview.png)

#### Task Overview

- View application logs
- View AWS X-Ray traces (사전에 정의 필요)
- View performance logs

![insight-1](./images/task-logs-overview.png)

![insight-2](./images/task-logs.png)

![insight-2](./images/task-logs-1.png)

## 인프라 삭제

### Service 삭제

- nginx-SVC deleted
- tomcat-SVC deleted

### Cluster 삭제

![delete-cluster](./images/delete-cluster.png)

### Load Balancer(Application Load Balancer) 삭제

#### Load Balancer

- ECS-Nginx-ALB -> Actions -> Delete
- ECS-Tomcat-ALB -> Actions -> Delete

#### Target Group 삭제

- ECS-Nginx-tg -> Actions -> Delete
- ECS-Tomcat-tg -> Actions -> Delete

### ECR 삭제

- my-nginx -> Delete

![delete-ecr](./images/delete-ecr.png)

- my-tomcat -> Delete

### NAT Gateway 삭제

- Default-NAT -> Actions -> Delete NAT Gateway
- Elatic IPs -> Actions -> Release addresses (NAT Gateway를 설치하면서 만들었던 eip release)

### Secret Group 삭제

- LB-SG (Group Name: http-lb-sg) -> Actions -> Delete Security Group
- ECS-Instance-SG (Group Name: ecs instance sg) -> Actions -> Delete Security Group

### IAM Role 삭제

- ecsInstanceRole -> Delete role