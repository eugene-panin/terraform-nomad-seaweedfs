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
