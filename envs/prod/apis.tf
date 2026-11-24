# この構成が必要とする GCP API。
#
# 手動で有効化済みの想定だが、1 つでも漏れると apply が 403 で途中失敗するため、コードで
# 明示する。すでに有効な API に対しては何も起きない（既存の有効化状態を取り込むだけ）。
#
# disable_on_destroy = false にしているのは、平時は destroy する運用のため。destroy のたびに
# API を無効化すると、再 apply のたびに有効化の伝播待ちが発生し、他の構成にも影響しうる。

# dns.googleapis.com はゾーンを持つ envs/prod-bootstrap 側で有効化する（二重管理を避けるため）。

locals {
  required_services = [
    "artifactregistry.googleapis.com",
    "compute.googleapis.com",
    "run.googleapis.com",
    "secretmanager.googleapis.com",
    "sqladmin.googleapis.com",
    "storage.googleapis.com",
  ]
}

resource "google_project_service" "required" {
  for_each = toset(local.required_services)

  project = var.project_id
  service = each.value

  disable_on_destroy = false
}
