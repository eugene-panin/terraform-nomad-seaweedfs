# Changelog

## v0.1.0

- SeaweedFS with its S3 API on a Nomad platform: one job, the lake in a dynamic
  host volume the platform's backup copies by name (`meta.backup = "stop"`).
- A Consul service clients reach the S3 API by, health-checked on the master's
  cluster-status endpoint. It binds only the internal host network.
- A secret key is generated per identity and kept in Vault; each identity is
  granted the caller's actions on the bucket, so the access policy stays with the
  app that owns the lake. Prometheus metrics on the metrics port.
