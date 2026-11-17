variable "zone_name" {
  description = "レコードを作成する既存の Cloud DNS マネージドゾーン名（modules/dns_zone が作る）"
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
