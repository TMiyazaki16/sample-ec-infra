variable "github_owner" {
  description = "信頼する GitHub のオーナー（ユーザーまたは Organization）"
  type        = string
}

variable "repositories" {
  description = <<-EOT
    デプロイ用サービスアカウントを作るリポジトリ。キーはサービスアカウント ID の一部として使う。
    例: { front = "SampleECSite", back = "SampleECSiteBackend" }
  EOT
  type        = map(string)
}

variable "service_account_prefix" {
  description = "サービスアカウント ID の接頭辞"
  type        = string
  default     = "github-actions"
}

variable "pool_id_prefix" {
  description = "Workload Identity Pool ID の接頭辞（実際の ID にはランダムな接尾辞が付く）"
  type        = string
  default     = "github-pool"
}

variable "provider_id" {
  description = "Workload Identity Pool Provider の ID"
  type        = string
  default     = "github-provider"
}
