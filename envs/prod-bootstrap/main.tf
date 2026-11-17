# 作り直さない前提のリソースを置くルートモジュール。
#
# envs/prod は「普段は destroy してコストを下げ、必要時に apply する」運用だが、
# Workload Identity Pool は次の理由からその運用に乗せられない。
#
#   - 削除後 30 日間ソフトデリート状態で残り、同じ ID で再作成できない
#   - 作っても課金されないため、消しても得が無い
#   - Pool ID が変わるたびに、GitHub 側の設定（2 リポジトリ分）を手で直す必要が生じる
#
# そのため state を分け、ここは一度だけ apply して destroy しない。
#
# 権限（ロール）の付与はここでは行わない。付与先のバケットや Cloud Run サービスは
# envs/prod が destroy のたびに作り直すため、それらに紐づく IAM バインディングも
# 一緒に作り直される必要がある。詳しくは envs/prod/ci_iam.tf を参照。

module "github_oidc" {
  source = "../../modules/github_oidc"

  depends_on = [google_project_service.required]

  github_owner = var.github_owner
  repositories = var.github_repositories
}
