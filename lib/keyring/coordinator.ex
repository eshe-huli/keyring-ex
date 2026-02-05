defmodule Keyring.Coordinator do
  @moduledoc """
  Cluster coordinator — presence, task routing, health monitoring.

  Uses DeltaCrdt (AWLWWMap) for eventually-consistent shared state:
  - Node presence (heartbeats, capabilities)
  - Task assignments and load balancing
  - Health status per node

  On start the node automatically registers itself. A heartbeat every 5 s
  keeps the presence entry fresh. When DeltaCrdt syncs with neighbours and
  diffs arrive via `on_state_change/1`, we update the local presence map
  and broadcast over PubSub so other modules can react.
  """

  use GenServer

  require Logger

  @heartbeat_interval :timer.seconds(5)
  @node_timeout :timer.seconds(30)

  # ── Public API ──

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @doc "Register this node in the cluster state."
  def register_self(capabilities \\ %{}) do
    GenServer.call(__MODULE__, {:register, capabilities})
  end

  @doc "Get list of active nodes."
  def active_nodes do
    GenServer.call(__MODULE__, :active_nodes)
  end

  @doc "Get the current presence map (node -> info)."
  def presence do
    GenServer.call(__MODULE__, :presence)
  end

  @doc "Route a task to the best available node."
  def route_task(task_type, payload) do
    GenServer.call(__MODULE__, {:route_task, task_type, payload})
  end

  @doc """
  Callback for DeltaCrdt `on_diffs`.

  Invoked in the CRDT process whenever diffs are applied (local or remote).
  We forward to the Coordinator GenServer so it can rebuild its presence map.
  """
  def on_state_change(diffs) do
    # Fire-and-forget cast — the CRDT process should not block
    GenServer.cast(__MODULE__, {:crdt_diffs, diffs})
  end

  # ── GenServer callbacks ──

  @impl true
  def init(_opts) do
    # Auto-register this node
    node_key = "node:#{node()}"

    DeltaCrdt.put(Keyring.ClusterState, node_key, %{
      node: node(),
      capabilities: %{},
      status: :active,
      last_heartbeat: System.system_time(:millisecond),
      started_at: System.system_time(:millisecond)
    })

    Logger.info("[Coordinator] Node #{node()} registered in cluster state")

    # Subscribe to topology events for logging
    Phoenix.PubSub.subscribe(Keyring.PubSub, "cluster:topology")
    Phoenix.PubSub.subscribe(Keyring.PubSub, "cluster:state")

    schedule_heartbeat()

    state = %{
      capabilities: %{},
      presence: %{},
      started_at: System.system_time(:millisecond)
    }

    {:ok, rebuild_presence(state)}
  end

  @impl true
  def handle_call({:register, capabilities}, _from, state) do
    node_key = "node:#{node()}"

    DeltaCrdt.put(Keyring.ClusterState, node_key, %{
      node: node(),
      capabilities: capabilities,
      status: :active,
      last_heartbeat: System.system_time(:millisecond),
      started_at: state.started_at
    })

    Logger.info("[Coordinator] Updated capabilities: #{inspect(capabilities)}")
    {:reply, :ok, rebuild_presence(%{state | capabilities: capabilities})}
  end

  @impl true
  def handle_call(:active_nodes, _from, state) do
    now = System.system_time(:millisecond)

    active =
      state.presence
      |> Map.values()
      |> Enum.filter(fn val ->
        val.status == :active && now - val.last_heartbeat < @node_timeout
      end)

    {:reply, active, state}
  end

  @impl true
  def handle_call(:presence, _from, state) do
    {:reply, state.presence, state}
  end

  @impl true
  def handle_call({:route_task, task_type, _payload}, _from, state) do
    target =
      state.presence
      |> Map.values()
      |> Enum.filter(fn val ->
        val.status == :active && Map.get(val.capabilities, task_type, false)
      end)
      |> Enum.map(& &1.node)
      |> Enum.shuffle()
      |> List.first()

    {:reply, target, state}
  end

  # ── Casts ──

  @impl true
  def handle_cast({:crdt_diffs, diffs}, state) do
    # Log interesting diffs
    Enum.each(diffs, fn
      {:add, key, value} ->
        if String.starts_with?(key, "node:") do
          Logger.debug("[Coordinator] CRDT add: #{key} → #{inspect(value.status)}")
        end

      {:remove, key} ->
        if String.starts_with?(key, "node:") do
          Logger.debug("[Coordinator] CRDT remove: #{key}")
        end

      _ ->
        :ok
    end)

    new_state = rebuild_presence(state)

    Phoenix.PubSub.broadcast(
      Keyring.PubSub,
      "cluster:presence",
      {:presence_updated, new_state.presence}
    )

    {:noreply, new_state}
  end

  # ── Info handlers ──

  @impl true
  def handle_info(:heartbeat, state) do
    node_key = "node:#{node()}"

    DeltaCrdt.put(Keyring.ClusterState, node_key, %{
      node: node(),
      capabilities: state.capabilities,
      status: :active,
      last_heartbeat: System.system_time(:millisecond),
      started_at: state.started_at
    })

    schedule_heartbeat()
    {:noreply, state}
  end

  # Topology events (for logging)
  def handle_info({:nodeup, node}, state) do
    Logger.info("[Coordinator] Topology: node up → #{node}")
    {:noreply, state}
  end

  def handle_info({:nodedown, node}, state) do
    Logger.info("[Coordinator] Topology: node down → #{node}")
    {:noreply, rebuild_presence(state)}
  end

  # PubSub state changes (from on_state_change broadcast — ignore our own)
  def handle_info({:state_changed, _diffs}, state), do: {:noreply, state}

  # ── Helpers ──

  defp rebuild_presence(state) do
    all = DeltaCrdt.to_map(Keyring.ClusterState)

    presence =
      all
      |> Enum.filter(fn {key, _} -> String.starts_with?(key, "node:") end)
      |> Enum.into(%{}, fn {key, val} -> {key, val} end)

    %{state | presence: presence}
  end

  defp schedule_heartbeat do
    Process.send_after(self(), :heartbeat, @heartbeat_interval)
  end
end
