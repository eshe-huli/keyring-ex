defmodule Keyring.Coordinator do
  @moduledoc """
  Cluster coordinator — presence, task routing, health monitoring.

  Uses DeltaCrdt (AWLWWMap) for eventually-consistent shared state:
  - Node presence (heartbeats, capabilities)
  - Task assignments and load balancing
  - Health status per node

  Broadcasts state changes over PubSub so other modules can react.
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

  @doc "Route a task to the best available node."
  def route_task(task_type, payload) do
    GenServer.call(__MODULE__, {:route_task, task_type, payload})
  end

  @doc "Callback for DeltaCrdt on_diffs — broadcasts state changes."
  def on_state_change(diffs) do
    Phoenix.PubSub.broadcast(Keyring.PubSub, "cluster:state", {:state_changed, diffs})
  end

  # ── GenServer callbacks ──

  @impl true
  def init(_opts) do
    schedule_heartbeat()

    state = %{
      node_id: nil,
      capabilities: %{},
      started_at: System.monotonic_time(:millisecond)
    }

    {:ok, state}
  end

  @impl true
  def handle_call({:register, capabilities}, _from, state) do
    node_key = "node:#{node()}"

    DeltaCrdt.put(Keyring.ClusterState, node_key, %{
      node: node(),
      capabilities: capabilities,
      status: :active,
      last_heartbeat: System.system_time(:millisecond)
    })

    Logger.info("[Coordinator] Registered node #{node()} with capabilities: #{inspect(capabilities)}")
    {:reply, :ok, %{state | capabilities: capabilities}}
  end

  @impl true
  def handle_call(:active_nodes, _from, state) do
    now = System.system_time(:millisecond)
    all_state = DeltaCrdt.to_map(Keyring.ClusterState)

    active =
      all_state
      |> Enum.filter(fn {key, val} ->
        String.starts_with?(key, "node:") &&
          val.status == :active &&
          now - val.last_heartbeat < @node_timeout
      end)
      |> Enum.map(fn {_key, val} -> val end)

    {:reply, active, state}
  end

  @impl true
  def handle_call({:route_task, task_type, _payload}, _from, state) do
    nodes = DeltaCrdt.to_map(Keyring.ClusterState)

    # Simple round-robin for now — pick node with matching capability
    target =
      nodes
      |> Enum.filter(fn {key, val} ->
        String.starts_with?(key, "node:") &&
          val.status == :active &&
          Map.get(val.capabilities, task_type, false)
      end)
      |> Enum.map(fn {_key, val} -> val.node end)
      |> Enum.shuffle()
      |> List.first()

    {:reply, target, state}
  end

  @impl true
  def handle_info(:heartbeat, state) do
    node_key = "node:#{node()}"

    DeltaCrdt.put(Keyring.ClusterState, node_key, %{
      node: node(),
      capabilities: state.capabilities,
      status: :active,
      last_heartbeat: System.system_time(:millisecond)
    })

    schedule_heartbeat()
    {:noreply, state}
  end

  defp schedule_heartbeat do
    Process.send_after(self(), :heartbeat, @heartbeat_interval)
  end
end
