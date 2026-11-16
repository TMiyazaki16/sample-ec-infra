# CI がビルドしたコンテナイメージの置き場。
#
# 注意: このリポジトリは Terraform 管理下にあるため、terraform destroy すると
# 格納しているイメージごと削除される。再構築するときは CI でイメージをビルドし直してから
# Cloud Run へデプロイする必要がある（Cloud Run 自体も destroy で消えるため、
# 再構築後は初期イメージの状態から始まる）。

resource "google_artifact_registry_repository" "this" {
  repository_id = var.repository_id
  location      = var.location
  format        = "DOCKER"
  description   = var.description
}
