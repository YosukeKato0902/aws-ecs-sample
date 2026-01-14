import json
import logging
import os
import boto3
import urllib.request
import urllib.error

# ログ設定
logger = logging.getLogger()
logger.setLevel(logging.INFO)

def lambda_handler(event, context):
    """
    ECS Blue/Green Deployments ライフサイクルフック検証関数
    """
    logger.info(f"Received event: {json.dumps(event)}")

    # イベントから必要な情報を取得
    try:
        # ECSデプロイメントIDやライフサイクルイベントトークンなどはイベントに含まれるが、
        # 組み込みBlue/GreenではhookStatusを返すだけで良い
        
        # 検証対象のURL (環境変数から取得)
        # 本番環境ではALBのDNS名などを設定想定だが、テストリスナーのポート指定が必要
        # 例: http://my-alb.ap-northeast-1.elb.amazonaws.com:10080/app1/health
        validation_url = os.environ.get('VALIDATION_URL')
        
        if not validation_url:
            logger.error("VALIDATION_URL environment variable is not set")
            return {"hookStatus": "FAILED"}

        logger.info(f"Validating URL: {validation_url}")

        # HTTPリクエストによるヘルスチェック
        req = urllib.request.Request(validation_url)
        with urllib.request.urlopen(req, timeout=30) as response:
            status_code = response.getcode()
            logger.info(f"Response status code: {status_code}")

            if 200 <= status_code < 300:
                logger.info("Validation successful")
                return {"hookStatus": "SUCCEEDED"}
            else:
                logger.error(f"Validation failed with status code: {status_code}")
                return {"hookStatus": "FAILED"}

    except urllib.error.URLError as e:
        logger.error(f"HTTP request failed: {e}")
        return {"hookStatus": "FAILED"}
    except Exception as e:
        logger.error(f"Unexpected error: {e}")
        return {"hookStatus": "FAILED"}
