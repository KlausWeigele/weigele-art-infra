variable "domain" {
  type = string
}

variable "bucket_name" {
  type = string
}

variable "tags" {
  type    = map(string)
  default = {}
}
