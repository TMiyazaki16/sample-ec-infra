# Cloud Run の実行サービスアカウントに Cloud SQL への接続を許可する。
#
# ここだけ「権限はプロジェクトレベルではなくリソース単位で与える」という本リポジトリの方針の
# 例外になる。Cloud SQL インスタンスには IAM バインディング用のリソースが存在せず
# （google_sql_database_instance に IAM の子リソースが無い）、roles/cloudsql.client は
# プロジェクトレベルでしか付与できないため。
#
# 影響範囲を狭めるため、付与先は Cloud Run の実行サービスアカウント 1 つに限定している。
# このロールが持つのはインスタンスへの接続権限だけで、インスタンスやデータの操作はできない。
resource "google_project_iam_member" "runtime_cloudsql_client" {
  project = var.project_id
  role    = "roles/cloudsql.client"
  member  = "serviceAccount:${module.cloudrun.service_account_email}"
}
