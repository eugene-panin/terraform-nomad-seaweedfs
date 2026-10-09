output "job_id" {
  description = "ID of the SeaweedFS job in Nomad."
  value       = nomad_job.seaweedfs.id
}

output "service_name" {
  description = "Consul service name clients reach the S3 API by."
  value       = var.job_name
}

output "s3_port" {
  description = "Port the S3 API is served on."
  value       = var.s3_port
}

output "bucket" {
  description = "The S3 bucket the identities are granted on."
  value       = var.bucket
}

output "identities" {
  description = "S3 identity names a secret key was generated for; the access key equals the name."
  value       = [for id in var.identities : id.name]
}

output "keys_secret" {
  description = "Vault KV name (under the mount) holding each identity's secret key, keyed by name. A client reads its own from here."
  value       = local.secret_name
}

output "data_volume" {
  description = "Name of the dynamic host volume holding the lake."
  value       = nomad_dynamic_host_volume.data.name
}
