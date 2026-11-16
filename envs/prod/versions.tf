terraform {
  required_version = ">= 1.5.0"

  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 6.0"
    }
  }

  # state はローカルに置く。リモート state を使う場合はここに backend "gcs" を定義し、
  # 値は backend.hcl から渡す（backend.hcl.example 参照）。
}
