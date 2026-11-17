output "lb_ip_address" {
  description = "ロードバランサのグローバル静的 IP アドレス"
  value       = module.lb.ip_address
}

output "dns_name_servers" {
  description = "レジストラの NS レコードに設定するネームサーバー（4 本）"
  value       = module.dns.name_servers
}

output "site_url" {
  description = "サイトの公開 URL"
  value       = "https://${var.site_domain}"
}

output "frontend_bucket_url" {
  description = "SPA ビルド成果物のアップロード先"
  value       = module.storage.bucket_url
}

output "cloud_run_service_uri" {
  description = "Cloud Run が払い出す直接 URL（疎通確認用）"
  value       = module.cloudrun.service_uri
}

output "ssl_certificate_name" {
  description = "マネージド SSL 証明書のリソース名（プロビジョニング状態の確認用）"
  value       = module.lb.ssl_certificate_name
}

output "artifact_registry_url" {
  description = "イメージ URI の接頭辞。CI はここへ push する"
  value       = module.artifactregistry.repository_url
}

output "backend_image_uri_example" {
  description = "バックエンドのイメージ URI の例（タグは CI が付ける）"
  value       = "${module.artifactregistry.repository_url}/${var.name_prefix}-back:<tag>"
}

output "front_deploy_sa_email" {
  description = "フロントエンド用デプロイサービスアカウント（本体は envs/prod-bootstrap が管理）"
  value       = data.google_service_account.ci_front.email
}

output "back_deploy_sa_email" {
  description = "バックエンド用デプロイサービスアカウント（本体は envs/prod-bootstrap が管理）"
  value       = data.google_service_account.ci_back.email
}
