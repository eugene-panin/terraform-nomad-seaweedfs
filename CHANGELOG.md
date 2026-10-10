# Changelog

## v0.1.0

- SeaweedFS with its S3 API on a Nomad platform: one job, the lake in a dynamic
  host volume the platform's backup copies by name (`meta.backup = "stop"`).
- A Consul service clients reach the S3 API by, health-checked on the master's
  cluster-status endpoint. It binds only the internal host network.
- A secret key is generated per identity and kept in Vault; each identity is
  granted the caller's actions on the bucket, so the access policy stays with the
  app that owns the lake. Prometheus metrics on the metrics port.

## v0.1.1

- The task reserves 512 MB, sized to its use, and may grow to 1024 MB:
  `resources.memory_max` (Nomad memory oversubscription, which the platform
  turns on). It reserved more than it used before.

## v0.1.2

- `mesh`: the S3 gateway can join the Consul service mesh — an Envoy sidecar
  with the transparent proxy, so mesh services reach it as
  `<job_name>.virtual.consul` over mTLS and only those in `mesh.allow` may
  (service-intentions; the platform's ACLs deny the rest). `mesh.protocol` is
  http, so Consul sees S3's requests. `mesh.keep_open_ports` stay reachable
  outside the mesh while clients move in; the master and metrics ports always
  are. Envoy's metrics are a `<job_name>-envoy` service tagged for Alloy.

## v0.1.3

- The mesh's config entries are written as Consul stores them (the empty
  blocks it fills into service-defaults; Type and Precedence on each intention
  source), so a plan no longer rewrites them on every apply.
- In the mesh the client port is static only while it is in
  `mesh.keep_open_ports`: Nomad lets any static port bypass the sidecar, so a
  static port left the service open outside the mesh. Mesh clients reach it
  through Envoy at `<job_name>.virtual.consul` either way.
