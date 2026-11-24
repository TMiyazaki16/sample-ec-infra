# リポジトリガイドライン

## プロジェクト概要

EC サイトの Google Cloud インフラ（IaC）。アプリコードは置かない。

- フロントエンド（SPA）: Cloud Storage
- バックエンド API: Cloud Run
- 公開経路: 外部アプリケーションロードバランサ（`/api/*` のみ Cloud Run、それ以外は Storage）
- DNS: Cloud DNS（レジストラから NS 委任）。ゾーンは `envs/prod-bootstrap`、A レコードは `envs/prod`

構成の概要と運用手順は `README.md`、環境固有の値と outputs は `envs/prod/README.md` を正とする。

## ディレクトリ構成

- `envs/<env>/` — 環境ごとのルートモジュール。モジュールの組み立てと環境固有値だけを置く
- `envs/prod-bootstrap/` — 一度だけ apply し **destroy しない** state。作り直すと外部（GitHub / レジストラ）の設定をやり直す羽目になるものを置く。現在は Workload Identity Pool（削除後 30 日は同じ ID で再作成できない）と Cloud DNS ゾーン（作り直すとネームサーバーが変わる）。ここへ destroy を提案しない
- `modules/<機能>/` — 再利用するモジュール。`main.tf` / `variables.tf` / `outputs.tf` / `versions.tf` の 4 点を揃える

モジュール側にドメイン名・プロジェクト ID・バケット名を直書きしない。必ず変数で受け、既定値は `envs/<env>/variables.tf` に置く。

## 開発コマンド

ホストに terraform が無い場合は `.terraform-version` と同じ版を入れる。

```sh
cd envs/prod
terraform fmt -recursive ../..   # 整形（リポジトリ全体）
terraform init
terraform validate               # 認証情報なしで通る
terraform plan                   # ADC が必要
```

- 認証は `gcloud auth application-default login` で設定するアプリケーションデフォルト認証情報を使う
- Terraform の版数は 2 か所にある。**実行する版**の正は `.terraform-version`、**許容する版**は各 `versions.tf` の `required_version`。上げるときは両方を揃える

## 運用の前提

- コスト削減のため、平時は `terraform destroy` で全削除し、必要時に `terraform apply` で再構築する。この前提があるため、バケットは `force_destroy = true`、Cloud Run は `deletion_protection = false` にしている。外す提案をするときはこの運用との整合を先に確認する
- Secret Manager のシークレットは手動作成済み。Terraform では `data` で参照するだけで、作成・更新・値の読み出しをしない
- Cloud Run の `max_instance_count` の上限は Cloud SQL の接続数で決まる。`db-f1-micro` の `max_connections` は 25 前後、HikariCP の既定プールは 1 インスタンスあたり 10 接続のため、2 を超えるなら先に `db_tier` を上げる（H2 インメモリ DB 時代の「1 固定」という制約は 2026-11-24 の Cloud SQL 移行で解消済み。`H2_CONSOLE_ENABLED` も同時に廃止した）
- Cloud SQL への接続はアプリに同梱した Cloud SQL Java Connector が Cloud SQL Admin API 経由で行う。Java は Unix ドメインソケットを扱えないため、Cloud Run のソケットマウント（`volumes` / `volume_mounts`）は使わない。代わりに実行サービスアカウントへの `roles/cloudsql.client` が必須
- Cloud SQL のインスタンス名には `random_id` の接尾辞が付く。`terraform state show` ではなく `terraform output cloudsql_instance_name` で実際の名前を確認する
- DB パスワードは `password_wo`（書き込み専用引数）で渡すため、`plan` / `apply` の前に `TF_VAR_db_password` の設定が必要。手順は `envs/prod/README.md` を正とする
- GitHub Actions のデプロイ用サービスアカウントは `envs/prod-bootstrap` が作り、権限付与は `envs/prod/ci_iam.tf` が行う。権限はプロジェクトレベルではなくリソース単位で与える（プロジェクトレベルにすると、今後追加されるリソースにも自動的に及ぶため）
- Artifact Registry も destroy の対象。イメージごと消えるため、再構築後はデプロイ前に CI でのビルドが必要
- Cloud Run のコンテナイメージは CI がデプロイする。`lifecycle { ignore_changes = [...] }` を外さない。無視しているのはイメージと、`gcloud run deploy` が付与する `client` / `client_version`（デプロイ元のツール名）。後者は CI が動くたびに再発するため、無視しないと plan に毎回ノイズが出る
- マネージド SSL 証明書は DNS が LB の IP を指すまで `ACTIVE` にならない。apply 直後に 502 や証明書エラーが出ても異常とは限らない
- DNS ゾーンと CAA レコードは `envs/prod-bootstrap`、A レコードは `envs/prod` にある。A レコードが指す IP は再構築のたびに変わるが、ネームサーバーは変わらないのでレジストラ側の作業は初回だけでよい。この分割を崩す変更（ゾーンを `envs/prod` へ戻すなど）は提案しない

## AI開発ルール

### 人間確認が必要なとき

次に該当したら、実装に入らず前提・選択肢・影響を提示して確認を待つ。

- `terraform apply` / `terraform destroy` / state の手動改変（`state rm`、`import` を含む）
- 既存リソースの置換（静的 IP、DNS ゾーン、バケット）を伴う変更。IP やネームサーバーが変わると外部設定のやり直しが必要になる
- 新規モジュールの追加、新しい GCP サービスの導入、環境の追加
- 公開範囲が広がる変更（`allUsers` への権限付与、ingress の緩和）
- 依頼スコープを超える変更（無関係なモジュールのリファクタ、アプリリポジトリの変更）
- 3 ファイル以上または複数モジュールにまたがる変更 → 先に計画（変更対象 / README の更新要否 / 検証方針 / リスク）を提示する

### そのまま進めてよいとき

既存モジュールのパターンに沿った変数・`validation`・コメント・ドキュメントの追加。置いた仮定は作業報告に明記する。パスやリソース名は実在を確認してから参照する。

### 明示依頼なしでは実行しない

- **`git commit`（コミット）** / `git push` / force push / `git reset --hard` / `git rebase -i`
- `terraform.tfvars`、`backend.hcl`、`.env`、プロジェクト ID 以外の認証情報の作成・変更・コミット
- シークレット値の出力・ログ出力・ファイルへの書き出し

### 変更時チェックリスト

1. `terraform fmt -recursive` が差分なし
2. `terraform validate` が成功
3. 可能なら `terraform plan` を実行し、置換（`-/+`）や削除が意図どおりか確認する
4. リソース名・変数名・outputs を変えたら `README.md` と `envs/<env>/README.md` を更新する
5. 新しい outputs は用途を `description` に書く

### 報告

実行したコマンドと結果、置いた仮定、確認が必要な事項を明記する。plan を実行できなかった場合はその理由も書く。未実施の手順を実施済みと書かない。
