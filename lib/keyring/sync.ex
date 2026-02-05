defmodule Keyring.Sync do
  @moduledoc """
  Merkle DAG sync protocol.

  Synchronizes content-addressed data between nodes using hash trees:
  1. Exchange root hashes to detect divergence
  2. Walk the DAG to find missing nodes
  3. Transfer only the delta (missing blobs/documents)

  Subscribes to cluster topology events so it knows which peers are available
  and automatically triggers sync rounds when new nodes join.
  """

  use GenServer

  require Logger

  @sync_interval :timer.seconds(30)

  # ── Public API ──

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @doc "Trigger a sync with a specific node."
  def sync_with(target_node) do
    GenServer.cast(__MODULE__, {:sync_with, target_node})
  end

  @doc "Announce that new content is available locally."
  def announce(content_hash) do
    Phoenix.PubSub.broadcast(
      Keyring.PubSub,
      "sync:announce",
      {:new_content, node(), content_hash}
    )
  end

  @doc "Get current sync status."
  def status do
    GenServer.call(__MODULE__, :status)
  end

  @doc "Return the list of peers we are tracking for sync."
  def connected_peers do
    GenServer.call(__MODULE__, :connected_peers)
  end

  # ── GenServer callbacks ──

  @impl true
  def init(_opts) do
    Phoenix.PubSub.subscribe(Keyring.PubSub, "sync:announce")
    Phoenix.PubSub.subscribe(Keyring.PubSub, "cluster:topology")
    schedule_sync()

    state = %{
      root_hash: nil,
      sync_cursors: %{},
      last_sync: nil,
      syncing: false,
      peers: MapSet.new()
    }

    {:ok, state}
  end

  @impl true
  def handle_call(:status, _from, state) do
    info =
      state
      |> Map.take([:root_hash, :last_sync, :syncing])
      |> Map.put(:peer_count, MapSet.size(state.peers))

    {:reply, info, state}
  end

  @impl true
  def handle_call(:connected_peers, _from, state) do
    {:reply, MapSet.to_list(state.peers), state}
  end

  @impl true
  def handle_cast({:sync_with, target_node}, state) do
    Logger.info("[Sync] Starting sync with #{target_node}")
    # TODO: implement full Merkle DAG exchange
    # 1. Send our root hash to target
    # 2. Receive their root hash
    # 3. Walk tree to find divergences
    # 4. Exchange missing blobs
    {:noreply, %{state | syncing: true}}
  end

  # ── Info handlers ──

  @impl true
  def handle_info({:new_content, from_node, content_hash}, state) do
    if from_node != node() do
      Logger.debug("[Sync] Node #{from_node} announced new content: #{inspect(content_hash)}")
      # TODO: request missing content from announcing node
    end

    {:noreply, state}
  end

  def handle_info({:nodeup, peer}, state) do
    Logger.info("[Sync] Peer joined: #{peer} — triggering sync")
    new_peers = MapSet.put(state.peers, peer)

    # Kick off an immediate sync with the new peer
    sync_with(peer)

    {:noreply, %{state | peers: new_peers}}
  end

  def handle_info({:nodedown, peer}, state) do
    Logger.info("[Sync] Peer left: #{peer}")
    {:noreply, %{state | peers: MapSet.delete(state.peers, peer)}}
  end

  def handle_info(:periodic_sync, state) do
    peers = Keyring.ClusterHandler.peers()

    if peers != [] do
      Logger.debug("[Sync] Periodic sync with #{length(peers)} peer(s)")
    end

    Enum.each(peers, fn peer ->
      sync_with(peer)
    end)

    schedule_sync()
    {:noreply, %{state | last_sync: System.system_time(:millisecond)}}
  end

  defp schedule_sync do
    Process.send_after(self(), :periodic_sync, @sync_interval)
  end
end
