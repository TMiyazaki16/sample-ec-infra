output "zone_name" {
  description = "マネージドゾーンのリソース名（レコードを作る側が managed_zone に指定する）"
  value       = google_dns_managed_zone.this.name
}

output "name_servers" {
  description = "ゾーンに割り当てられたネームサーバー（レジストラの NS 設定に登録する）"
  value       = google_dns_managed_zone.this.name_servers
}
