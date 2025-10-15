terraform {
  backend "s3" {
    bucket         = "weigele-terraform-state"
    key            = "weigele-art/prod.tfstate"
    region         = "eu-central-1"
    dynamodb_table = "weigele-terraform-locks"
    encrypt        = true
  }
}
