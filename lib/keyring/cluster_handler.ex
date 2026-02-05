defmodule Keyring.ClusterHandler do
  @moduledoc """
  Listens for :net_kernel nodeup/nodedown events and wires up
  DeltaCrdt neighbours so that cluster state replicates automatically.
  """

  use GenServer
  require Logger

  # ── Public API ──

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @doc "Return the set of nodes we currently consider peers."
  def peers do
    GenServer.call(__MODULE__, :peers)
  end

  # ── GenServer callbacks ──

  @impl true
  def init(_opts) do
    :net_kernel.monitor_nodes(true, node_type: :visible)
    Logger.info("[ClusterHandler] Monitoring node connections")

    # Pick up any nodes that connected before we started monitoring
    existing = Node.list()

    if existing != [] do
      Logger.info("[ClusterHandler] Found existing peers: #{inspect(existing)}")
      set_crdt_neighbours(existing)
    end

    {:ok, %{peers: MapSet.new(existing)}}
  end

  @impl true
  def handle_call(:peers, _from, state) do
    {:reply, MapSet.to_list(state.peers), state}
  end

  @impl true
  def handle_info({:nodeup, node, _info}, state) do
    Logger.info("[ClusterHandler] 🟢 Node connected: #{node}")
    new_peers = MapSet.put(state.peers, node)
    set_crdt_neighbours(MapSet.to_list(new_peers))

    Phoenix.PubSub.broadcast(Keyring.PubSub, "cluster:topology", {:nodeup, node})
    {:noreply, %{state | peers: new_peers}}
  end

  @impl true
  def handle_info({:nodedown, node, _info}, state) do
    Logger.warn("[ClusterHandler] 🔴 Node disconnected: #{node}")
    new_peers = MapSet.delete(state.peers, node)
    set_crdt_neighbours(MapSet.to_list(new_peers))

    # Mark the node stale in the CRDT so coordinator picks it up
    node_key = "node:#{node}"

    case DeltaCrdt.to_map(Keyring.ClusterState) |> Map.get(node_key) do
      nil ->
        :ok

      entry ->
        DeltaCrdt.put(Keyring.ClusterState, node_key, %{entry | status: :disconnected})
    end

    Phoenix.PubSub.broadcast(Keyring.PubSub, "cluster:topology", {:nodedown, node})
    {:noreply, %{state | peers: new_peers}}
  end

  # ── Helpers ──

  defp set_crdt_neighbours(peer_list) do
    neighbours =
      Enum.map(peer_list, fn n ->
        {Keyring.ClusterState, n}
      end)

    DeltaCrdt.set_neighbours(Keyring.ClusterState, neighbours)
    Logger.debug("[ClusterHandler] CRDT neighbours set to: #{inspect(neighbours)}")
  end
end
