variable "repository_id" {
  description = "Artifact Registry のリポジトリ ID"
  type        = string
}

variable "location" {
  description = "リポジトリを配置するリージョン"
  type        = string
}

variable "description" {
  description = "リポジトリの説明"
  type        = string
  default     = "Container images"
}
