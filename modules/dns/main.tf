# サイト公開用のレコード。
#
# ゾーン本体は modules/dns_zone（envs/prod-bootstrap 側）が持つ。A レコードが指す IP は
# ロードバランサを作り直すたびに変わるため、レコードだけを envs/prod 側に置き、
# LB と同じライフサイクルで作り直す。

resource "google_dns_record_set" "site" {
  name         = "${var.site_domain}."
  managed_zone = var.zone_name
  type         = "A"
  ttl          = var.record_ttl
  rrdatas      = [var.lb_ip_address]
}
