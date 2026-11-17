# Workload Identity 連携に必要な API。
#
# envs/prod の apis.tf とは管理対象が重複しないよう分けている（同じ API を 2 つの state から
# 管理すると互いに上書きし合うため）。この state は destroy しないので、ここで有効化した API は
# 以後そのまま残る。

locals {
  required_services = [
    "cloudresourcemanager.googleapis.com",
    "iam.googleapis.com",
    "iamcredentials.googleapis.com",
    "sts.googleapis.com",
  ]
}

resource "google_project_service" "required" {
  for_each = toset(local.required_services)

  project = var.project_id
  service = each.value

  disable_on_destroy = false
}
