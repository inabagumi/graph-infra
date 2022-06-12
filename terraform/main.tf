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
      version = "4.24.0"
    }

    google-beta = {
      source  = "hashicorp/google-beta"
      version = "4.24.0"
    }

    github = {
      source  = "integrations/github"
      version = "4.26.1"
    }

    helm = {
      source  = "hashicorp/helm"
      version = "2.5.1"
    }

    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "2.11.0"
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
  db_name                = "grafana"
  master_auth_subnetwork = "${local.name}-master-subnet"
  name                   = "graph"
  network_name           = "${local.name}-network"
  pods_range_name        = "ip-range-pods-${local.name}"
  subnet_name            = "${local.name}-subnet"
  subnet_names           = [for subnet_self_link in module.vpc.subnets_self_links : split("/", subnet_self_link)[length(split("/", subnet_self_link)) - 1]]
  svc_range_name         = "ip-range-svc-${local.name}"
}

data "google_client_config" "default" {}

data "google_compute_network" "default" {
  name = "default"
}

resource "google_service_account" "gha" {
  account_id   = "github-actions"
  description  = "Service Account for GitHub Actions"
  display_name = "GitHub Actions"
  project      = var.project
}

module "gh_oidc" {
  source  = "terraform-google-modules/github-actions-runners/google//modules/gh-oidc"
  version = "3.0.0"

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
  version = "5.1.0"

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

resource "google_dns_record_set" "frontend" {
  name = google_dns_managed_zone.default.dns_name
  type = "A"
  ttl  = 300

  managed_zone = google_dns_managed_zone.default.name

  rrdatas = [google_compute_global_address.default.address]
}

module "mysql-db" {
  source  = "GoogleCloudPlatform/sql-db/google//modules/mysql"
  version = "11.0.0"

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
    ipv4_enabled        = true
    private_network     = data.google_compute_network.default.id
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

resource "google_storage_bucket" "image-store" {
  name     = "21g-social-images"
  location = var.region
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

resource "google_container_cluster" "main" {
  name     = local.name
  location = "${var.region}-c"

  enable_shielded_nodes    = false
  remove_default_node_pool = true
  initial_node_count       = 1

  master_auth {
    client_certificate_config {
      issue_client_certificate = false
    }
  }

  release_channel {
    channel = "REGULAR"
  }

  ip_allocation_policy {}
}

resource "google_container_node_pool" "main_nodes" {
  name       = "${local.name}-node-pool"
  location   = google_container_cluster.main.location
  cluster    = google_container_cluster.main.name
  node_count = 2

  autoscaling {
    min_node_count = 1
    max_node_count = 5
  }

  management {
    auto_repair  = true
    auto_upgrade = true
  }

  node_config {
    preemptible  = true
    machine_type = "e2-small"
    disk_size_gb = 10

    metadata = {
      disable-legacy-endpoints = "true"
    }

    oauth_scopes = [
      "https://www.googleapis.com/auth/devstorage.read_only",
      "https://www.googleapis.com/auth/logging.write",
      "https://www.googleapis.com/auth/monitoring",
    ]
  }
}

module "gke" {
  source  = "terraform-google-modules/kubernetes-engine/google//modules/beta-autopilot-public-cluster"
  version = "21.1.0"

  enable_vertical_pod_autoscaling = true
  ip_range_pods                   = local.pods_range_name
  ip_range_services               = local.svc_range_name
  name                            = local.name
  network                         = module.vpc.network_name
  project_id                      = var.project
  region                          = var.region
  release_channel                 = "REGULAR"
  subnetwork                      = local.subnet_names[index(module.vpc.subnets_names, local.subnet_name)]
}

resource "kubernetes_config_map_v1" "telegraf_plugins_config" {
  data = {
    "twitter-telegraf-plugin.conf" = file("${path.module}/files/telegraf/twitter-telegraf-plugin.conf")
    "youtube-telegraf-plugin.conf" = file("${path.module}/files/telegraf/youtube-telegraf-plugin.conf")
  }

  metadata {
    name = "telegraf-plugins-config"
  }
}

resource "kubernetes_secret_v1" "telegraf-tokens" {
  data = {
    INFLUXDB_TOKEN              = ""
    GOOGLE_API_KEY              = ""
    TWITTER_ACCESS_TOKEN        = ""
    TWITTER_ACCESS_TOKEN_SECRET = ""
    TWITTER_CONSUMER_KEY        = ""
    TWITTER_CONSUMER_SECRET     = ""
  }
  type = "Opaque"

  metadata {
    name = "telegraf-tokens"
  }
}

resource "helm_release" "influxdb2" {
  chart      = "influxdb2"
  name       = "influxdb2"
  repository = "https://helm.influxdata.com/"
  values     = [file("${path.module}/files/influxdb2/values.yaml")]
  version    = "2.1.0"
}

resource "helm_release" "telegraf" {
  chart      = "telegraf"
  name       = "telegraf"
  repository = "https://helm.influxdata.com/"
  values     = [file("${path.module}/files/telegraf/values.yaml")]
  version    = "1.8.18"
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
