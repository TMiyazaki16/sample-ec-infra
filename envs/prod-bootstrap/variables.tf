variable "project_id" {
  description = "GCP プロジェクト ID"
  type        = string
  default     = "ec-site-handson"
}

variable "region" {
  description = "リソースを配置するリージョン"
  type        = string
  default     = "asia-northeast1"
}

variable "github_owner" {
  description = "信頼する GitHub のオーナー"
  type        = string
  default     = "TMiyazaki16"
}

variable "github_repositories" {
  description = "デプロイ用サービスアカウントを作るリポジトリ（キーはサービスアカウント ID の一部になる）"
  type        = map(string)
  default = {
    front = "SampleECSite"
    back  = "SampleECSiteBackend"
  }
}

variable "domain" {
  description = "Cloud DNS で管理するルートドメイン"
  type        = string
  default     = "tmiyazaki-works.com"
}

variable "dns_zone_name" {
  description = "Cloud DNS マネージドゾーンのリソース名（envs/prod からも同じ名前で参照する）"
  type        = string
  default     = "tmiyazaki-works-zone"
}
