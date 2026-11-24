variable "project_name" {
  type    = string
  default = "logicworks-devops"
}

variable "primary_region" {
  type    = string
  default = "ap-south-1"          # Mumbai Region
}

variable "secondary_region" {
  type    = string
  default = "ap-southeast-1"      # Singapore Region
}

variable "primary_vpc_cidr" {
  type    = string
  default = "10.10.0.0/16"
}

variable "secondary_vpc_cidr" {
  type    = string
  default = "10.20.0.0/16"
}

variable "alert_email" {
  type        = string
  description = "Email ID for SNS / CloudWatch alerts"
}