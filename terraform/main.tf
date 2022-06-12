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

locals {
  db_name = "grafana"
  name    = "graph"
}

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
    binary_log_enabled = true
    enabled = true
    location = "asia"
    retained_backups = 7
    retention_unit = "COUNT"
    start_time = "20:00"
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

resource "google_storage_bucket" "image-store" {
  name     = "21g-social-images"
  location = var.region
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
