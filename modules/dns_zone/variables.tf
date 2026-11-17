variable "zone_name" {
  description = "Cloud DNS マネージドゾーンのリソース名"
  type        = string
}

variable "domain" {
  description = "管理するルートドメイン（末尾ドットなし）"
  type        = string
}

variable "record_ttl" {
  description = "レコードの TTL（秒）"
  type        = number
  default     = 300
}
