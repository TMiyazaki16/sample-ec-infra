output "site_record_name" {
  description = "作成した A レコードの名前（末尾ドット付き）"
  value       = google_dns_record_set.site.name
}
