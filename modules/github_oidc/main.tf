# GitHub Actions から Google Cloud を操作するための Workload Identity 連携（OIDC）。
#
# サービスアカウントキー（JSON）を発行せずに済ませるための仕組み。GitHub Actions が提示する
# 身分証明（OIDC トークン）を GCP 側が検証し、条件に合えば短命の資格情報を発行する。
# 鍵ファイルが存在しないため、漏洩して永続的に悪用される事故が起きない。
#
# このモジュールは destroy しない前提の state（envs/prod-bootstrap）から呼ぶ。理由は
# google_iam_workload_identity_pool が削除後 30 日間ソフトデリート状態で残り、同じ ID で
# 再作成できないため。万一作り直す必要が生じた場合に備え、Pool ID にはランダムな接尾辞を付ける。

resource "random_id" "pool" {
  byte_length = 4
}

resource "google_iam_workload_identity_pool" "github" {
  workload_identity_pool_id = "${var.pool_id_prefix}-${random_id.pool.hex}"
  display_name              = "GitHub Actions"
  description               = "OIDC federation for GitHub Actions"
}

resource "google_iam_workload_identity_pool_provider" "github" {
  workload_identity_pool_id          = google_iam_workload_identity_pool.github.workload_identity_pool_id
  workload_identity_pool_provider_id = var.provider_id
  display_name                       = "GitHub"

  oidc {
    issuer_uri = "https://token.actions.githubusercontent.com"
  }

  attribute_mapping = {
    "google.subject"             = "assertion.sub"
    "attribute.actor"            = "assertion.actor"
    "attribute.repository"       = "assertion.repository"
    "attribute.repository_owner" = "assertion.repository_owner"
  }

  # この条件を入れないと、どのアカウントの GitHub リポジトリからでもトークンの要求ができてしまう。
  # 実際にサービスアカウントを使うには下の principalSet との一致も必要だが、入口の時点で絞る。
  attribute_condition = "assertion.repository_owner == '${var.github_owner}'"
}

# リポジトリごとのデプロイ用サービスアカウント。
# 権限そのものは付けない（付与先のリソースを持つ側＝envs/prod で、リソース単位に付与する）。
resource "google_service_account" "deployer" {
  for_each = var.repositories

  account_id   = "${var.service_account_prefix}-${each.key}"
  display_name = "GitHub Actions deployer for ${var.github_owner}/${each.value}"
}

# 「このリポジトリの GitHub Actions だけが、このサービスアカウントを使ってよい」という紐付け。
# attribute.repository が完全一致した場合のみ成立するため、別リポジトリからは使えない。
resource "google_service_account_iam_member" "workload_identity_user" {
  for_each = var.repositories

  service_account_id = google_service_account.deployer[each.key].name
  role               = "roles/iam.workloadIdentityUser"
  member             = "principalSet://iam.googleapis.com/${google_iam_workload_identity_pool.github.name}/attribute.repository/${var.github_owner}/${each.value}"
}
