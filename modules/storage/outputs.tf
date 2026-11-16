output "bucket_name" {
  description = "作成したバケット名"
  value       = google_storage_bucket.this.name
}

output "bucket_url" {
  description = "バケットの gs:// URL（成果物アップロード先）"
  value       = google_storage_bucket.this.url
}
