# 外部アプリケーションロードバランサ（グローバル）。
# 既定はフロントエンドのバケット、/api/* のみ Cloud Run へ振り分ける。

locals {
  # SPA のクライアントルーティング対応。バケットに存在しないパスは 404 になるため、
  # 200 に書き換えたうえでエントリポイントを返し、ルーティングをブラウザ側へ委ねる。
  spa_error_response = {
    match_response_codes   = ["404"]
    path                   = var.spa_entry_path
    override_response_code = 200
  }
}

# ------------------------------------------------------------
# フロントエンド IP
# ------------------------------------------------------------
resource "google_compute_global_address" "lb_ip" {
  name       = "${var.name_prefix}-lb-ip"
  ip_version = "IPV4"
}

# ------------------------------------------------------------
# バックエンド: Cloud Run（API）
# ------------------------------------------------------------
resource "google_compute_region_network_endpoint_group" "api" {
  name                  = "${var.name_prefix}-neg"
  region                = var.backend_region
  network_endpoint_type = "SERVERLESS"

  cloud_run {
    service = var.cloud_run_service_name
  }
}

resource "google_compute_backend_service" "api" {
  name                  = "${var.name_prefix}-backend-service"
  protocol              = "HTTP"
  load_balancing_scheme = "EXTERNAL_MANAGED"

  backend {
    group = google_compute_region_network_endpoint_group.api.id
  }
}

# ------------------------------------------------------------
# バックエンド: Cloud Storage（SPA）
# ------------------------------------------------------------
resource "google_compute_backend_bucket" "frontend" {
  name        = "${var.name_prefix}-frontend-bucket"
  bucket_name = var.frontend_bucket_name
  enable_cdn  = var.enable_cdn
}

# ------------------------------------------------------------
# ルーティング（HTTPS）
# ------------------------------------------------------------
resource "google_compute_url_map" "https" {
  name            = "${var.name_prefix}-url-map"
  default_service = google_compute_backend_bucket.frontend.id

  default_custom_error_response_policy {
    error_response_rule {
      match_response_codes   = local.spa_error_response.match_response_codes
      path                   = local.spa_error_response.path
      override_response_code = local.spa_error_response.override_response_code
    }
    error_service = google_compute_backend_bucket.frontend.id
  }

  host_rule {
    hosts        = [var.site_domain]
    path_matcher = "${var.name_prefix}-path-matcher"
  }

  path_matcher {
    name            = "${var.name_prefix}-path-matcher"
    default_service = google_compute_backend_bucket.frontend.id

    # ホストが一致した経路も同じ SPA フォールバックを通す
    default_custom_error_response_policy {
      error_response_rule {
        match_response_codes   = local.spa_error_response.match_response_codes
        path                   = local.spa_error_response.path
        override_response_code = local.spa_error_response.override_response_code
      }
      error_service = google_compute_backend_bucket.frontend.id
    }

    path_rule {
      paths   = ["/api/*"]
      service = google_compute_backend_service.api.id
    }
  }
}

# ------------------------------------------------------------
# HTTPS フロントエンド
# ------------------------------------------------------------
# マネージド証明書は DNS が LB の IP を指してから ACTIVE になる（数十分かかる場合がある）
resource "google_compute_managed_ssl_certificate" "this" {
  name = "${var.name_prefix}-ssl-cert"

  managed {
    domains = [var.site_domain]
  }

  lifecycle {
    create_before_destroy = true
  }
}

resource "google_compute_target_https_proxy" "this" {
  name             = "${var.name_prefix}-https-proxy"
  url_map          = google_compute_url_map.https.id
  ssl_certificates = [google_compute_managed_ssl_certificate.this.id]
}

resource "google_compute_global_forwarding_rule" "https" {
  name                  = "${var.name_prefix}-https-forwarding-rule"
  target                = google_compute_target_https_proxy.this.id
  ip_address            = google_compute_global_address.lb_ip.id
  port_range            = "443"
  load_balancing_scheme = "EXTERNAL_MANAGED"
}

# ------------------------------------------------------------
# HTTP フロントエンド（HTTPS へリダイレクト）
# ------------------------------------------------------------
resource "google_compute_url_map" "http_redirect" {
  name = "${var.name_prefix}-http-redirect-map"

  default_url_redirect {
    https_redirect         = true
    redirect_response_code = "MOVED_PERMANENTLY_DEFAULT"
    strip_query            = false
  }
}

resource "google_compute_target_http_proxy" "this" {
  name    = "${var.name_prefix}-http-proxy"
  url_map = google_compute_url_map.http_redirect.id
}

resource "google_compute_global_forwarding_rule" "http" {
  name                  = "${var.name_prefix}-http-forwarding-rule"
  target                = google_compute_target_http_proxy.this.id
  ip_address            = google_compute_global_address.lb_ip.id
  port_range            = "80"
  load_balancing_scheme = "EXTERNAL_MANAGED"
}
