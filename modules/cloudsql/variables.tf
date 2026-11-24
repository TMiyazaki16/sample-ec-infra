variable "instance_name_prefix" {
  description = "Cloud SQL インスタンス名の接頭辞（実際の名前にはランダムな接尾辞が付く）"
  type        = string
}

variable "region" {
  description = "Cloud SQL インスタンスを配置するリージョン"
  type        = string
}

variable "tier" {
  description = "インスタンスのマシンタイプ。db-f1-micro は最小構成（接続数の上限が低い点に注意）"
  type        = string
  default     = "db-f1-micro"
}

variable "disk_size" {
  description = "データディスクのサイズ（GB）。自動拡張は無効にしているため、足りなければここを上げる"
  type        = number
  default     = 10

  validation {
    condition     = var.disk_size >= 10
    error_message = "disk_size は 10 以上で指定する（Cloud SQL の最小値）。"
  }
}

variable "database_name" {
  description = "作成するデータベース名。アプリの JDBC URL と一致させる"
  type        = string
}

variable "user_name" {
  description = "アプリが接続に使う MySQL ユーザー名"
  type        = string
}

variable "db_password" {
  description = <<-EOT
    MySQL ユーザーのパスワード。Secret Manager に手動作成済みの値を apply 時に渡す。

    ephemeral にしているのは state とプランファイルに値を残さないため。Terraform では
    シークレットの値を読み出さない方針だが、google provider 6.x に Secret Manager の
    ephemeral リソースが無いため、data ソースで読む（= state に平文で残る）代わりに
    外から渡す形にしている。渡し方は envs/prod/README.md を参照。
  EOT
  type        = string
  sensitive   = true
  ephemeral   = true

  validation {
    condition     = length(var.db_password) >= 8
    error_message = "db_password が未設定か短すぎる。Secret Manager の値を環境変数で渡しているか確認する（envs/prod/README.md を参照）。"
  }
}

variable "password_wo_version" {
  description = <<-EOT
    パスワードの世代番号。password_wo は値が state に残らない代わりに Terraform が変更を
    検知できないため、稼働中のインスタンスでシークレットの値を変えた場合はこの数値を
    上げて初めて反映される。destroy / apply で作り直す運用では触る必要がない。
  EOT
  type        = number
  default     = 1
}
