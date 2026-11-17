output "pool_name" {
  description = "Workload Identity Pool のリソース名"
  value       = google_iam_workload_identity_pool.github.name
}

output "provider_name" {
  description = "GitHub Actions の google-github-actions/auth に設定する provider のリソース名"
  value       = google_iam_workload_identity_pool_provider.github.name
}

output "service_account_emails" {
  description = "作成したデプロイ用サービスアカウントのメールアドレス（キーは repositories と同じ）"
  value       = { for k, sa in google_service_account.deployer : k => sa.email }
}
