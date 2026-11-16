variable "bucket_name" {
  description = "フロントエンド（SPA）配信用バケットの名前"
  type        = string
}

variable "location" {
  description = "バケットのロケーション"
  type        = string
  default     = "ASIA-NORTHEAST1"
}

variable "index_document" {
  description = "ディレクトリ参照時に返すドキュメント"
  type        = string
  default     = "index.html"
}

variable "force_destroy" {
  description = "オブジェクトが残っていてもバケットを削除できるようにするか"
  type        = bool
  default     = true
}
