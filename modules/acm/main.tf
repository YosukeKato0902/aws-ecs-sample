# -----------------------------------------------------------------------------
# ACM（AWS Certificate Manager）モジュール
# このモジュールは、SSL/TLS証明書のリクエスト、Route 53を使用した
# DNS検証レコードの自動作成、および証明書の有効化（検証完了待ち）を定義する。
# -----------------------------------------------------------------------------

# -----------------------------------------------------------------------------
# ACM証明書本体
# -----------------------------------------------------------------------------
resource "aws_acm_certificate" "main" {
  domain_name               = var.domain_name               # メインドメイン名
  subject_alternative_names = var.subject_alternative_names # 追加のドメイン（サブドメイン等）
  validation_method         = "DNS"                         # 検証方式としてDNSを選択

  # 証明書の更新時に新しい証明書を先に作成し、ダウンタイムを防止する設定
  lifecycle {
    create_before_destroy = true
  }

  tags = {
    Name = "${var.project_name}-${var.environment}-certificate"
  }
}

# -----------------------------------------------------------------------------
# DNS検証レコード (Route 53 使用時)
# ACMから提示された検証用のCNAMEレコードをRoute 53に登録する
# -----------------------------------------------------------------------------
resource "aws_route53_record" "validation" {
  for_each = var.create_route53_records ? {
    # 複数のドメインがある場合に対応するため、ループ処理でレコードを作成
    for dvo in aws_acm_certificate.main.domain_validation_options : dvo.domain_name => {
      name   = dvo.resource_record_name
      record = dvo.resource_record_value
      type   = dvo.resource_record_type
    }
  } : {}

  allow_overwrite = true # 既存のレコードがある場合の上書きを許可
  name            = each.value.name
  records         = [each.value.record]
  ttl             = 60 # キャッシュ生存時間を短めに設定
  type            = each.value.type
  zone_id         = var.route53_zone_id # 登録先のホストゾーンID
}

# -----------------------------------------------------------------------------
# 証明書検証の完了待機
# DNSレコードの伝播を確認し、ACM証明書が「発行済み」になるまで待機する
# -----------------------------------------------------------------------------
resource "aws_acm_certificate_validation" "main" {
  count                   = var.create_route53_records ? 1 : 0
  certificate_arn         = aws_acm_certificate.main.arn                                # 検証対象の証明書ARN
  validation_record_fqdns = [for record in aws_route53_record.validation : record.fqdn] # 参照する検証レコード
}
