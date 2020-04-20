######################################################################################################
# THIS SCRIPT IS PROVIDED TO YOU "AS IS." TO THE EXTENT PERMITTED BY LAW, QUALYS HEREBY DISCLAIMS ALL WARRANTIES AND LIABILITY 
# FOR THE PROVISION OR USE OF THIS SCRIPT. IN NO EVENT SHALL THESE SCRIPTS BE DEEMED TO BE CLOUD SERVICES AS PROVIDED BY QUALYS
#
# Author: Mikesh Khanal
#
# INPUT THE FOLLOWING PARAMETERS
#
# project_id : GCP project to be onboarded to Qualys CloudView
# username: Username to login to Qualys CloudView
# Password: Password to login to Qualys CloudView
# baseurl: Qualys CloudView URL
######################################################################################################

variable "project_id" {
  type    = string
  description = "The id of the GCP Project which you want to Onboard to Qualys CloudView."
}
variable "username" {
  type    = string
  description = "The username for Qualys CloudView."
}
variable "password" {
  type    = string
  description = "The password for Qualys CloudView."
}
variable "baseurl" {
  type    = string
  description = "The API server for Qualys CloudView."
}

#############################
# Initializing the provider
##############################
terraform {
  required_providers {
    google = "~> 2.17"
  }
}
provider "google" {}


############################################################
# Creating the service account and the associated key
############################################################

resource "random_id" "unique_id" {
  byte_length = 8
}

resource "google_service_account" "qualys_cloudview_service_account" {
  account_id   = "cv-sa-${random_id.unique_id.dec}"
  display_name = "Qualys CloudView Service Account"
  project      = var.project_id
}

resource "google_service_account_key" "qualys_cloudview_service_account_key" {
  service_account_id = google_service_account.qualys_cloudview_service_account.name
}

########################################
# Role Assignment to the service account
########################################

resource "google_project_iam_member" "assign_viewer" {
  project = var.project_id
  role    = "roles/viewer"
  member  = "serviceAccount:${google_service_account.qualys_cloudview_service_account.email}"
}

resource "google_project_iam_member" "assign_security-reviewer" {
  project = var.project_id
  role    = "roles/iam.securityReviewer"
  member  = "serviceAccount:${google_service_account.qualys_cloudview_service_account.email}"
}


#################################
# Enable APIs
# Compute Engine API
# Cloud Resource Manager API
# Kubernetes Engine API
# Cloud SQL Admin API
#################################

resource "google_project_service" "enable_cloudresourcemanager" {
  project            = var.project_id
  service            = "cloudresourcemanager.googleapis.com"
  disable_on_destroy = false
}

resource "google_project_service" "enable_service_compute" {
  project            = var.project_id
  service            = "compute.googleapis.com"
  disable_on_destroy = false
}

resource "google_project_service" "enable_service_kubernetes" {
  project            = var.project_id
  service            = "container.googleapis.com"
  disable_on_destroy = false
}

resource "google_project_service" "enable_service_sql" {
  project            = var.project_id
  service            = "sql-component.googleapis.com"
  disable_on_destroy = false
}

#######################################################
# Qualys API Call to create CloudView Azure Connector
#######################################################

resource "local_file" "authentication_key" {
  content  = base64decode(google_service_account_key.qualys_cloudview_service_account_key.private_key)
  filename = "${path.module}/authentication_key1.json"
  depends_on = [google_project_service.enable_service_sql]
}
module "files" {
  source  = "matti/resource/shell"
  command = "curl -u '${var.username}:${var.password}' -X POST --header 'Content-Type: multipart/form-data' --header 'Accept: application/json' -F name=${var.project_id} -F configFile=@authentication_key1.json ${var.baseurl}/cloudview-api/rest/v1/gcp/connectors"
  depends = [local_file.authentication_key]
}

####################
## OUTPUT
####################

output "OUTPUT" { value = module.files.stdout }
output "EXIT-STATUS" { value = module.files.exitstatus }
