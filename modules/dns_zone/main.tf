# 外部レジストラから NS 委任を受けるパブリックゾーン。
#
# このモジュールは envs/prod-bootstrap（destroy しない state）から呼ぶ。ゾーンを作り直すと
# 割り当てられるネームサーバーが変わり、そのたびにレジストラ側の設定をやり直す必要が
# 生じるため、destroy / apply を繰り返す envs/prod には置かない。
#
# ネームサーバーは apply 後に outputs.name_servers から取得し、レジストラ側へ登録する。

resource "google_dns_managed_zone" "this" {
  name        = var.zone_name
  dns_name    = "${var.domain}."
  description = "Public zone for ${var.domain}"
  visibility  = "public"
}

# Google マネージド SSL 証明書の発行元を明示する CAA レコード。
# これが無い状態で他社 CAA が存在すると証明書のプロビジョニングが失敗する。
#
# ドメイン単位の静的な宣言で、LB の作り直しとは無関係なためゾーンと同じ state に置く。
resource "google_dns_record_set" "caa" {
  name         = "${var.domain}."
  managed_zone = google_dns_managed_zone.this.name
  type         = "CAA"
  ttl          = var.record_ttl
  rrdatas      = ["0 issue \"pki.goog\""]
}
