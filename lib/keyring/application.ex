defmodule Keyring.Application do
  @moduledoc """
  Keyring OTP Application — distributed agent mesh runtime.

  Starts the supervision tree:
  - libcluster for node discovery
  - Horde for distributed process registry & supervision
  - DeltaCrdt for shared cluster state
  - Phoenix.PubSub for event broadcasting
  - Keyring.Coordinator for presence & task routing
  - Keyring.Sync for Merkle DAG synchronization
  """

  use Application

  @impl true
  def start(_type, _args) do
    topologies = Application.get_env(:keyring, :cluster_topologies, [])

    children = [
      # Cluster discovery
      {Cluster.Supervisor, [topologies, [name: Keyring.ClusterSupervisor]]},

      # PubSub for internal event broadcasting
      {Phoenix.PubSub, name: Keyring.PubSub},

      # Distributed process registry (Horde)
      {Horde.Registry, [name: Keyring.Registry, keys: :unique, members: :auto]},

      # Distributed dynamic supervisor (Horde)
      {Horde.DynamicSupervisor, [name: Keyring.DynamicSupervisor, strategy: :one_for_one, members: :auto]},

      # Shared cluster state via CRDT
      {DeltaCrdt,
       [
         crdt: DeltaCrdt.AWLWWMap,
         name: Keyring.ClusterState,
         on_diffs: {Keyring.Coordinator, :on_state_change, []}
       ]},

      # Coordinator — presence, routing, health
      Keyring.Coordinator,

      # Merkle DAG sync engine
      Keyring.Sync
    ]

    opts = [strategy: :one_for_one, name: Keyring.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
