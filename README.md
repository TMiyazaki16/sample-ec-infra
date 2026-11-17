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
  lb/          外部アプリケーションロードバランサ一式
```

環境を追加する場合は `envs/<env>/` を増やし、`modules/` は共有する。

## 構成の概要

```
          https://<site_domain>
                   │
        [ 外部アプリケーション LB ]
         ├ /api/*  → Cloud Run (バックエンド API)
         └ それ以外 → Cloud Storage (SPA)
```

- HTTP(80) は HTTPS(443) へ 301 リダイレクトする。
- SPA のクライアントルーティング対応として、バケットの 404 を 200 + `/index.html` に書き換える。
- 証明書は Google マネージド SSL 証明書を使う。
- JWT の署名鍵は手動作成済みの Secret Manager シークレットを参照し、Terraform では作成しない。

## 外せない制約

- **Cloud Run のインスタンス数上限は 1 に固定している**（`max_instance_count = 1`）。
  バックエンドが H2 インメモリ DB を使っており、DB がインスタンスごとに独立するため、
  2 インスタンス以上に増えると注文データと在庫がインスタンス間で食い違う。
  負荷が上がっても引き上げられない。解除するには Cloud SQL など外部データベースへの移行が必要。
- **DNS ゾーンは `envs/prod` から destroy できない場所にある**。`envs/prod` が管理するのは
  A レコードだけで、ゾーン本体と CAA レコードは `envs/prod-bootstrap` にある。ゾーンを作り直すと
  ネームサーバーが変わり、レジストラ側の再設定と伝播待ちが発生するため。
- **Artifact Registry は Terraform 管理下にある**。`terraform destroy` するとリポジトリごと
  イメージも消えるため、再構築時は CI でイメージをビルドし直す必要がある。
- **`H2_CONSOLE_ENABLED` は `"false"` を明示的に渡している**。アプリ側の既定値は `"true"` で、
  H2 コンソールは認証なしで公開されるため、渡さないと誰でもブラウザから DB を操作できる状態になる。

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

```sh
cd envs/prod
terraform init
terraform plan
terraform apply
```

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
- Secret Manager のシークレットは手動作成済み。
- 認証は `gcloud auth application-default login` で設定したアプリケーションデフォルト認証情報を使う。
