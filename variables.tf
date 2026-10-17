variable "vault_kv_path" {
  description = "Path of the Vault KV v2 engine the per-identity secret keys are kept in; the platform gives it."
  type        = string
}

variable "bucket" {
  description = "The S3 bucket the identities are granted on. The first identity (an Admin) creates it."
  type        = string
  default     = "lake"
}

variable "identities" {
  description = <<-EOT
    S3 identities. Each gets an access key equal to its name and a generated
    secret key, kept in Vault, granted the given actions on the bucket. The
    actions are the caller's policy (e.g. a writer gets Admin/Read/Write/List/
    Tagging, a reader Read/List), because they belong to the app that owns the
    lake.
  EOT
  type = list(object({
    name    = string
    actions = list(string)
  }))
  validation {
    condition     = alltrue([for id in var.identities : can(regex("^[a-z][a-z0-9_]*$", id.name))])
    error_message = "each identity name must be lowercase letters, digits and _, starting with a letter."
  }
}

variable "namespace" {
  description = "Nomad namespace the job runs in."
  type        = string
  default     = "default"
}

variable "job_name" {
  description = "Name of the Nomad job and the Consul service other apps reach it by."
  type        = string
  default     = "seaweedfs"
  validation {
    condition     = can(regex("^[a-z][a-z0-9-]{0,30}$", var.job_name))
    error_message = "job_name must be lowercase letters, digits and -, starting with a letter."
  }
}

variable "datacenters" {
  description = "Nomad datacenters the job may run in."
  type        = list(string)
  default     = ["*"]
}

variable "image" {
  description = "SeaweedFS container image, pinned by a fixed tag or a digest."
  type        = string
  default     = "chrislusf/seaweedfs:3.80"
}

variable "s3_port" {
  description = "Port the S3 API is served on, on the internal host network."
  type        = number
  default     = 8333
}

variable "master_port" {
  description = "Port the master (and its cluster-status health endpoint) is served on."
  type        = number
  default     = 9333
}

variable "metrics_port" {
  description = "Port Prometheus metrics are served on."
  type        = number
  default     = 9327
}

variable "volume_size_limit_mb" {
  description = "SeaweedFS volume size limit in MB; the master only places a volume on a node that has this much free, so a full disk stops writes."
  type        = number
  default     = 1024
}

variable "internal_host_network" {
  description = "Nomad host network SeaweedFS binds to. Never the public network: the lake is reachable only inside the platform."
  type        = string
  default     = "default"
}

variable "resources" {
  description = "CPU (MHz) and memory (MB) for the SeaweedFS task: memory is what it reserves (sized to its use), memory_max how far it may grow (Nomad memory oversubscription)."
  type = object({
    cpu        = optional(number, 500)
    memory     = optional(number, 512)
    memory_max = optional(number, 1024)
  })
  default = {}
  validation {
    condition     = var.resources.memory_max >= var.resources.memory
    error_message = "resources.memory_max must be at least resources.memory."
  }
}

variable "mesh" {
  description = <<-EOT
    The Consul service mesh. enabled puts the S3 gateway behind an Envoy sidecar
    (transparent proxy): mesh services reach it as <job_name>.virtual.consul over mTLS, and
    only those in allow may (Consul intentions; any other is denied). keep_open_ports stay
    reachable outside the mesh — for clients not in it yet, during a move into it; the
    master and metrics ports always are. protocol is what Consul's L7 features see: http
    for S3.
  EOT
  type = object({
    enabled         = optional(bool, false)
    allow           = optional(list(string), [])
    keep_open_ports = optional(list(number), [])
    protocol        = optional(string, "http")
  })
  default = {}
  validation {
    condition     = contains(["tcp", "http", "http2", "grpc"], var.mesh.protocol)
    error_message = "mesh.protocol must be tcp, http, http2 or grpc."
  }
}

variable "service_tags" {
  description = "Tags of the Consul service clients reach the S3 API by, besides its own; such as damstack.provides=s3@1, which tells damstack what it provides."
  type        = list(string)
  default     = []
}

variable "service_meta" {
  description = "Meta of the Consul service clients reach the S3 API by: what else a client needs to use it."
  type        = map(string)
  default     = {}
  validation {
    condition     = alltrue([for k in keys(var.service_meta) : can(regex("^[A-Za-z_][A-Za-z0-9_-]*$", k))])
    error_message = "service_meta keys must be letters, digits, _ and -, starting with a letter or _."
  }
}
