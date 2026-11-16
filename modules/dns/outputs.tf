output "zone_name" {
  description = "作成したマネージドゾーンのリソース名"
  value       = google_dns_managed_zone.this.name
}

output "name_servers" {
  description = "ゾーンに割り当てられたネームサーバー（レジストラの NS 設定に登録する）"
  value       = google_dns_managed_zone.this.name_servers
}
