# QualysConnector_terraform
Terraform Template to create Qualys CloudView(CV) & AssetView(AV) Connector in your subscription

# From SJULTRA GitHub Repo
https://github.com/sjultra/qualys_cloud_connector_terraform_templates

# License
_**THIS SCRIPT IS PROVIDED TO YOU "AS IS."  TO THE EXTENT PERMITTED BY LAW, QUALYS HEREBY DISCLAIMS ALL WARRANTIES AND LIABILITY FOR THE PROVISION OR USE OF THIS SCRIPT.  IN NO EVENT SHALL THESE SCRIPTS BE DEEMED TO BE CLOUD SERVICES AS PROVIDED BY QUALYS**_

# Usage:
Use Terraform Template to create a Qualys AWS, AZURE & GCP CloudView Connector and AWS & AZURE AssetView Coonector. To run the script you will need to supply credentials for the Qualys user name and password for Qualys API Access.

## Common Input Parameters: 

* UserName: Default: {supply_Qualys_user_name_for_CloudView_API} ...

* Password: Default: {supply_Qualys_user_password_for_CloudView_API}

* BaseUrl: Url of the Qualys CloudView APIs  Default: https://qualysguard.qg2.apps.qualys.com 

## Terraform CLI to Run Template
An Example:
` terraform init
terraform plan
terraform apply `

You can copy these templates and directly run in Azure Shell for Azure AV & CV connectors and similarly for GCP AV & CV Connectors, run these commands in Google cloud shell.

## Note
The terraform template makes use of the module by Matti present in this [GitHub repo](https://github.com/matti/terraform-shell-resource) for generation of output & error for null resource due to limitation of terraform. 
