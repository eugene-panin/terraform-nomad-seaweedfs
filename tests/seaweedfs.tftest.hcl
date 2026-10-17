mock_provider "consul" {}
mock_provider "nomad" {}
mock_provider "random" {}
mock_provider "vault" {}

variables {
  vault_kv_path = "secret"
  bucket        = "lake"
  identities = [
    { name = "fetcher", actions = ["Admin", "Read", "Write", "List", "Tagging"] },
    { name = "ingest", actions = ["Read", "List"] },
  ]
}

run "it_exposes_a_consul_service" {
  command = apply

  assert {
    condition     = output.service_name == "seaweedfs" && output.s3_port == 8333
    error_message = "SeaweedFS is not exposed as the expected Consul service and port."
  }

  assert {
    condition     = output.keys_secret == "default/seaweedfs/keys"
    error_message = "The secret keys are not at the expected Vault name."
  }
}

run "it_grants_the_actions_on_the_bucket_and_stays_internal" {
  command = apply

  assert {
    condition     = strcontains(nomad_job.seaweedfs.jobspec, "\"Admin:lake\"")
    error_message = "The writer identity is not granted its actions on the bucket."
  }

  assert {
    condition     = strcontains(nomad_job.seaweedfs.jobspec, "\"accessKey\":\"fetcher\",\"secretKey\":\"{{ .Data.data.fetcher }}\"")
    error_message = "An identity's secret key is not injected from Vault."
  }

  assert {
    condition     = !strcontains(nomad_job.seaweedfs.jobspec, "host_network = \"public\"")
    error_message = "The lake must never bind the public host network."
  }
}

run "memory_is_reserved_by_use_and_may_grow" {
  command = apply

  assert {
    condition     = strcontains(nomad_job.seaweedfs.jobspec, "memory     = 512") && strcontains(nomad_job.seaweedfs.jobspec, "memory_max = 1024")
    error_message = "The task must reserve its usual memory and be allowed to grow to memory_max."
  }
}

run "it_joins_the_mesh" {
  command = apply

  variables {
    mesh = { enabled = true, allow = ["sauron-ingest"], keep_open_ports = [8333] }
  }

  assert {
    condition = (
      strcontains(nomad_job.seaweedfs.jobspec, "transparent_proxy")
      && strcontains(nomad_job.seaweedfs.jobspec, "exclude_inbound_ports = [\"8333\",\"9333\",\"9327\",\"9102\"]")
      && strcontains(nomad_job.seaweedfs.jobspec, "name     = \"seaweedfs-envoy\"")
      && strcontains(nomad_job.seaweedfs.jobspec, "uid                   = \"1337\"")
    )
    error_message = "In the mesh the S3 gateway must sit behind an Envoy sidecar, keep the given ports, the master and metrics open, and expose Envoy's metrics."
  }

  assert {
    condition = (
      jsondecode(consul_config_entry.intentions[0].config_json).Sources == [{ Name = "sauron-ingest", Action = "allow", Precedence = 9, Type = "consul" }]
      && jsondecode(consul_config_entry.defaults[0].config_json).Protocol == "http"
    )
    error_message = "Only the allowed services may connect, and the protocol is http."
  }
}

run "out_of_the_mesh_by_default" {
  command = apply

  assert {
    condition     = !strcontains(nomad_job.seaweedfs.jobspec, "connect {") && length(consul_config_entry.intentions) == 0
    error_message = "Without mesh.enabled there is no sidecar and no intentions."
  }
}

run "in_the_mesh_the_port_is_static_only_while_kept_open" {
  command = apply

  variables {
    mesh = { enabled = true, allow = ["x"] }
  }

  assert {
    condition     = !strcontains(nomad_job.seaweedfs.jobspec, "static       = 8333")
    error_message = "Nomad lets a static port bypass the sidecar: in the mesh the s3 port must be dynamic unless kept open."
  }
}

run "envoy_passes_to_the_port_inside_the_group" {
  command = apply

  variables {
    mesh = { enabled = true, allow = ["x"] }
  }

  assert {
    condition     = strcontains(nomad_job.seaweedfs.jobspec, "local_service_port = ")
    error_message = "With a dynamic port, Envoy must be told the port inside the group, or it passes the traffic to the host port, where nothing listens."
  }
}

run "the_service_carries_the_tags_and_meta_given" {
  command = apply

  variables {
    service_tags = ["damstack.provides=s3@1"]
    service_meta = { kind = "example" }
  }

  assert {
    condition     = strcontains(nomad_job.seaweedfs.jobspec, "tags     = [\"damstack.provides=s3@1\"]") && strcontains(nomad_job.seaweedfs.jobspec, "meta {") && strcontains(nomad_job.seaweedfs.jobspec, "kind = \"example\"")
    error_message = "The service must carry the tags and meta given."
  }
}

run "the_service_has_no_tags_or_meta_by_default" {
  command = apply

  assert {
    condition     = !strcontains(nomad_job.seaweedfs.jobspec, "damstack.provides") && length(regexall("\n      meta {", nomad_job.seaweedfs.jobspec)) == 0
    error_message = "Without service_tags and service_meta the service must be as before."
  }
}
