# バックエンド API。ロードバランサの /api/* から serverless NEG 経由で到達する。

data "google_project" "this" {}

# Terraform では作成せず、手動作成済みのシークレットを参照する
data "google_secret_manager_secret" "jwt" {
  secret_id = var.jwt_secret_id
}

# Cloud Run のサービスエージェントにシークレット読み取りを許可する。
# これが無いとリビジョンの起動時にシークレット解決で失敗する。
resource "google_secret_manager_secret_iam_member" "jwt_accessor" {
  secret_id = data.google_secret_manager_secret.jwt.id
  role      = "roles/secretmanager.secretAccessor"
  member    = "serviceAccount:service-${data.google_project.this.number}@serverless-robot-prod.iam.gserviceaccount.com"
}

resource "google_cloud_run_v2_service" "this" {
  name     = var.service_name
  location = var.location
  ingress  = "INGRESS_TRAFFIC_ALL"

  # 平時は destroy する運用のため、削除保護は外しておく
  deletion_protection = false

  # サービスレベルの scaling（template.scaling とは別物）。設定しないと API が返す既定値と
  # 設定の差が毎回 plan に出続けるため、既定値どおりの内容を明示して差分を消す。
  scaling {
    min_instance_count = 0
  }

  template {
    # H2 インメモリ DB のため 1 を超えられない（modules/cloudrun/variables.tf の説明を参照）
    scaling {
      max_instance_count = var.max_instance_count
    }

    containers {
      image = var.initial_image

      ports {
        container_port = var.container_port
      }

      # アプリ側の既定は "true"。認証なしで DB を操作できてしまうため本番では無効にする
      env {
        name  = "H2_CONSOLE_ENABLED"
        value = var.h2_console_enabled
      }

      env {
        name  = "ALLOWED_ORIGINS"
        value = var.allowed_origins
      }

      env {
        name = "JWT_SECRET"
        value_source {
          secret_key_ref {
            secret  = data.google_secret_manager_secret.jwt.secret_id
            version = "latest"
          }
        }
      }
    }
  }

  # CI がデプロイした本番イメージを Terraform が初期イメージへ巻き戻さないようにする。
  #
  # client / client_version は「最後にデプロイしたツール」を GCP 側が記録するメタデータで、
  # CI が gcloud run deploy を実行するたびに付与される。無視しないと CI が動くたびに
  # plan へ差分が出続け、本当に見るべき差分が埋もれる。どちらも CI の責任範囲に属する。
  lifecycle {
    ignore_changes = [
      template[0].containers[0].image,
      client,
      client_version,
    ]
  }

  depends_on = [google_secret_manager_secret_iam_member.jwt_accessor]
}

# 未認証アクセスを許可（アクセス制御はロードバランサ側で行う）
resource "google_cloud_run_v2_service_iam_member" "public_invoker" {
  count = var.allow_unauthenticated ? 1 : 0

  name     = google_cloud_run_v2_service.this.name
  location = google_cloud_run_v2_service.this.location
  role     = "roles/run.invoker"
  member   = "allUsers"
}
