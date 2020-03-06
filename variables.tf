variable "project" {}
variable "credentials" {}
variable "region" {}
variable "zone" {}
variable "machine_type" {}

locals {
  name = "graph"

  machine_type = "n1-standard-1"
  disk_size_gb = 10
}
