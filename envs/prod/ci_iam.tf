# GitHub Actions のデプロイ用サービスアカウントに対する権限付与。
#
# サービスアカウント本体は envs/prod-bootstrap が作る（destroy しない state）。ここで行うのは
# 「この state が持つリソースに対して、何をしてよいか」の付与だけ。付与先のバケットや
# Cloud Run サービスは destroy のたびに作り直されるため、その紐づけもここで作り直す。
#
# 権限はプロジェクト全体ではなく、対象のリソース単位で与える。プロジェクトレベルで与えると
# 今後追加される別のリソースにも自動的に権限が及んでしまうため。
#
# 前提: envs/prod-bootstrap を先に apply しておくこと。未適用の場合、下の data 参照が
# 「サービスアカウントが見つからない」というエラーになる。

data "google_service_account" "ci_front" {
  account_id = "github-actions-front"
}

data "google_service_account" "ci_back" {
  account_id = "github-actions-back"
}

# ------------------------------------------------------------
# フロントエンド: SPA をバケットへアップロードする
# ------------------------------------------------------------
# objectViewer ではなく objectAdmin なのは、古いファイルの削除（rsync -d 相当）が必要なため。
resource "google_storage_bucket_iam_member" "ci_front_object_admin" {
  bucket = module.storage.bucket_name
  role   = "roles/storage.objectAdmin"
  member = "serviceAccount:${data.google_service_account.ci_front.email}"
}

# ------------------------------------------------------------
# バックエンド: イメージを push し、Cloud Run へデプロイする
# ------------------------------------------------------------
resource "google_artifact_registry_repository_iam_member" "ci_back_writer" {
  project    = var.project_id
  location   = var.region
  repository = module.artifactregistry.repository_id
  role       = "roles/artifactregistry.writer"
  member     = "serviceAccount:${data.google_service_account.ci_back.email}"
}

resource "google_cloud_run_v2_service_iam_member" "ci_back_developer" {
  name     = module.cloudrun.service_name
  location = module.cloudrun.location
  role     = "roles/run.developer"
  member   = "serviceAccount:${data.google_service_account.ci_back.email}"
}

# Cloud Run のデプロイには「アプリを動かす実行サービスアカウントを使ってよい」権限が要る。
# プロジェクトレベルで付けるとプロジェクト内の全サービスアカウントになりすませてしまうため、
# 実際に使われている実行サービスアカウント 1 つに限定する。
resource "google_service_account_iam_member" "ci_back_act_as_runtime" {
  service_account_id = "projects/${var.project_id}/serviceAccounts/${module.cloudrun.service_account_email}"
  role               = "roles/iam.serviceAccountUser"
  member             = "serviceAccount:${data.google_service_account.ci_back.email}"
}

# rsync は同期を始める前に宛先バケットのメタデータを取得するため storage.buckets.get が要る。
# objectAdmin はオブジェクト単位の権限しか含まないため、バケット自体への読み取り権限を別に与える。
# legacyBucketReader が持つのは storage.buckets.get と storage.objects.list のみで、
# バケットの設定変更や削除はできない。
resource "google_storage_bucket_iam_member" "ci_front_bucket_reader" {
  bucket = module.storage.bucket_name
  role   = "roles/storage.legacyBucketReader"
  member = "serviceAccount:${data.google_service_account.ci_front.email}"
}
