variable "db_password" {
  type = string
}

variable "google_api_key" {
  type = string
}

variable "influx_token" {
  type = string
}

variable "project" {
  type = string
}

variable "region" {
  default = "asia-northeast1"
  type    = string
}
variable "repo_name" {
  default = "graph-infra"
  type    = string
}

variable "repo_owner" {
  default = "inabagumi"
  type    = string
}

variable "twitch_client_id" {
  type = string
}

variable "twitch_client_secret" {
  type = string
}

variable "twitter_access_token" {
  type = string
}

variable "twitter_access_token_secret" {
  type = string
}

variable "twitter_consumer_key" {
  type = string
}

variable "twitter_consumer_secret" {
  type = string
}

