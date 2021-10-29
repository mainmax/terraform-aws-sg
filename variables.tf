variable "vpc_id" {
  description = "VPC ID"
  type        = string
}

variable "name" {
  description = "The name for this Security Group"
  type        = string
}

variable "description" {
  description = "The description of what this Security Group is for"
  type        = string
}

variable "rules" { 
  description = "Ruleset document with each rule like \"IN TCP 22 0.0.0.0/0 - SSH from Internet\" on a new line"
  type        = string
  default     = "" 
}

variable "rules_vars" { 
  description = "Map of \"key\" = value pairs to substitute values in place of \"{key}\" in rules document. This way dynamic values, available only at \"apply\" can be used."
  type        = map(string)
  default     = {} 
}