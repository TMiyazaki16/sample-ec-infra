# SPA のビルド成果物を置くバケット。ロードバランサのバックエンドバケットとして配信する。

resource "google_storage_bucket" "this" {
  name                        = var.bucket_name
  location                    = var.location
  uniform_bucket_level_access = true

  # 平時は destroy、必要時に apply する運用のため、中身が残っていても削除できるようにする
  force_destroy = var.force_destroy

  website {
    main_page_suffix = var.index_document

    # SPA のクライアントルーティング用。LB を経由しない直接アクセス時のフォールバック
    not_found_page = var.index_document
  }
}

# 静的コンテンツを匿名公開する
resource "google_storage_bucket_iam_member" "public_read" {
  bucket = google_storage_bucket.this.name
  role   = "roles/storage.objectViewer"
  member = "allUsers"
}
