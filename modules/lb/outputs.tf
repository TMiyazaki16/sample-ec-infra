output "ip_address" {
  description = "払い出されたグローバル静的 IP アドレス"
  value       = google_compute_global_address.lb_ip.address
}

output "ssl_certificate_name" {
  description = "マネージド SSL 証明書のリソース名（状態確認用）"
  value       = google_compute_managed_ssl_certificate.this.name
}
