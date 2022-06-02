provider "aws" {
  region     = "us-east-1"
}

terraform {
  # Use s3 to store terraform state
  backend "s3" {
    bucket  = "nypl-travis-builds-production"
    key     = "PatronService-production"
    region  = "us-east-1"
  }
}

module "base" {
  source = "../base"

  environment = "production"
}
