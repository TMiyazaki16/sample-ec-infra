output "connection_name" {
  description = "インスタンス接続名（<project>:<region>:<instance>）。Cloud Run のソケットマウントと JDBC URL で使う"
  value       = google_sql_database_instance.this.connection_name
}

output "instance_name" {
  description = "Cloud SQL インスタンス名（ランダムな接尾辞付き。gcloud で操作する際に使う）"
  value       = google_sql_database_instance.this.name
}

output "database_name" {
  description = "作成したデータベース名。JDBC URL の組み立てに使う"
  value       = google_sql_database.this.name
}

output "user_name" {
  description = "アプリが接続に使う MySQL ユーザー名。SPRING_DATASOURCE_USERNAME に渡す"
  value       = google_sql_user.this.name
}
