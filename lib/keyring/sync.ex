defmodule Keyring.Sync do
  @moduledoc """
  Merkle DAG sync protocol.

  Synchronizes content-addressed data between nodes using hash trees:
  1. Exchange root hashes to detect divergence
  2. Walk the DAG to find missing nodes
  3. Transfer only the delta (missing blobs/documents)

  Uses PubSub to announce new content and trigger sync rounds.
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

  # ── GenServer callbacks ──

  @impl true
  def init(_opts) do
    Phoenix.PubSub.subscribe(Keyring.PubSub, "sync:announce")
    schedule_sync()

    state = %{
      root_hash: nil,
      sync_cursors: %{},
      last_sync: nil,
      syncing: false
    }

    {:ok, state}
  end

  @impl true
  def handle_call(:status, _from, state) do
    {:reply, Map.take(state, [:root_hash, :last_sync, :syncing]), state}
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

  @impl true
  def handle_info({:new_content, from_node, content_hash}, state) do
    if from_node != node() do
      Logger.debug("[Sync] Node #{from_node} announced new content: #{inspect(content_hash)}")
      # TODO: request missing content from announcing node
    end

    {:noreply, state}
  end

  @impl true
  def handle_info(:periodic_sync, state) do
    active_nodes = Keyring.Coordinator.active_nodes()

    Enum.each(active_nodes, fn node_info ->
      if node_info.node != node() do
        sync_with(node_info.node)
      end
    end)

    schedule_sync()
    {:noreply, %{state | last_sync: System.system_time(:millisecond)}}
  end

  defp schedule_sync do
    Process.send_after(self(), :periodic_sync, @sync_interval)
  end
end
