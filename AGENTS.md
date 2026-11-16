# リポジトリガイドライン

## プロジェクト概要

EC サイトの Google Cloud インフラ（IaC）。アプリコードは置かない。

- フロントエンド（SPA）: Cloud Storage
- バックエンド API: Cloud Run
- 公開経路: 外部アプリケーションロードバランサ（`/api/*` のみ Cloud Run、それ以外は Storage）
- DNS: Cloud DNS（レジストラから NS 委任）

構成の概要と運用手順は `README.md`、環境固有の値と outputs は `envs/prod/README.md` を正とする。

## ディレクトリ構成

- `envs/<env>/` — 環境ごとのルートモジュール。モジュールの組み立てと環境固有値だけを置く
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
- Cloud Run の `max_instance_count` は 1 に固定する。バックエンドが H2 インメモリ DB を使っており、2 インスタンス以上でデータが食い違うため。Cloud SQL へ移行するまで引き上げない。同様に `H2_CONSOLE_ENABLED` は `"false"` を明示する（アプリ既定は `"true"` で、H2 コンソールが認証なしで公開される）
- Artifact Registry も destroy の対象。イメージごと消えるため、再構築後はデプロイ前に CI でのビルドが必要
- Cloud Run のコンテナイメージは CI がデプロイする。`lifecycle { ignore_changes = [...image] }` を外さない
- マネージド SSL 証明書は DNS が LB の IP を指すまで `ACTIVE` にならない。apply 直後に 502 や証明書エラーが出ても異常とは限らない

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
