# envs/prod

本番環境のルートモジュール。`modules/` を組み立て、環境固有の値だけをここで与える。

## 実行

```sh
terraform init
terraform plan
terraform apply
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
