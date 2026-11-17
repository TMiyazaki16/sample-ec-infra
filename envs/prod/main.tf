# EC サイト本番環境のルートモジュール。
#
# コスト削減のため平時は terraform destroy で全削除し、必要時に apply で再構築する運用を
# 前提にしている。そのためバケットは force_destroy、Cloud Run は deletion_protection = false。
#
# 依存の向き:
#   storage ─┐
#            ├→ lb ─→ dns（A レコードが LB の静的 IP を指す）
#   cloudrun ┘
#
#   DNS ゾーンは envs/prod-bootstrap 側にある。ゾーンを作り直すとネームサーバーが変わり、
#   レジストラ側の再設定が必要になるため、destroy の対象に含めていない。
#
#   artifactregistry は他から参照されない。CI がビルドしたイメージの置き場で、
#   Cloud Run へのデプロイは CI が行う（Terraform は image を ignore_changes にしている）。

module "storage" {
  source = "../../modules/storage"

  depends_on = [google_project_service.required]

  bucket_name = var.frontend_bucket_name
  location    = var.frontend_bucket_location
}

module "artifactregistry" {
  source = "../../modules/artifactregistry"

  depends_on = [google_project_service.required]

  repository_id = var.name_prefix
  location      = var.region
  description   = "Container images for ${var.name_prefix}"
}

module "cloudrun" {
  source = "../../modules/cloudrun"

  # このモジュールには depends_on を付けない。付けるとモジュール内の data 読み取りが apply 時まで
  # 遅延し、値が未知になって Secret Manager の IAM バインディングが毎回再作成される
  # （一時的に権限が外れる）。API が未有効の場合は data 読み取りの時点で失敗するため、
  # 有効化漏れに気づけなくなるわけではない。

  service_name  = "${var.name_prefix}-back"
  location      = var.region
  jwt_secret_id = var.jwt_secret_id

  # 以下 2 つはモジュールの既定値と同じだが、渡し忘れても fmt / validate / plan が通り、
  # 静かに危険な本番ができてしまう項目なので env 側で明示する。
  #   h2_console_enabled: アプリ既定は "true"（認証なしで DB を操作できる）
  #   max_instance_count: H2 インメモリ DB のため 1 を超えるとデータが食い違う
  h2_console_enabled = "false"
  max_instance_count = 1

  # 同一オリジン構成のため本番では CORS は発生しないが、Cloud Run のサービス URL へ
  # 直接アクセスする場合に備えて設定する。ドメインを二重管理しないよう site_domain から組み立てる。
  allowed_origins = "https://${var.site_domain}"
}

module "lb" {
  source = "../../modules/lb"

  depends_on = [google_project_service.required]

  name_prefix            = var.name_prefix
  site_domain            = var.site_domain
  backend_region         = var.region
  cloud_run_service_name = module.cloudrun.service_name
  frontend_bucket_name   = module.storage.bucket_name
}

# ゾーン本体と CAA レコードは envs/prod-bootstrap が持つ（destroy で消さないため）。
# ここで作るのは LB の IP を指す A レコードだけ。
#
# 前提: envs/prod-bootstrap を先に apply しておくこと。未適用の場合、下の data 参照が
# 「ゾーンが見つからない」というエラーになる。
data "google_dns_managed_zone" "site" {
  name = var.dns_zone_name
}

module "dns" {
  source = "../../modules/dns"

  depends_on = [google_project_service.required]

  zone_name     = var.dns_zone_name
  site_domain   = var.site_domain
  lb_ip_address = module.lb.ip_address
}
