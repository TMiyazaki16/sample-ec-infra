# sample-ec-infra

EC サイト本番環境のインフラを Terraform で管理するリポジトリ。

## ディレクトリ構成

```
envs/
  prod/            環境ごとのルートモジュール（モジュールの組み立てと環境固有値）
  prod-bootstrap/  一度だけ apply し destroy しないリソース（OIDC 連携・DNS ゾーン）
modules/
  artifactregistry/  CI がビルドしたコンテナイメージの置き場
  github_oidc/       GitHub Actions から GCP を操作するための Workload Identity 連携
  dns_zone/    Cloud DNS のゾーンと CAA レコード（destroy しない側）
  dns/         LB の IP を指す A レコード（destroy する側）
  storage/     フロントエンド（SPA）配信用の Cloud Storage バケット
  cloudrun/    バックエンド API の Cloud Run サービス
  cloudsql/    バックエンド API の永続 DB（Cloud SQL for MySQL）
  lb/          外部アプリケーションロードバランサ一式
```

環境を追加する場合は `envs/<env>/` を増やし、`modules/` は共有する。

## 構成の概要

```
          https://<site_domain>
                   │
        [ 外部アプリケーション LB ]
         ├ /api/*  → Cloud Run (バックエンド API) ─→ Cloud SQL (MySQL)
         └ それ以外 → Cloud Storage (SPA)
```

- HTTP(80) は HTTPS(443) へ 301 リダイレクトする。
- SPA のクライアントルーティング対応として、バケットの 404 を 200 + `/index.html` に書き換える。
- 証明書は Google マネージド SSL 証明書を使う。
- JWT の署名鍵と DB パスワードは手動作成済みの Secret Manager シークレットを参照し、Terraform では作成しない。
- DB のスキーマと初期データはアプリ起動時に Flyway が適用する。マイグレーション用の CI ステップは無い。
- Cloud SQL への接続はアプリに同梱した Cloud SQL Java Connector が Cloud SQL Admin API 経由で行う。
  Java は Unix ドメインソケットを扱えないため、Cloud Run のソケットマウントは使っていない。

## 外せない制約

- **Cloud Run のインスタンス数上限は Cloud SQL の接続数で決まる**（現在 `max_instance_count = 2`）。
  H2 インメモリ DB 時代の「1 固定」という制約は Cloud SQL への移行で外れたが、今度は DB 側の
  接続数が上限になる。`db-f1-micro` の `max_connections` は 25 前後で、HikariCP の既定プールは
  1 インスタンスあたり 10 接続のため、2 を超えるなら先に `db_tier` を引き上げる。
- **Cloud SQL インスタンス名にはランダムな接尾辞が付く**。削除した名前をすぐ再利用できるかが
  未確認（旧来「最大 1 週間再利用できない」制約があった）で、これに当たると destroy → apply が
  `409 INSTANCE_ALREADY_EXISTS` で失敗するため、最初から回避している。apply のたびに名前が
  変わるので、`gcloud` で操作する際は `terraform output cloudsql_instance_name` を見る。
- **Cloud SQL のデータは `terraform destroy` で消える**。維持費ゼロを優先した判断で、
  スキーマと初期データはアプリ起動時に Flyway が全自動で適用するため、初期状態の EC サイトは
  完全に復元される。永続化が必要になったら運用方針から見直すこと。
- **DNS ゾーンは `envs/prod` から destroy できない場所にある**。`envs/prod` が管理するのは
  A レコードだけで、ゾーン本体と CAA レコードは `envs/prod-bootstrap` にある。ゾーンを作り直すと
  ネームサーバーが変わり、レジストラ側の再設定と伝播待ちが発生するため。
- **Artifact Registry は Terraform 管理下にある**。`terraform destroy` するとリポジトリごと
  イメージも消えるため、再構築時は CI でイメージをビルドし直す必要がある。

## 使い方

### 初回のみ

`envs/prod-bootstrap` を一度だけ apply する。GitHub Actions の OIDC 連携とデプロイ用
サービスアカウントが入っており、**destroy しない**。

```sh
cd envs/prod-bootstrap
terraform init
terraform apply
```

ここに置いているのは次の 2 つ。どちらも作り直すと外部（GitHub / レジストラ）の設定を
やり直す羽目になるため、destroy / apply サイクルから分離している。

- **Workload Identity 連携**: Pool は削除後 30 日間ソフトデリート状態になり、同じ ID で再作成できない
- **Cloud DNS ゾーンと CAA レコード**: ゾーンを作り直すと割り当てられるネームサーバーが変わり、
  レジストラ側の NS 設定をやり直す必要が生じる

### 通常の構築

DB のパスワードは state に残さないため、環境変数で渡す（未設定だと `plan` / `apply` が
バリデーションで止まる）。

```sh
cd envs/prod
export TF_VAR_db_password="$(gcloud secrets versions access latest --secret=sample-ec-db-password)"
terraform init
terraform plan
terraform apply
```

**Cloud SQL インスタンスの作成には 10〜15 分かかる**。SSL 証明書が `ACTIVE` になるまでの
待ち時間と合わせると、人に見せる 30 分前には apply しておく必要がある。

平時はコスト削減のため `terraform destroy` で全削除し、必要時に `terraform apply` で再構築する運用を想定している。

### apply 後の手順

1. `terraform output dns_name_servers` の 4 本をレジストラのネームサーバーへ設定する。
   **ゾーンは `envs/prod-bootstrap` が持つため、2 回目以降は値が変わらず、この作業は初回だけでよい。**
2. DNS が LB の IP を指したのち、マネージド SSL 証明書が `ACTIVE` になるまで待つ（数十分かかる場合がある）。
3. バックエンドの CI を実行してイメージをビルド・デプロイする。Artifact Registry も destroy 対象のため、
   再構築後はイメージが存在しない状態から始まる。
4. フロントエンドの CI を実行して SPA のビルド成果物をバケットへ配置する。

## GitHub Actions に設定する値

`envs/prod-bootstrap` の output を、各リポジトリの Actions 変数へ設定する。
Pool は destroy しないため、`envs/prod` を作り直しても値は変わらない。

| 値 | 設定先 |
| --- | --- |
| `wif_provider_name` | 両リポジトリ |
| `front_deploy_sa_email` | `SampleECSite` |
| `back_deploy_sa_email` | `SampleECSiteBackend` |

各サービスアカウントへの権限付与は `envs/prod/ci_iam.tf` が行う。対象リソースが destroy で
消えるため、権限もそちらの state 側で作り直す構成にしている。

## 前提

- GCP の各 API は `google_project_service` で有効化する。`envs/prod` と `envs/prod-bootstrap` で
  管理対象が重複しないよう分けている（Cloud DNS API はゾーンを持つ bootstrap 側）。
- Secret Manager のシークレットは手動作成済み（JWT 署名鍵と DB パスワードの 2 つ）。
- 認証は `gcloud auth application-default login` で設定したアプリケーションデフォルト認証情報を使う。
