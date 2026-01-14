#!/usr/bin/env python3
"""
AWS ECS Fargate アーキテクチャ図生成スクリプト

使用方法:
    python3 docs/generate_architecture.py

出力:
    docs/images/aws_ecs_architecture.png
    docs/images/network_architecture.png
    docs/images/bluegreen_deployment.png
    docs/images/cicd_pipeline.png
"""

from diagrams import Diagram, Cluster, Edge
from diagrams.aws.compute import ECS, Fargate, Lambda, EC2ContainerRegistry as ECR
from diagrams.aws.network import ALB, NATGateway, InternetGateway, VPC
from diagrams.aws.database import RDS
from diagrams.aws.storage import S3
from diagrams.aws.security import WAF, SecretsManager, SecurityHub, Guardduty
from diagrams.aws.devtools import Codebuild, Codepipeline
from diagrams.aws.management import Cloudwatch, CloudwatchAlarm, Cloudtrail, Config
from diagrams.aws.integration import SNS
from diagrams.generic.network import Firewall
from diagrams.onprem.client import User
from diagrams.onprem.vcs import Github
from diagrams.generic.network import Firewall
from diagrams.onprem.client import User
from diagrams.onprem.vcs import Github

import os

# 出力ディレクトリ作成
os.makedirs("docs/images", exist_ok=True)

# 共通設定
graph_attr = {
    "fontsize": "14",
    "bgcolor": "white",
    "pad": "0.5",
}


def generate_main_architecture():
    """全体アーキテクチャ図を生成"""
    with Diagram(
        "AWS ECS Fargate Web Application Architecture",
        filename="docs/images/aws_ecs_architecture",
        show=False,
        direction="LR",
        graph_attr=graph_attr,
    ):
        user = User("Users")

        with Cluster("AWS Cloud"):
            waf = WAF("WAF\nWeb ACL")

            with Cluster("VPC (10.0.0.0/16)"):
                with Cluster("Public Subnets"):
                    igw = InternetGateway("Internet\nGateway")
                    alb = ALB("Application\nLoad Balancer")
                    nat = NATGateway("NAT\nGateway")

                with Cluster("Private Subnets"):
                    with Cluster("ECS Cluster"):
                        ecs = ECS("ECS Service\nBlue/Green")
                        task1 = Fargate("App1\nTask")
                        task2 = Fargate("App2\nTask")

                    rds1 = RDS("RDS\nApp1 DB")
                    rds2 = RDS("RDS\nApp2 DB")

            # AWSサービス
            ecr = ECR("ECR")
            s3 = S3("S3")
            secrets = SecretsManager("Secrets\nManager")
            cw = Cloudwatch("CloudWatch")

            with Cluster("CI/CD"):
                pipeline = Codepipeline("CodePipeline")
                build = Codebuild("CodeBuild")

            with Cluster("Security & Audit"):
                securityhub = SecurityHub("Security\nHub")
                guardduty = Guardduty("GuardDuty")
                cloudtrail = Cloudtrail("CloudTrail")
                config = Config("AWS\nConfig")

        # 接続
        user >> waf >> alb
        alb >> task1
        alb >> task2
        task1 >> rds1
        task2 >> rds2
        task1 >> Edge(style="dashed") >> ecr
        task1 >> Edge(style="dashed") >> secrets
        task1 >> Edge(style="dashed") >> cw
        nat >> igw
        pipeline >> build >> ecr
        build >> Edge(style="dashed", label="Deploy") >> ecs
        # セキュリティサービス接続
        guardduty >> Edge(style="dashed") >> securityhub
        config >> Edge(style="dashed") >> securityhub


def generate_network_architecture():
    """ネットワーク構成図を生成"""
    with Diagram(
        "Network Architecture",
        filename="docs/images/network_architecture",
        show=False,
        direction="LR",
        graph_attr=graph_attr,
    ):
        user = User("Internet")

        with Cluster("VPC: 10.0.0.0/16"):
            igw = InternetGateway("Internet Gateway")

            with Cluster("Public Subnets"):
                with Cluster("AZ: ap-northeast-1a"):
                    alb = ALB("ALB")
                    nat1 = NATGateway("NAT GW 1")

                with Cluster("AZ: ap-northeast-1c"):
                    nat2 = NATGateway("NAT GW 2")

            with Cluster("Private Subnets"):
                with Cluster("AZ: ap-northeast-1a"):
                    task1 = Fargate("ECS Tasks")
                    rds1 = RDS("RDS Primary")

                with Cluster("AZ: ap-northeast-1c"):
                    task2 = Fargate("ECS Tasks")
                    rds2 = RDS("RDS Standby")

        # 接続
        user >> igw >> alb
        alb >> task1
        alb >> task2
        task1 >> nat1 >> igw
        task2 >> nat2 >> igw
        task1 >> rds1
        task2 >> rds1
        rds1 - Edge(style="dashed", label="Multi-AZ Sync") - rds2


def generate_bluegreen_deployment():
    """Blue/Green デプロイメント図を生成"""
    with Diagram(
        "Blue/Green Deployment",
        filename="docs/images/bluegreen_deployment",
        show=False,
        direction="LR",
        graph_attr=graph_attr,
    ):
        alb = ALB("ALB")

        with Cluster("Listeners"):
            prod = Firewall("Port 80\nProduction")
            test = Firewall("Port 10080\nTest")

        with Cluster("Target Groups"):
            with Cluster("Blue (Current)"):
                blue_tg = ALB("Blue TG")
                blue_task = Fargate("Blue Task\nv1.0")

            with Cluster("Green (New)"):
                green_tg = ALB("Green TG")
                green_task = Fargate("Green Task\nv1.1")

        lambda_fn = Lambda("Validation\nHook")

        # 接続
        alb >> prod >> blue_tg >> blue_task
        alb >> test >> green_tg >> green_task
        lambda_fn >> Edge(label="Health Check") >> green_tg
        lambda_fn >> Edge(style="dashed", label="SUCCEEDED") >> ECS("ECS Service")


def generate_cicd_pipeline():
    """CI/CD パイプライン図を生成
    
    現在の構成:
    - GitHub への push/merge を CodeStar Connection 経由で CodePipeline が直接検知
    - S3 source.zip は使用しない（以前の GitHub Actions → S3 フローは廃止）
    - CodeBuild で Docker イメージをビルドし ECR にプッシュ
    - ECS サービスを更新して Blue/Green デプロイを開始
    """
    with Diagram(
        "CI/CD Pipeline",
        filename="docs/images/cicd_pipeline",
        show=False,
        direction="LR",
        graph_attr=graph_attr,
    ):
        dev = User("Developer")
        github = Github("GitHub")

        with Cluster("AWS"):
            # CodeStar Connection（GitHub と CodePipeline を直接接続）
            with Cluster("CodePipeline"):
                pipeline = Codepipeline("Pipeline\n(CodeStar\nConnection)")

            # アーティファクト保存用 S3（ソース取得後の中間ファイル保存）
            s3 = S3("S3\nArtifacts")

            build = Codebuild("CodeBuild")
            ecr = ECR("ECR")
            ecs = ECS("ECS Service\nBlue/Green")

        # 接続（新しいフロー）
        # Developer が GitHub に push/merge すると、CodePipeline が直接検知
        dev >> github >> Edge(label="push / merge") >> pipeline
        # パイプラインは CodeBuild を起動
        pipeline >> Edge(label="Source") >> s3
        s3 >> build
        # CodeBuild は Docker イメージをビルドして ECR にプッシュ
        build >> Edge(label="docker push") >> ecr
        # CodeBuild から ECS サービスを更新（Blue/Green デプロイ開始）
        build >> Edge(label="update-service") >> ecs


def generate_monitoring():
    """監視・アラート図を生成"""
    with Diagram(
        "Monitoring & Alerting",
        filename="docs/images/monitoring",
        show=False,
        direction="LR",
        graph_attr=graph_attr,
    ):
        with Cluster("Monitored Resources"):
            ecs = ECS("ECS Services")
            alb = ALB("ALB")
            rds = RDS("RDS")

        with Cluster("CloudWatch"):
            cw = Cloudwatch("CloudWatch")
            alarm = CloudwatchAlarm("Alarms")

        sns = SNS("SNS Topic")
        admin = User("Admin")

        # 接続
        ecs >> Edge(label="CPU/Memory") >> cw
        alb >> Edge(label="Requests/5xx") >> cw
        rds >> Edge(label="Connections") >> cw
        cw >> alarm >> sns >> admin


if __name__ == "__main__":
    print("アーキテクチャ図を生成中...")

    print("  1/5 全体アーキテクチャ...")
    generate_main_architecture()

    print("  2/5 ネットワーク構成...")
    generate_network_architecture()

    print("  3/5 Blue/Green デプロイメント...")
    generate_bluegreen_deployment()

    print("  4/5 CI/CD パイプライン...")
    generate_cicd_pipeline()

    print("  5/5 監視・アラート...")
    generate_monitoring()

    print("\n✅ 完了！生成された画像:")
    print("  - docs/images/aws_ecs_architecture.png")
    print("  - docs/images/network_architecture.png")
    print("  - docs/images/bluegreen_deployment.png")
    print("  - docs/images/cicd_pipeline.png")
    print("  - docs/images/monitoring.png")
