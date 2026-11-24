# envs/prod

本番環境のルートモジュール。`modules/` を組み立て、環境固有の値だけをここで与える。

## 実行

```sh
export TF_VAR_db_password="$(gcloud secrets versions access latest --secret=sample-ec-db-password)"
terraform init
terraform plan
terraform apply
```

`db_password` は既定値を持たない。Cloud SQL ユーザーのパスワードを `password_wo`
（書き込み専用引数）で渡しており、**state にもプランファイルにも値が残らない**代わりに、
実行のたびに値を外から渡す必要があるため。渡し忘れた場合は対話で入力を求められるか、
`validation` で止まる。

値の正は Secret Manager のシークレット（既定: `sample-ec-db-password`）で、`terraform apply`
の前に手動で作成しておく。アプリのコンテナへは Cloud Run が同じシークレットから直接注入する
（Terraform は経由しない）。

```sh
# 初回のみ。値は Terraform の管理対象ではない
gcloud secrets create sample-ec-db-password --replication-policy=automatic
openssl rand -base64 24 | tr -d '\n' | gcloud secrets versions add sample-ec-db-password --data-file=-
```

変数の既定値は `variables.tf` に入っているため、通常 `terraform.tfvars` は不要。上書きする場合は
`terraform.tfvars.example` をコピーして使う（`*.tfvars` は commit しない）。

state はローカルに置いている。リモート state へ移す場合は `versions.tf` の `backend "gcs"` を有効にし、
値は `backend.hcl`（`backend.hcl.example` 参照）から渡す。

## outputs

| 名前 | 用途 |
| --- | --- |
| `lb_ip_address` | レジストラ / 動作確認で使う LB の静的 IP |
| `dns_name_servers` | レジストラの NS レコードに設定する 4 本 |
| `site_url` | 公開 URL |
| `frontend_bucket_url` | SPA 成果物のアップロード先 |
| `cloud_run_service_uri` | バックエンドの直接 URL（疎通確認用） |
| `ssl_certificate_name` | 証明書のプロビジョニング状態の確認用 |
| `cloudsql_instance_name` | Cloud SQL インスタンス名（接尾辞は apply ごとに変わる） |
| `cloudsql_connection_name` | `gcloud sql connect` / Auth Proxy で DB を覗く際に使う接続名 |

## Cloud SQL

| 項目 | 値 |
| --- | --- |
| エンジン | MySQL 8.4 LTS（ローカルの docker-compose と同一） |
| edition | `ENTERPRISE`（**必須**。8.4 の既定は `ENTERPRISE_PLUS` で、共有コアの tier は Enterprise 限定） |
| tier | `db-f1-micro` / SSD 10GB / `ZONAL` |
| バックアップ | 無効（destroy でインスタンスごと消えるため） |
| 削除保護 | 無効（`deletion_protection` と `settings.deletion_protection_enabled` の両方） |
| データベース / ユーザー | `ecdb` / `ecuser`（`utf8mb4` / `utf8mb4_unicode_ci`） |
| 接続経路 | アプリ同梱の Cloud SQL Java Connector が Cloud SQL Admin API 経由で接続 |

JDBC URL は `main.tf` の `locals.backend_datasource_url` で組み立てている。`cloudSqlInstance` /
`socketFactory` に加えて `cloudSqlRefreshStrategy=lazy` を付けているのは、Cloud Run のように
リクエスト外で CPU がスロットリングされる環境で、既定の `background` だと接続情報の更新が
働かないことがあるため。

パブリック IP は有効だが `authorized_networks` を一つも置いていないため、インターネットから
直接は接続できない（到達には `roles/cloudsql.client` と資格情報が要る）。そのロールは
`cloudsql_iam.tf` が Cloud Run の実行サービスアカウント 1 つにだけ付与している。Cloud SQL には
IAM バインディング用のリソースが無く、プロジェクトレベルでしか付与できないため、
「権限はリソース単位で与える」方針の唯一の例外になっている。
