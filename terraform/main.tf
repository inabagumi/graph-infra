terraform {
  backend "remote" {}
}

provider "google" {
  credentials = var.credentials

  project = var.project
  region  = var.region
  zone    = var.zone
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

resource "google_container_cluster" "primary0" {
  name               = "${local.name}-cluster"
  location           = var.region
  min_master_version = "1.16.9-gke.6"

  node_locations = [
    var.zone
  ]

  remove_default_node_pool = true
  initial_node_count       = 1

  master_auth {
    username = ""
    password = ""

    client_certificate_config {
      issue_client_certificate = false
    }
  }

  ip_allocation_policy {}
}

resource "google_container_cluster" "primary" {
  name     = local.name
  location = var.zone

  min_master_version       = "1.16.9-gke.6"
  remove_default_node_pool = true
  initial_node_count       = 1

  master_auth {
    username = ""
    password = ""

    client_certificate_config {
      issue_client_certificate = false
    }
  }

  ip_allocation_policy {}
}

resource "google_container_node_pool" "primary_nodes0" {
  name       = "${local.name}-node-pool"
  location   = google_container_cluster.primary0.location
  cluster    = google_container_cluster.primary0.name
  version    = google_container_cluster.primary0.min_master_version
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
    machine_type = "n1-standard-1"
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

resource "google_container_node_pool" "primary_nodes" {
  name       = "${local.name}-node-pool"
  location   = google_container_cluster.primary.location
  cluster    = google_container_cluster.primary.name
  version    = google_container_cluster.primary.min_master_version
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
