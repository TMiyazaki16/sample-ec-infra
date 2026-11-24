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

variable "db_name" {
  description = "Cloud SQL に作成するデータベース名（ローカルの docker-compose と揃える）"
  type        = string
  default     = "ecdb"
}

variable "db_user_name" {
  description = "アプリが接続に使う MySQL ユーザー名（ローカルの docker-compose と揃える）"
  type        = string
  default     = "ecuser"
}

variable "db_password" {
  description = <<-EOT
    DB ユーザーのパスワード。既定値を持たせず、apply 時に環境変数で渡す:
      export TF_VAR_db_password="$(gcloud secrets versions access latest --secret=sample-ec-db-password)"

    ephemeral なので state にもプランファイルにも残らない。値そのものは db_password_secret_id の
    シークレットが正で、Cloud Run へはそちらから直接注入される（Terraform を経由しない）。
  EOT
  type        = string
  sensitive   = true
  ephemeral   = true
}

variable "db_password_secret_id" {
  description = "手動作成済みの Secret Manager シークレット ID（DB ユーザーのパスワード）"
  type        = string
  default     = "sample-ec-db-password"
}

variable "db_tier" {
  description = "Cloud SQL インスタンスのマシンタイプ。引き上げる場合は max_instance_count も見直す"
  type        = string
  default     = "db-f1-micro"
}
