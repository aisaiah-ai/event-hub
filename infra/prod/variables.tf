variable "project_id" {
  description = "GCP / Firebase project ID"
  type        = string
}

variable "region" {
  description = "GCP region"
  type        = string
  default     = "us-central1"
}

variable "firestore_location" {
  description = "Firestore database location (e.g. nam5 for multi-region US)"
  type        = string
  default     = "nam5"
}
