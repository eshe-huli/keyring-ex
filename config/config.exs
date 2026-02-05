import Config

# Keyring mesh runtime configuration

# libcluster topology — how nodes discover each other
#
# Epmd strategy: reliable on any host, just list the known peers.
# For LAN/multicast environments, swap to Cluster.Strategy.Gossip.
config :keyring, :cluster_topologies, [
  keyring: [
    strategy: Cluster.Strategy.Epmd,
    config: [
      hosts: [
        :"keyring1@127.0.0.1",
        :"keyring2@127.0.0.1"
      ]
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
