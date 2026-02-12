output "project_id" {
  description = "Firebase project ID"
  value       = var.project_id
}

output "firestore_database" {
  description = "Firestore database name"
  value       = google_firestore_database.event_hub_prod.name
}
