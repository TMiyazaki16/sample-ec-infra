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

variable "allow_unauthenticated" {
  description = "未認証の呼び出しを許可するか（ロードバランサ経由で公開するため既定は true）"
  type        = bool
  default     = true
}

variable "h2_console_enabled" {
  description = <<-EOT
    H2 コンソールを有効にするか。アプリ側の既定は "true" で、H2 コンソールは認証なしで
    公開されるため、本番では必ず "false" を渡す（指定しないとアプリ既定の有効状態になる）。
  EOT
  type        = string
  default     = "false"

  validation {
    condition     = contains(["true", "false"], var.h2_console_enabled)
    error_message = "h2_console_enabled には \"true\" または \"false\" を指定する。"
  }
}

variable "allowed_origins" {
  description = "CORS 許可オリジン（カンマ区切りで複数指定可）"
  type        = string
}

variable "max_instance_count" {
  description = <<-EOT
    インスタンス数の上限。アプリが H2 インメモリ DB を使っており、DB がインスタンスごとに
    独立するため 1 を超えると注文データと在庫がインスタンス間で食い違う。Cloud SQL へ
    移行するまで 1 から引き上げられない。
  EOT
  type        = number
  default     = 1

  validation {
    condition     = var.max_instance_count >= 1
    error_message = "max_instance_count は 1 以上で指定する。"
  }
}
