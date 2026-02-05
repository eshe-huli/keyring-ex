import Config

# Keyring mesh runtime configuration

# libcluster topology — how nodes discover each other
config :keyring, :cluster_topologies, [
  keyring: [
    strategy: Cluster.Strategy.Gossip,
    config: [
      port: 45892,
      if_addr: "0.0.0.0",
      multicast_if: "0.0.0.0",
      multicast_addr: "230.1.1.251",
      multicast_ttl: 1
    ]
  ]
]

# Content store path
config :keyring, :store_path, "~/.keyring/store"

# Node identity path
config :keyring, :identity_path, "~/.keyring/identity"

# Rustler NIF configuration
config :keyring, Keyring.Native,
  crate: "keyring_nif",
  path: "native/keyring_nif"

# Import environment-specific config
import_config "#{config_env()}.exs"
