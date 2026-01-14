# アーキテクチャ図 - PlantUML版 (Architecture Diagram - PlantUML)

本ドキュメントでは、AWS ECS Fargate Webアプリケーション基盤のアーキテクチャを PlantUML + AWS公式アイコンで記述。

---

## 目次

1. [PlantUML の表示方法](#plantuml-の表示方法)
2. [全体アーキテクチャ（シンプル版）](#1-全体アーキテクチャシンプル版)
3. [ネットワーク構成](#2-ネットワーク構成)
4. [Blue/Green デプロイメント](#3-bluegreen-デプロイメント)
5. [セキュリティグループ](#4-セキュリティグループ)
6. [CI/CD パイプライン](#5-cicd-パイプライン)
7. [監視・アラート](#6-監視・アラート)
8. [PNG への変換方法](#png-への変換方法)
9. [参考リンク](#参考リンク)

---

## PlantUML の表示方法

### 推奨: オンラインサーバーを使用

VS Code の設定で以下を追加（`Cmd + ,` → 右上の「設定(JSON)を開く」）：

```json
{
    "plantuml.server": "https://www.plantuml.com/plantuml",
    "plantuml.render": "PlantUMLServer"
}
```

その後、コードブロック内にカーソルを置いて `Option + D` でプレビュー可能。

---

## 1. 全体アーキテクチャ（シンプル版）

```plantuml
@startuml AWS_ECS_Simple
skinparam linetype ortho
skinparam backgroundColor #FEFEFE

title AWS ECS Fargate Web Application Architecture

actor "User" as user

cloud "Internet" as internet {
}

package "AWS Cloud" {
    package "WAF" {
        [Web ACL] as waf
    }
    
    package "VPC (10.0.0.0/16)" {
        package "Public Subnets" {
            [ALB] as alb
            [NAT Gateway] as nat
            [Internet GW] as igw
        }
        
        package "Private Subnets" {
            package "ECS Cluster" {
                [App1 Task] as task1
                [App2 Task] as task2
            }
            
            database "RDS App1" as rds1
            database "RDS App2" as rds2
        }
    }
    
    [ECR] as ecr
    [S3] as s3
    [Secrets Manager] as secrets
    [CloudWatch] as cw
    
    package "CI/CD" {
        [CodePipeline] as pipeline
        [CodeBuild] as build
    }
    
    package "Security & Audit" {
        [Security Hub] as securityhub
        [GuardDuty] as guardduty
        [CloudTrail] as cloudtrail
        [AWS Config] as config
    }
}

user --> internet
internet --> waf
waf --> alb
alb --> task1 : /app1/*
alb --> task2 : /app2/*
task1 --> rds1
task2 --> rds2
task1 ..> ecr : Pull
task1 ..> secrets
task1 ..> cw : Logs
nat --> igw
build --> ecr
build --> task1 : Deploy

@enduml
```

---

## 2. ネットワーク構成

```plantuml
@startuml Network
skinparam linetype ortho
skinparam backgroundColor #FEFEFE

title Network Architecture

cloud "Internet" as internet

package "VPC: 10.0.0.0/16" {
    [Internet Gateway] as igw
    
    package "Public Subnet (AZ-1a)\n10.0.0.0/20" #LightBlue {
        [ALB] as alb
        [NAT GW 1] as nat1
    }
    
    package "Public Subnet (AZ-1c)\n10.0.16.0/20" #LightBlue {
        [NAT GW 2] as nat2
    }
    
    package "Private Subnet (AZ-1a)\n10.0.32.0/20" #LightGreen {
        [ECS Tasks] as ecs1
        database "RDS Primary" as rds1
    }
    
    package "Private Subnet (AZ-1c)\n10.0.48.0/20" #LightGreen {
        [ECS Tasks] as ecs2
        database "RDS Standby" as rds2
    }
}

internet <--> igw
igw <--> alb
alb --> ecs1
alb --> ecs2
nat1 --> igw
nat2 --> igw
ecs1 --> nat1 : Outbound
ecs2 --> nat2 : Outbound
ecs1 --> rds1
ecs2 --> rds1
rds1 <..> rds2 : Multi-AZ Sync

@enduml
```

---

## 3. Blue/Green デプロイメント

```plantuml
@startuml BlueGreen
skinparam linetype ortho
skinparam backgroundColor #FEFEFE

title Blue/Green Deployment Flow

package "ALB" {
    [Port 80\nProduction] as prod #LightBlue
    [Port 10080\nTest] as test #LightGreen
}

package "Target Groups" {
    [Blue TG] as blueTG #LightBlue
    [Green TG] as greenTG #LightGreen
}

package "ECS Task Sets" {
    [Blue Task\n(v1.0 - Current)] as blueTask #LightBlue
    [Green Task\n(v1.1 - New)] as greenTask #LightGreen
}

[Lambda\nValidation Hook] as lambda

prod --> blueTG : "100%"
test --> greenTG : "Test Traffic"
blueTG --> blueTask
greenTG --> greenTask
lambda --> greenTG : Health Check
lambda ..> greenTask : Validate

note right of greenTask
  After validation:
  1. Shift traffic to Green
  2. Drain Blue
  3. Terminate Blue
end note

@enduml
```

---

## 4. セキュリティグループ

```plantuml
@startuml SecurityGroups
skinparam linetype ortho
skinparam backgroundColor #FEFEFE

title Security Group Configuration

actor "Users" as users

package "ALB SG" #LightBlue {
    [ALB] as alb
}

package "ECS SG" #LightGreen {
    [ECS Tasks] as ecs
}

package "RDS SG" #LightCoral {
    database "RDS" as rds
}

users --> alb : "80, 443, 10080\nfrom 0.0.0.0/0"
alb --> ecs : "80\nfrom ALB SG"
ecs --> rds : "5432\nfrom ECS SG"

note bottom of alb
  Inbound:
  - 80 (HTTP)
  - 443 (HTTPS)
  - 10080 (Test)
end note

note bottom of ecs
  Inbound:
  - 80 from ALB SG only
end note

note bottom of rds
  Inbound:
  - 5432 from ECS SG only
end note

@enduml
```

---

## 5. CI/CD パイプライン

```plantuml
@startuml CICD
skinparam linetype ortho
skinparam backgroundColor #FEFEFE

title CI/CD Pipeline (CodeStar Connection)

actor Developer as dev

package "GitHub" {
    [Repository] as repo
}

package "AWS" {
    [CodeStar\nConnection] as codestar
    
    package "CodePipeline" {
        [Source Stage] as source
        [Build Stage] as buildStage
    }
    
    [S3\nArtifacts] as s3
    [CodeBuild] as codebuild
    [ECR] as ecr
    [ECS Service\nBlue/Green] as ecs
}

dev --> repo : git push / merge
repo --> codestar : Webhook
codestar --> source : Trigger
source --> s3 : Store Source
s3 --> buildStage
buildStage --> codebuild
codebuild --> ecr : docker push
codebuild --> ecs : update-service

note right of codestar
  GitHub Actions は不要
  CodePipeline が直接
  GitHub を監視
end note

@enduml
```

---

## 6. 監視・アラート

```plantuml
@startuml Monitoring
skinparam linetype ortho
skinparam backgroundColor #FEFEFE

title Monitoring & Alerting

package "Resources" {
    [ECS Service] as ecs
    [ALB] as alb
    database "RDS" as rds
}

package "CloudWatch" {
    [Metrics] as metrics
    [Alarms] as alarms
    [Dashboard] as dashboard
    [Logs] as logs
}

[SNS Topic] as sns
actor "Admin" as admin

ecs --> metrics : CPU, Memory
alb --> metrics : Requests, 5xx
rds --> metrics : CPU, Connections
ecs --> logs : Container Logs

metrics --> alarms
metrics --> dashboard
alarms --> sns : Alert
sns --> admin : Email

@enduml
```

---

## PNG への変換方法

### VS Code で変換

1. PlantUML 拡張機能をインストール
2. 設定でオンラインサーバーを有効化（上記参照）
3. コードブロック内にカーソルを置いて `Option + D` でプレビュー
4. `Cmd + Shift + P` → "PlantUML: Export Current Diagram"

### オンラインで変換

1. [PlantUML Server](https://www.plantuml.com/plantuml/uml/) にアクセス
2. コードを貼り付け
3. 生成された画像をダウンロード

---

## 参考リンク

- [AWS Icons for PlantUML (公式)](https://github.com/awslabs/aws-icons-for-plantuml)
- [PlantUML 公式サイト](https://plantuml.com/)
- [AWS Architecture Icons (公式)](https://aws.amazon.com/architecture/icons/)
