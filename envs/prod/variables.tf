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

variable "name_prefix" {
  description = "リソース名の接頭辞"
  type        = string
  default     = "sample-ec"
}

variable "domain" {
  description = "Cloud DNS で管理するルートドメイン"
  type        = string
  default     = "tmiyazaki-works.com"
}

variable "site_domain" {
  description = "サイトを公開するサブドメイン（FQDN）"
  type        = string
  default     = "sample-ec-site.tmiyazaki-works.com"
}

variable "dns_zone_name" {
  description = "Cloud DNS マネージドゾーンのリソース名"
  type        = string
  default     = "tmiyazaki-works-zone"
}

variable "frontend_bucket_name" {
  description = "フロントエンド（SPA）配信用バケット名"
  type        = string
  default     = "tmiyazaki-works-frontend"
}

variable "frontend_bucket_location" {
  description = "フロントエンド配信用バケットのロケーション"
  type        = string
  default     = "ASIA-NORTHEAST1"
}

variable "jwt_secret_id" {
  description = "手動作成済みの Secret Manager シークレット ID（JWT 署名鍵）"
  type        = string
  default     = "sample-ec-jwt-secret"
}
