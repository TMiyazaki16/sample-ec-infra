# 外部レジストラから NS 委任を受けるパブリックゾーン。
# ネームサーバーは apply 後に outputs.name_servers から取得し、レジストラ側へ登録する。

resource "google_dns_managed_zone" "this" {
  name        = var.zone_name
  dns_name    = "${var.domain}."
  description = "Public zone for ${var.domain}"
  visibility  = "public"
}

# サイト公開用の A レコード（ロードバランサの静的 IP を指す）
resource "google_dns_record_set" "site" {
  name         = "${var.site_domain}."
  managed_zone = google_dns_managed_zone.this.name
  type         = "A"
  ttl          = var.record_ttl
  rrdatas      = [var.lb_ip_address]
}

# Google マネージド SSL 証明書の発行元を明示する CAA レコード。
# これが無い状態で他社 CAA が存在すると証明書のプロビジョニングが失敗する。
resource "google_dns_record_set" "caa" {
  name         = "${var.domain}."
  managed_zone = google_dns_managed_zone.this.name
  type         = "CAA"
  ttl          = var.record_ttl
  rrdatas      = ["0 issue \"pki.goog\""]
}
