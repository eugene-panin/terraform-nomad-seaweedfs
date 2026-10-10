locals {
  secret_name    = "${var.namespace}/${var.job_name}/keys"
  volume_name    = "${var.job_name}-data"
  secret_keys    = { for id in var.identities : id.name => random_password.key[id.name].result }
  secret_version = parseint(substr(sha256(jsonencode(local.secret_keys)), 0, 8), 16)

  # The identities JSON for weed's -s3.config, with each secret key left as a
  # consul-template placeholder the job fills from Vault at runtime.
  identities_json = join(",", [
    for id in var.identities :
    format(
      "{\"name\":\"%s\",\"credentials\":[{\"accessKey\":\"%s\",\"secretKey\":\"{{ .Data.data.%s }}\"}],\"actions\":[%s]}",
      id.name, id.name, id.name,
      join(",", [for a in id.actions : "\"${a}:${var.bucket}\""]),
    )
  ])
}

resource "random_password" "key" {
  for_each = { for id in var.identities : id.name => id }
  length   = 40
  special  = false
}

resource "vault_kv_secret_v2" "keys" {
  mount                = var.vault_kv_path
  name                 = local.secret_name
  data_json_wo         = jsonencode(local.secret_keys)
  data_json_wo_version = local.secret_version
}

resource "nomad_dynamic_host_volume" "data" {
  name      = local.volume_name
  namespace = var.namespace
  plugin_id = "mkdir"

  parameters = {
    mode = "0700"
    uid  = "0"
    gid  = "0"
  }

  capability {
    access_mode     = "single-node-writer"
    attachment_mode = "file-system"
  }
}

resource "nomad_job" "seaweedfs" {
  jobspec = templatefile("${path.module}/templates/seaweedfs.nomad.hcl.tftpl", {
    job_name             = var.job_name
    namespace            = var.namespace
    datacenters          = var.datacenters
    volume_name          = nomad_dynamic_host_volume.data.name
    secret_path          = "${var.vault_kv_path}/data/${local.secret_name}"
    secret_version       = local.secret_version
    internal_network     = var.internal_host_network
    image                = var.image
    identities_json      = local.identities_json
    s3_port              = var.s3_port
    master_port          = var.master_port
    metrics_port         = var.metrics_port
    volume_size_limit_mb = var.volume_size_limit_mb
    resources            = var.resources
    mesh                 = var.mesh
  })

  purge_on_destroy = true

  depends_on = [vault_kv_secret_v2.keys]
}

# In the mesh: what Consul's L7 features see, and who may connect (intentions;
# the platform's ACLs deny any other).
resource "consul_config_entry" "defaults" {
  count = var.mesh.enabled ? 1 : 0

  kind = "service-defaults"
  name = var.job_name
  config_json = jsonencode({
    # As Consul stores it (with the empty blocks it fills in), so a plan sees no drift.
    Protocol         = var.mesh.protocol
    Expose           = {}
    MeshGateway      = {}
    TransparentProxy = {}
  })
}

# Only when some service is allowed: Consul takes no intentions without a source,
# and with none the platform's default deny already stands.
resource "consul_config_entry" "intentions" {
  count = var.mesh.enabled && length(var.mesh.allow) > 0 ? 1 : 0

  kind = "service-intentions"
  name = var.job_name
  config_json = jsonencode({
    # As Consul stores it: Type consul, and Precedence 9 for an exact source and an
    # exact destination; so a plan sees no drift.
    Sources = [for s in var.mesh.allow : { Name = s, Action = "allow", Precedence = 9, Type = "consul" }]
  })
}
