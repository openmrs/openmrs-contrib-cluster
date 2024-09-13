variable "domain_name" {
  type        = string
  description = "Domain Name for Amazon SES service"
}

variable "zone_id" {
  type        = string
  description = "Route 53 Hosted Zone ID for the domain_name"
}
