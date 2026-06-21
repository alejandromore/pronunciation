terraform {
  backend "s3" {
    region = "us-east-1" # Cualquier region valida de AWS (el backend es OBS)

    bucket = "obs-alejandro-terraform-tfstate"
    key    = "tdp-pronunciation.tfstate"
    endpoints = {
      s3 = "https://obs.la-south-2.myhuaweicloud.com"
    }

    use_path_style              = false
    skip_region_validation      = true
    skip_credentials_validation = true
    skip_metadata_api_check     = true
    skip_requesting_account_id  = true
    skip_s3_checksum            = true
  }
}
