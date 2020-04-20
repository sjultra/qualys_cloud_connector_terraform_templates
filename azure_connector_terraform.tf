##################################
# THIS SCRIPT IS PROVIDED TO YOU "AS IS." TO THE EXTENT PERMITTED BY LAW, QUALYS HEREBY DISCLAIMS ALL WARRANTIES AND LIABILITY 
# FOR THE PROVISION OR USE OF THIS SCRIPT. IN NO EVENT SHALL THESE SCRIPTS BE DEEMED TO BE CLOUD SERVICES AS PROVIDED BY QUALYS
#
# Author: Mikesh Khanal
#
# EDIT THE FOLLOWING PARAMETERS
#
# active_directory_id :Active directory's ID
# subscription_id:Subscription ID that you want to onboard to Qualys CloudView
# username: Username to login to Qualys CloudView
# Password: Password to login to Qualys CloudView
# baseurl: Qualys CloudView URL
##################################

variable "create_assetview_connector" {
  description = "If set to true, creates assetview connector"
  type        = bool
}
variable "active_directory_id" {
  type = string
  default = "ff4e2413-65ab-4dc2-9e5b-1ea02d3d94eb"
}
variable "subscription_id" {
  type = string
  default = "30293558-9706-4c17-863a-016e35462650"
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
  description = "The API server for Qualys CloudView eg: https://qualysguard.qg2.apps.qualys.com"
}

#############################
# Initializing the provider
##############################

provider "azuread" {
  subscription_id = var.subscription_id
  tenant_id = var.active_directory_id
}

provider "azurerm" {
  version = "=2.0.0"
  subscription_id = var.subscription_id
  tenant_id = var.active_directory_id
  features {}
}

#######################################################
# Creating an Application & associated Service Principal
#######################################################
resource "random_password" "password" {
  length = 24
  special = true
}

resource "random_id" "unique_id" {
  byte_length = 8
}


resource "azuread_application" "qualys_cloudview_app" {
  name                       = "Qualys CloudView Application for ${var.subscription_id} ${random_id.unique_id.dec}"
  homepage                   = "https://www.qualys.com/apps/cloud-security-assessment/"
  available_to_other_tenants = false
  
  required_resource_access {
    
	# the Azure AD Graph API
    resource_app_id = "00000003-0000-0000-c000-000000000000"

    # The "User Read all" permission. Get ID from:
    # az ad sp show --id 00000003-0000-0000-c000-000000000000 --query "oauth2Permissions[?value=='User.Read.All']"
    resource_access {
      id = "df021288-bdef-4463-88db-98f22de89214"
      type = "Role"
    }	
  }
  
  required_resource_access {
    
	# the Azure Service Management API
    resource_app_id = "797f4846-ba00-4fd7-ba43-dac1f8f63013"

    # The "Impersonate user" permission. Get ID from:
	# az ad sp show --id 797f4846-ba00-4fd7-ba43-dac1f8f63013 --query "oauth2Permissions[?value=='user_impersonation']"
    resource_access {
      id = "41094075-9dad-400e-a0bd-54e686782033"
      type = "Scope"
    }	
  }
}

resource "azuread_service_principal" "qualys_cloudview_serviceprincipal" {
  application_id = azuread_application.qualys_cloudview_app.application_id
}


resource "azuread_application_password" "password" {
  application_id       = azuread_application.qualys_cloudview_app.id
  value                = random_password.password.result
  end_date = "2299-12-30T23:00:00Z"
}


#######################################################
# Role Assignment
#######################################################

resource "azurerm_role_assignment" "assign_reader" {
  scope       = "/subscriptions/${var.subscription_id}"
  principal_id = azuread_service_principal.qualys_cloudview_serviceprincipal.id
  role_definition_name = "Reader"
}

#######################################################
# Qualys API Call to create CloudView Azure Connector
#######################################################

module "QualysCloudViewConnector" {
  source  = "matti/resource/shell"
  command = "curl -u '${var.username}:${var.password}' -X POST --header 'Content-Type: application/json' --header 'Accept: application/json' -d '{\"applicationId\":\"${azuread_application.qualys_cloudview_app.application_id}\" , \"authenticationKey\":\"${random_password.password.result}\" , \"description\": \"${var.subscription_id}\", \"directoryId\": \"${var.active_directory_id}\", \"isGovCloud\": false, \"name\": \"Azure-coonector-${var.subscription_id}\", \"subscriptionId\": \"${var.subscription_id}\"}' ${var.baseurl}/cloudview-api/rest/v1/azure/connectors"
  depends = [azurerm_role_assignment.assign_reader]
}

#########################################################
# Qualys API Call to create ClouAssetView Azure Connector
#########################################################

resource "local_file" "authentication_key" {
  count = var.create_assetview_connector ? 1 : 0

  content  = "<ServiceRequest><data><AzureAssetDataConnector><name>Azure-connector-${var.subscription_id}</name><description>Sample Azure Connector</description><disabled>false</disabled><isGovCloudConfigured>false</isGovCloudConfigured><authRecord><applicationId>${azuread_application.qualys_cloudview_app.application_id}</applicationId><directoryId>${var.active_directory_id}</directoryId><subscriptionId>${var.subscription_id}</subscriptionId><authenticationKey>${random_password.password.result}</authenticationKey></authRecord></AzureAssetDataConnector></data></ServiceRequest>"
  filename = "${path.module}/file.xml"
  depends_on = [azurerm_role_assignment.assign_reader]
}

module "QualysAssetViewConnector" {
  source  = "matti/resource/shell"
  command = "curl -u '${var.username}:${var.password}' -X POST --header 'Content-Type: text/xml' --header 'Accept: application/json' --data-binary @- \"${replace("${var.baseurl}", "guard", "api")}\"/qps/rest/2.0/create/am/azureassetdataconnector < file.xml"
  depends = [local_file.authentication_key]
}

#######################################################
# Outputs
#######################################################


output "Qualys_CloudView__application_id" { value = azuread_application.qualys_cloudview_app.application_id}
output "Qualys_CloudView__authentication_key" { value = random_password.password.result}
output "Qualys_CloudView__application_name" { value = azuread_application.qualys_cloudview_app.name }
output "CLOUDVIEW-OUTPUT" { value = module.QualysCloudViewConnector.stdout }
output "CLOUDVIEW-EXIT-STATUS" { value = module.QualysCloudViewConnector.exitstatus }
output "ASSETVIEW-OUTPUT" { value = module.QualysAssetViewConnector.stdout }
output "ASSETVIEW-EXIT-STATUS" { value = module.QualysAssetViewConnector.exitstatus }