output "wif_provider_name" {
  description = "GitHub Actions の google-github-actions/auth に設定する workload_identity_provider の値"
  value       = module.github_oidc.provider_name
}

output "front_deploy_sa_email" {
  description = "フロントエンド用デプロイサービスアカウントのメールアドレス"
  value       = module.github_oidc.service_account_emails["front"]
}

output "back_deploy_sa_email" {
  description = "バックエンド用デプロイサービスアカウントのメールアドレス"
  value       = module.github_oidc.service_account_emails["back"]
}

output "dns_zone_name" {
  description = "マネージドゾーンのリソース名（envs/prod の dns_zone_name と一致させる）"
  value       = module.dns_zone.zone_name
}

output "dns_name_servers" {
  description = "レジストラ（GoDaddy）のネームサーバーに設定する 4 本。この state を destroy しない限り変わらない"
  value       = module.dns_zone.name_servers
}
