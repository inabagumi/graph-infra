terraform {
  cloud {
    organization = "inabagumi"

    workspaces {
      name = "graph-infra"
    }
  }

  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "4.59.0"
    }

    google-beta = {
      source  = "hashicorp/google-beta"
      version = "4.59.0"
    }

    github = {
      source  = "integrations/github"
      version = "5.19.0"
    }

    helm = {
      source  = "hashicorp/helm"
      version = "2.9.0"
    }

    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "2.19.0"
    }
  }
}

provider "google" {
  project = var.project
  region  = var.region
}

provider "google-beta" {
  project = var.project
  region  = var.region
}

provider "github" {
  owner = var.repo_owner
}

provider "helm" {
  kubernetes {
    cluster_ca_certificate = base64decode(module.gke.ca_certificate)
    host                   = "https://${module.gke.endpoint}"
    token                  = data.google_client_config.default.access_token
  }
}

provider "kubernetes" {
  cluster_ca_certificate = base64decode(module.gke.ca_certificate)
  host                   = "https://${module.gke.endpoint}"
  token                  = data.google_client_config.default.access_token
}

locals {
  db_name                   = "grafana"
  master_auth_subnetwork    = "${local.name}-master-subnet"
  name                      = "graph"
  network_name              = "${local.name}-network"
  pods_range_name           = "ip-range-pods-${local.name}"
  subnet_name               = "${local.name}-subnet"
  subnet_names              = [for subnet_self_link in module.vpc.subnets_self_links : split("/", subnet_self_link)[length(split("/", subnet_self_link)) - 1]]
  svc_range_name            = "ip-range-svc-${local.name}"
  telegraf_image_repository = "${var.region}-docker.pkg.dev/${var.project}/containers/telegraf"
}

data "google_client_config" "default" {}

resource "google_service_account" "gha" {
  account_id   = "github-actions"
  description  = "Service Account for GitHub Actions"
  display_name = "GitHub Actions"
  project      = var.project
}

resource "google_service_account" "tempo" {
  account_id   = "grafana-tempo"
  description  = "Service Account for Grafana Tempo"
  display_name = "Grafana Tempo"
  project      = var.project
}

resource "google_service_account" "grafana" {
  account_id   = "grafana"
  description  = "Service Account for Grafana"
  display_name = "Grafana"
  project      = var.project
}

resource "google_service_account_iam_member" "tempo" {
  member             = "serviceAccount:${var.project}.svc.id.goog[default/tempo]"
  role               = "roles/iam.workloadIdentityUser"
  service_account_id = google_service_account.tempo.name
}

resource "google_service_account_iam_member" "grafana" {
  member             = "serviceAccount:${var.project}.svc.id.goog[default/grafana]"
  role               = "roles/iam.workloadIdentityUser"
  service_account_id = google_service_account.grafana.name
}

module "gh_oidc" {
  source  = "terraform-google-modules/github-actions-runners/google//modules/gh-oidc"
  version = "3.1.1"

  pool_id               = "${var.repo_name}-pool"
  project_id            = var.project
  provider_display_name = "GitHub"
  provider_id           = "github"
  sa_mapping = {
    (google_service_account.gha.account_id) = {
      attribute = "attribute.repository/${var.repo_owner}/${var.repo_name}"
      sa_name   = google_service_account.gha.name
    }
  }
}

module "vpc" {
  source  = "terraform-google-modules/network/google"
  version = "6.0.1"

  network_name = local.network_name
  project_id   = var.project
  secondary_ranges = {
    (local.subnet_name) = [
      {
        range_name    = local.pods_range_name
        ip_cidr_range = "192.168.0.0/18"
      },
      {
        range_name    = local.svc_range_name
        ip_cidr_range = "192.168.64.0/18"
      },
    ]
  }
  subnets = [
    {
      subnet_name   = local.subnet_name
      subnet_ip     = "10.0.0.0/17"
      subnet_region = var.region
    },
    {
      subnet_name   = local.master_auth_subnetwork
      subnet_ip     = "10.60.0.0/17"
      subnet_region = var.region
    },
  ]
}

resource "google_compute_global_address" "default" {
  name = "${local.name}-ip"
}

resource "google_dns_managed_zone" "default" {
  name     = "${local.name}-zone"
  dns_name = "21g.social."
}

resource "google_dns_record_set" "www" {
  name = "www.${google_dns_managed_zone.default.dns_name}"
  type = "A"
  ttl  = 300

  managed_zone = google_dns_managed_zone.default.name

  rrdatas = [google_compute_global_address.default.address]
}

resource "google_dns_record_set" "frontend" {
  name = google_dns_managed_zone.default.dns_name
  type = "A"
  ttl  = 300

  managed_zone = google_dns_managed_zone.default.name

  rrdatas = [google_compute_global_address.default.address]
}

module "mysql-db" {
  source  = "GoogleCloudPlatform/sql-db/google//modules/mysql"
  version = "14.1.0"

  availability_type = "ZONAL"
  backup_configuration = {
    binary_log_enabled             = true
    enabled                        = true
    location                       = "asia"
    retained_backups               = 7
    retention_unit                 = "COUNT"
    start_time                     = "20:00"
    transaction_log_retention_days = 7
  }
  database_flags = [
    {
      name  = "sql_mode"
      value = "ONLY_FULL_GROUP_BY,NO_ZERO_IN_DATE,NO_ZERO_DATE,ERROR_FOR_DIVISION_BY_ZERO,NO_ENGINE_SUBSTITUTION"
    },
  ]
  database_version    = "MYSQL_5_7"
  disk_autoresize     = false
  disk_size           = 10
  disk_type           = "PD_SSD"
  deletion_protection = true
  enable_default_db   = false
  enable_default_user = false
  ip_configuration = {
    ipv4_enabled        = false
    private_network     = module.vpc.network_id
    require_ssl         = false
    allocated_ip_range  = null
    authorized_networks = []
  }
  maintenance_window_day          = 1
  maintenance_window_hour         = 4
  maintenance_window_update_track = "stable"
  name                            = local.db_name
  project_id                      = var.project
  region                          = var.region
  tier                            = "db-f1-micro"
  zone                            = "${var.region}-a"
}

resource "google_storage_bucket" "tempo_data" {
  name     = "21g-social-tempo-data"
  location = var.region
  project  = var.project
}

resource "google_storage_bucket" "image-store" {
  name     = "21g-social-images"
  location = var.region
  project  = var.project
}

resource "google_storage_bucket_iam_member" "tempo_data_admin" {
  bucket = google_storage_bucket.tempo_data.name
  member = "serviceAccount:${google_service_account.tempo.email}"
  role   = "roles/storage.objectAdmin"
}

resource "google_storage_bucket_iam_member" "tempo_data_legacy_bucket_reader" {
  bucket = google_storage_bucket.tempo_data.name
  member = "serviceAccount:${google_service_account.tempo.email}"
  role   = "roles/storage.legacyBucketReader"
}

resource "google_storage_bucket_iam_member" "image_store_creator" {
  bucket = google_storage_bucket.image-store.name
  member = "serviceAccount:${google_service_account.grafana.email}"
  role   = "roles/storage.objectCreator"
}

resource "google_artifact_registry_repository" "containers" {
  provider = google-beta

  format        = "DOCKER"
  location      = var.region
  project       = var.project
  repository_id = "containers"
}

resource "google_artifact_registry_repository_iam_member" "gha" {
  provider = google-beta

  location   = google_artifact_registry_repository.containers.location
  member     = "serviceAccount:${google_service_account.gha.email}"
  project    = google_artifact_registry_repository.containers.project
  repository = google_artifact_registry_repository.containers.name
  role       = "roles/artifactregistry.writer"
}

module "gke" {
  source  = "terraform-google-modules/kubernetes-engine/google//modules/beta-autopilot-public-cluster"
  version = "25.0.0"

  datapath_provider = "ADVANCED_DATAPATH"
  ip_range_pods     = local.pods_range_name
  ip_range_services = local.svc_range_name
  name              = local.name
  network           = module.vpc.network_name
  project_id        = var.project
  region            = var.region
  release_channel   = "REGULAR"
  subnetwork        = local.subnet_names[index(module.vpc.subnets_names, local.subnet_name)]
}

resource "random_string" "influxdb2_admin_password" {
  length  = 32
  numeric = false
  special = false
}

resource "random_string" "influxdb2_admin_token" {
  length  = 32
  numeric = false
  special = false
}

resource "kubernetes_config_map_v1" "telegraf_plugins_config" {
  data = {
    "twitch-telegraf-plugin.conf"  = file("${path.module}/files/telegraf/twitch-telegraf-plugin.conf")
    "twitter-telegraf-plugin.conf" = file("${path.module}/files/telegraf/twitter-telegraf-plugin.conf")
    "youtube-telegraf-plugin.conf" = file("${path.module}/files/telegraf/youtube-telegraf-plugin.conf")
  }

  metadata {
    name = "telegraf-plugins-config"
  }
}

resource "kubernetes_secret_v1" "telegraf-tokens" {
  data = {
    INFLUX_TOKEN                = var.influx_token
    GOOGLE_API_KEY              = var.google_api_key
    TWITCH_CLIENT_ID            = var.twitch_client_id
    TWITCH_CLIENT_SECRET        = var.twitch_client_secret
    TWITTER_ACCESS_TOKEN        = var.twitter_access_token
    TWITTER_ACCESS_TOKEN_SECRET = var.twitter_access_token_secret
    TWITTER_CONSUMER_KEY        = var.twitter_consumer_key
    TWITTER_CONSUMER_SECRET     = var.twitter_consumer_secret
  }
  type = "Opaque"

  metadata {
    name = "telegraf-tokens"
  }
}

resource "kubernetes_secret_v1" "grafana_tokens" {
  data = {
    GF_DATABASE_HOST                      = "${module.mysql-db.private_ip_address}:3306"
    GF_DATABASE_NAME                      = "grafana"
    GF_DATABASE_PASSWORD                  = var.db_password
    GF_DATABASE_TYPE                      = "mysql"
    GF_DATABASE_USER                      = "grafana"
    GF_EXTERNAL_IMAGE_STORAGE_GCS_BUCKET  = google_storage_bucket.image-store.name
    GF_EXTERNAL_IMAGE_STORAGE_PROVIDER    = "gcs"
    GF_TRACING_OPENTELEMETRY_OTLP_ADDRESS = "tempo:4317"
  }
  type = "Opaque"

  metadata {
    name = "grafana-tokens"
  }
}

resource "helm_release" "tempo" {
  chart      = "tempo"
  name       = "tempo"
  repository = "https://grafana.github.io/helm-charts"
  values     = [file("${path.module}/files/tempo/values.yaml")]
  version    = "1.0.3"

  set {
    name  = "serviceAccount.annotations.iam\\.gke\\.io/gcp-service-account"
    value = google_service_account.tempo.email
  }

  set {
    name  = "tempo.storage.trace.gcs.bucket_name"
    value = google_storage_bucket.tempo_data.name
  }
}

resource "helm_release" "influxdb2" {
  chart      = "influxdb2"
  name       = "influxdb2"
  repository = "https://helm.influxdata.com/"
  values     = [file("${path.module}/files/influxdb2/values.yaml")]
  version    = "2.1.1"

  set_sensitive {
    name  = "adminUser.password"
    value = random_string.influxdb2_admin_password.result
  }

  set_sensitive {
    name  = "adminUser.token"
    value = random_string.influxdb2_admin_token.result
  }
}

resource "helm_release" "telegraf" {
  chart      = "telegraf"
  name       = "telegraf"
  repository = "https://helm.influxdata.com/"
  values     = [file("${path.module}/files/telegraf/values.yaml")]
  version    = "1.8.27"

  set {
    name  = "image.repo"
    value = local.telegraf_image_repository
  }

  set {
    name  = "image.tag"
    value = "20220629@sha256:6fb0b867b5f3f02abd380e9d6eb683cd5375fe02d65ff8b5fae57315b1803d9b"
  }
}

resource "helm_release" "grafana" {
  chart      = "grafana"
  name       = "grafana"
  repository = "https://grafana.github.io/helm-charts"
  values     = [file("${path.module}/files/grafana/values.yaml")]
  version    = "6.52.5"

  set {
    name  = "serviceAccount.annotations.iam\\.gke\\.io/gcp-service-account"
    value = google_service_account.grafana.email
  }
}

resource "github_actions_secret" "project" {
  plaintext_value = var.project
  repository      = var.repo_name
  secret_name     = "GOOGLE_PROJECT"
}

resource "github_actions_secret" "region" {
  plaintext_value = var.region
  repository      = var.repo_name
  secret_name     = "GOOGLE_REGION"
}

resource "github_actions_secret" "service_account" {
  plaintext_value = google_service_account.gha.email
  repository      = var.repo_name
  secret_name     = "GOOGLE_SERVICE_ACCOUNT"
}

resource "github_actions_secret" "workload_identity_provider" {
  plaintext_value = module.gh_oidc.provider_name
  repository      = var.repo_name
  secret_name     = "GOOGLE_WORKLOAD_IDENTITY_PROVIDER"
}
