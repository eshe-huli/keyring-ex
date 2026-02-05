import Config

config :logger, level: :warning

# Use a simpler cluster strategy for tests
config :keyring, :cluster_topologies, []
