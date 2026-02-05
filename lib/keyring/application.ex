defmodule Keyring.Application do
  @moduledoc """
  Keyring OTP Application — distributed agent mesh runtime.

  Starts the supervision tree:
  - libcluster for node discovery (gossip multicast)
  - Horde for distributed process registry & supervision
  - DeltaCrdt for shared cluster state
  - Phoenix.PubSub for event broadcasting
  - Keyring.ClusterHandler for nodeup/nodedown → CRDT neighbour wiring
  - Keyring.Coordinator for presence & task routing
  - Keyring.Sync for Merkle DAG synchronization
  """

  use Application

  @impl true
  def start(_type, _args) do
    topologies = Application.get_env(:keyring, :cluster_topologies, [])

    children = [
      # ── networking ──
      {Cluster.Supervisor, [topologies, [name: Keyring.ClusterSupervisor]]},

      # ── pubsub ──
      {Phoenix.PubSub, name: Keyring.PubSub},

      # ── distributed registry / supervisor ──
      {Horde.Registry, [name: Keyring.Registry, keys: :unique, members: :auto]},
      {Horde.DynamicSupervisor,
       [name: Keyring.DynamicSupervisor, strategy: :one_for_one, members: :auto]},

      # ── shared cluster state via CRDT ──
      {DeltaCrdt,
       [
         crdt: DeltaCrdt.AWLWWMap,
         name: Keyring.ClusterState,
         on_diffs: {Keyring.Coordinator, :on_state_change, []}
       ]},

      # ── cluster topology handler (wires CRDT neighbours on nodeup/nodedown) ──
      Keyring.ClusterHandler,

      # ── coordinator: presence, routing, health ──
      Keyring.Coordinator,

      # ── merkle DAG sync engine ──
      Keyring.Sync
    ]

    opts = [strategy: :one_for_one, name: Keyring.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
