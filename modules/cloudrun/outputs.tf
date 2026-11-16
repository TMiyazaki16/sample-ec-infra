output "service_name" {
  description = "Cloud Run サービス名"
  value       = google_cloud_run_v2_service.this.name
}

output "location" {
  description = "Cloud Run サービスのリージョン"
  value       = google_cloud_run_v2_service.this.location
}

output "service_uri" {
  description = "Cloud Run が払い出す直接 URL（疎通確認用）"
  value       = google_cloud_run_v2_service.this.uri
}
