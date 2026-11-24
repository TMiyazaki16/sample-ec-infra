# バックエンド API の永続 DB（Cloud SQL for MySQL）。
#
# このモジュールは envs/prod（平時 destroy する側）から呼ぶ。envs/prod-bootstrap には置かない。
# あちらは「作り直すと外部（GitHub / レジストラ）の設定をやり直す羽目になるもの」だけを置く
# state で、Cloud SQL はその条件に当てはまらないため。
#
# destroy のたびにデータは消えるが、スキーマと初期データの適用はアプリ起動時に Flyway が
# 全自動で行うため、真っさらなインスタンスから初期状態が復元される。この前提があるので
# バックアップも取らない。
#
# インスタンス名にランダムな接尾辞を付けるのは、削除した名前をすぐ再利用できるかが未確認のため。
# Cloud SQL には旧来「削除した名前は最大 1 週間再利用できない」制約があり、これに当たると
# destroy → apply が 409 INSTANCE_ALREADY_EXISTS で失敗して「見せたいときに apply」が
# 成立しなくなる。modules/github_oidc の Pool ID と同じ回避策。

resource "random_id" "instance" {
  byte_length = 4
}

resource "google_sql_database_instance" "this" {
  name = "${var.instance_name_prefix}-${random_id.instance.hex}"
  # ローカルの docker-compose と揃える。8.0 は 2027-01-01 に Cloud SQL の標準サポートが切れ、
  # 以降は有償の拡張サポート扱いになるため 8.4 LTS を使う。
  # 8.4 への移行はアプリ無改修で動くことをローカルで検証済み（MyBatis の手書き SQL・
  # 楽観ロック・ページング・シードの冪等性まで確認）。
  database_version = "MYSQL_8_4"
  region           = var.region

  # 平時は destroy する運用のため削除保護を外す。
  # この引数は既定値が true で、明示的に false にしないと terraform destroy が失敗する。
  deletion_protection = false

  settings {
    # MySQL 8.4 の既定の edition は ENTERPRISE_PLUS だが、db-f1-micro などの共有コアは
    # ENTERPRISE 限定。明示しないと apply が失敗するか、桁違いに高い edition で作られる。
    edition = "ENTERPRISE"

    tier              = var.tier
    availability_type = "ZONAL"
    disk_type         = "PD_SSD"
    disk_size         = var.disk_size

    # 自動拡張されると意図しない課金につながるため止める（容量が要るなら disk_size を上げる）
    disk_autoresize = false

    # 上の deletion_protection とは別物。あちらは Terraform 側の安全装置、こちらは
    # Cloud SQL API 側の保護フラグで、両方外れていないと destroy できない。
    deletion_protection_enabled = false

    backup_configuration {
      # destroy でインスタンスごと消える運用のためバックアップは取らない
      enabled = false
    }

    ip_configuration {
      # パブリック IP は有効のままにする。Cloud Run からは /cloudsql の Unix ドメインソケット
      # 経由で接続するが、その実体は Cloud SQL Auth による接続で IP 経路自体は必要になる。
      # authorized_networks を一つも置いていないため、インターネットから直接は接続できない
      # （到達には roles/cloudsql.client と資格情報が要る）。
      ipv4_enabled = true

      # 暗号化されていない接続を拒否する
      ssl_mode = "ENCRYPTED_ONLY"
    }
  }
}

resource "google_sql_database" "this" {
  name     = var.database_name
  instance = google_sql_database_instance.this.name

  # ローカルの docker-compose（mysql:8.4）と揃える
  charset   = "utf8mb4"
  collation = "utf8mb4_unicode_ci"
}

resource "google_sql_user" "this" {
  name     = var.user_name
  instance = google_sql_database_instance.this.name

  # 書き込み専用引数。値は state にもプランファイルにも記録されない。
  # 値の供給元は ephemeral な入力変数（variables.tf の db_password を参照）。
  #
  # 引き換えに Terraform はパスワードの変更を検知できないため、稼働中のインスタンスで値を
  # 回すには password_wo_version を手で上げる必要がある。平時 destroy する運用では apply の
  # たびにインスタンスごと作り直され、その時点の値で作成されるため実害はない。
  password_wo         = var.db_password
  password_wo_version = var.password_wo_version
}
