# terraform-nomad-seaweedfs

SeaweedFS with its S3 API on a Nomad platform that has Consul and Vault — such as
[hashi](https://github.com/eugene-panin/damstack-hashi). The
[damstack-seaweedfs](https://github.com/eugene-panin/damstack-seaweedfs) stack
wires it.

A generic object store: it runs `weed server -s3`, keeps the lake in a host
volume, and exposes a Consul service. The access policy — which identity may do
what on the bucket — is your `identities`, because it belongs to the app that
owns the lake (e.g. Sauron). Each identity's access key is its name; its secret
key is generated and kept in Vault.

## What it deploys

- One Nomad job, SeaweedFS, the lake in the `<job_name>-data` host volume
  (`meta.backup = "stop"`).
- A Consul service `<job_name>` on `s3_port`, health-checked on the master, bound
  to the internal host network. Prometheus metrics on `metrics_port`.
- A secret key per identity in Vault at
  `<vault_kv_path>/<namespace>/<job_name>/keys`, keyed by name. A client reads its
  own from there; its access key is the identity name.

## Inputs

| Name | Default | What |
| --- | --- | --- |
| `vault_kv_path` | — | Vault KV v2 mount the platform gives |
| `identities` | — | `[{name, actions}]`; actions granted on the bucket |
| `bucket` | `lake` | the S3 bucket |
| `job_name` | `seaweedfs` | Nomad job and Consul service name |
| `namespace` | `default` | Nomad namespace |
| `datacenters` | `["*"]` | Nomad datacenters |
| `image` | `chrislusf/seaweedfs:3.80` | image, pinned |
| `s3_port` | `8333` | S3 API port |
| `master_port` | `9333` | master / health port |
| `metrics_port` | `9327` | Prometheus metrics port |
| `volume_size_limit_mb` | `1024` | per-volume size limit |
| `internal_host_network` | `default` | host network it binds to |
| `resources` | `{500, 1024}` | `{cpu, memory}` |
| `service_tags` | `[]` | tags of the Consul service, such as `damstack.provides=<capability>` |
| `service_meta` | `{}` | meta of the Consul service, what else a client needs |

## Outputs

`job_id`, `service_name`, `s3_port`, `bucket`, `identities`, `keys_secret` (Vault
name), `data_volume`.

## Development

```sh
make lint
make module-tests
```

## Service mesh

With `mesh.enabled`, the job gets an Envoy sidecar (transparent proxy) and
Consul config entries: `service-defaults` (`mesh.protocol`, http) and
`service-intentions` allowing only `mesh.allow`. Mesh clients use the S3
endpoint `<job_name>.virtual.consul:8333`. While some clients are not in the
mesh yet, keep `8333` in `mesh.keep_open_ports`; drop it once they all are. The
master (the health check) and metrics ports stay open.
