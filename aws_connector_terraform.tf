##################################
# THIS SCRIPT IS PROVIDED TO YOU "AS IS." TO THE EXTENT PERMITTED BY LAW, QUALYS HEREBY DISCLAIMS ALL WARRANTIES AND LIABILITY 
# FOR THE PROVISION OR USE OF THIS SCRIPT. IN NO EVENT SHALL THESE SCRIPTS BE DEEMED TO BE CLOUD SERVICES AS PROVIDED BY QUALYS
#
# Author: Mikesh Khanal
#
# INPUT THE FOLLOWING PARAMETERS
#
# username: Username to login to Qualys CloudView
# Password: Password to login to Qualys CloudView
# baseurl: Qualys CloudView URL
##################################

variable "create_assetview_cloudview_connector" {
  type    = bool
  description = "If set to true, creates cloudview and AssetView Connector; If set to false, creates AssetView Connector"

}
variable "username" {
  type    = string
  description = "The username for Qualys CloudView."
}
variable "baseurl" {
  type    = string
  description = "The API server for Qualys CloudView eg:https://qualysapi.qg2.apps.qualys.com"
}
variable "password" {
  type    = string
  description = "The password for Qualys CloudView."
}
variable "externalId" {
  type    = string
  description = "The external Id for the assume role."
}

#############################
# Initializing the provider
##############################

provider "aws" {
  version = "~> 2.0"
  region  = "us-east-1"
}

################################################
# Creating an IAM role with assume_role policy
################################################

resource "aws_iam_role" "Qualys_role" {
  name = "qualys_role"

  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "AWS": "arn:aws:iam::805950163170:root"
      },
      "Action": "sts:AssumeRole",
      "Condition": {
        "StringEquals": {
          "sts:ExternalId": ${var.externalId}
        }
      }
    }
  ]
}
EOF

  tags = {
    tag-key = "tag-value"
  }
}

###################################################
# Attaching SecurityAudit Policy to the Qualys role
###################################################

resource "aws_iam_role_policy_attachment" "role_attach" {
  role       = "${aws_iam_role.Qualys_role.name}"
  policy_arn = "arn:aws:iam::aws:policy/SecurityAudit"
}

#################################################################
# Qualys API Call to create CloudView AWS Connector
#################################################################

resource "local_file" "authentication_key" {
  content  = "<ServiceRequest><data><AwsAssetDataConnector><name>AWS-connector-\"${substr("${aws_iam_role.Qualys_role.arn}",13,12)}\"</name><activation><set><ActivationModule>VM</ActivationModule><ActivationModule>PC</ActivationModule></set></activation><arn>${aws_iam_role.Qualys_role.arn}</arn><externalId>${var.externalId}</externalId><allRegions>true</allRegions><useForCloudView>${var.create_cloudview_connector}</useForCloudView></AwsAssetDataConnector></data></ServiceRequest>"
  filename = "${path.module}/file.xml"
  depends_on = [aws_iam_role_policy_attachment.role_attach]
}
module "QualysCloudViewAssetViewConnector" {
  source  = "matti/resource/shell"
  command = "curl -u '${var.username}:${var.password}' --header 'Content-type: text/xml' -X POST --data-binary @- ${var.baseurl}/qps/rest/2.0/create/am/awsassetdataconnector < file.xml"
  depends = [aws_iam_role_policy_attachment.role_attach]
}

#######################################################
# Outputs
#######################################################

output "ROLE_ARN" { value = aws_iam_role.Qualys_role.arn}
output "CLOUDVIEW-OUTPUT" { value = module.QualysCloudViewAssetViewConnector.stdout }
output "CLOUDVIEW-EXIT-STATUS" { value = module.QualysCloudViewAssetViewConnector.exitstatus }