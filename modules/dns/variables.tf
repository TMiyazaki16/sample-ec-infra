variable "zone_name" {
  description = "Cloud DNS マネージドゾーンのリソース名"
  type        = string
}

variable "domain" {
  description = "管理するルートドメイン（末尾ドットなし）"
  type        = string
}

variable "site_domain" {
  description = "A レコードを作成するサイトの FQDN（末尾ドットなし）"
  type        = string
}

variable "lb_ip_address" {
  description = "A レコードが指すロードバランサのグローバル静的 IP"
  type        = string
}

variable "record_ttl" {
  description = "レコードの TTL（秒）"
  type        = number
  default     = 300
}
