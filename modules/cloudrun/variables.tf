variable "service_name" {
  description = "Cloud Run サービス名"
  type        = string
}

variable "location" {
  description = "Cloud Run サービスを配置するリージョン"
  type        = string
}

variable "initial_image" {
  description = "初期コンテナイメージ。実際のアプリイメージは CI からデプロイする"
  type        = string
  default     = "us-docker.pkg.dev/cloudrun/container/hello"
}

variable "container_port" {
  description = "コンテナが待ち受けるポート"
  type        = number
  default     = 8080
}

variable "jwt_secret_id" {
  description = "手動作成済みの Secret Manager シークレット ID（JWT 署名鍵）"
  type        = string
}

variable "db_password_secret_id" {
  description = "手動作成済みの Secret Manager シークレット ID（DB ユーザーのパスワード）"
  type        = string
}

variable "datasource_url" {
  description = <<-EOT
    SPRING_DATASOURCE_URL に渡す JDBC URL。必要な接続パラメータがアプリ側の依存ライブラリで
    変わる（Cloud SQL Java Connector のプロパティを含む）ため、組み立ては env 側に置く。
  EOT
  type        = string
}

variable "datasource_username" {
  description = "SPRING_DATASOURCE_USERNAME に渡す DB ユーザー名"
  type        = string
}

variable "allow_unauthenticated" {
  description = "未認証の呼び出しを許可するか（ロードバランサ経由で公開するため既定は true）"
  type        = bool
  default     = true
}

variable "allowed_origins" {
  description = "CORS 許可オリジン（カンマ区切りで複数指定可）"
  type        = string
}

variable "max_instance_count" {
  description = <<-EOT
    インスタンス数の上限。Cloud SQL への移行により「H2 インメモリ DB がインスタンスごとに
    独立する」という 1 固定の制約は外れたが、今度は DB 側の接続数が上限になる。
    db-f1-micro の max_connections は 25 前後で、HikariCP の既定プールは 1 インスタンス
    あたり 10 接続のため、2 を超えるなら先に Cloud SQL の tier を上げること。
  EOT
  type        = number
  default     = 2

  validation {
    condition     = var.max_instance_count >= 1
    error_message = "max_instance_count は 1 以上で指定する。"
  }
}
