output "repository_id" {
  description = "リポジトリ ID"
  value       = google_artifact_registry_repository.this.repository_id
}

output "repository_url" {
  description = "イメージ URI の接頭辞（<これ>/<イメージ名>:<タグ> の形で使う）"
  value       = "${google_artifact_registry_repository.this.location}-docker.pkg.dev/${google_artifact_registry_repository.this.project}/${google_artifact_registry_repository.this.repository_id}"
}
