# -----------------------------------------------------------------------------
# REQUIRED PROVIDERS
# The provider configuration should be in the calling module (environment)
# -----------------------------------------------------------------------------

terraform {
  required_providers {
    google = {
      source = "hashicorp/google"
    }
  }
}