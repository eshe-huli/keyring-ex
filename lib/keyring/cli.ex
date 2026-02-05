defmodule Keyring.CLI do
  @moduledoc """
  CLI commands for the Keyring mesh runtime.

  Usage:
    keyring init              — generate node identity & config
    keyring start             — start the node
    keyring status            — show node status & cluster info
    keyring identity          — display node ID & public key
    keyring peers             — list connected peers
    keyring store put <file>  — store a file as content-addressed blob
    keyring store get <hash>  — retrieve a blob by hash
    keyring sync              — trigger manual sync
    keyring plugin load <path> — load a WASM plugin
  """

  def main(args) do
    args
    |> parse_args()
    |> run()
  end

  defp parse_args(args) do
    case args do
      ["init" | rest] -> {:init, rest}
      ["start" | rest] -> {:start, rest}
      ["status" | _] -> {:status, []}
      ["identity" | _] -> {:identity, []}
      ["peers" | _] -> {:peers, []}
      ["store", "put" | rest] -> {:store_put, rest}
      ["store", "get" | rest] -> {:store_get, rest}
      ["sync" | _] -> {:sync, []}
      ["plugin", "load" | rest] -> {:plugin_load, rest}
      ["help" | _] -> {:help, []}
      _ -> {:help, []}
    end
  end

  defp run({:init, _args}) do
    IO.puts("Generating node identity...")
    keypair = Keyring.Identity.generate_keypair()
    IO.puts("Node ID: #{Base.encode16(keypair.node_id, case: :lower)}")
    IO.puts("Identity saved.")
  end

  defp run({:status, _}) do
    IO.puts("Keyring Node Status")
    IO.puts("---")
    IO.puts("Node: #{node()}")

    case Keyring.Coordinator.active_nodes() do
      nodes when is_list(nodes) ->
        IO.puts("Active peers: #{length(nodes)}")
      _ ->
        IO.puts("Active peers: unknown")
    end

    sync_status = Keyring.Sync.status()
    IO.puts("Last sync: #{inspect(sync_status.last_sync)}")
  end

  defp run({:identity, _}) do
    IO.puts("TODO: display stored identity")
  end

  defp run({:peers, _}) do
    nodes = Keyring.Coordinator.active_nodes()
    IO.puts("Connected peers (#{length(nodes)}):")

    Enum.each(nodes, fn n ->
      IO.puts("  #{n.node} — #{n.status}")
    end)
  end

  defp run({:store_put, [path]}) do
    IO.puts("Storing: #{path}")
    # TODO: open store, read file, put blob
  end

  defp run({:store_get, [hash]}) do
    IO.puts("Retrieving: #{hash}")
    # TODO: open store, get blob, write to stdout
  end

  defp run({:sync, _}) do
    IO.puts("Triggering sync...")
    Keyring.Coordinator.active_nodes()
    |> Enum.each(fn n ->
      if n.node != node(), do: Keyring.Sync.sync_with(n.node)
    end)
  end

  defp run({:plugin_load, [path]}) do
    IO.puts("Loading plugin: #{path}")
    IO.puts("Not yet implemented.")
  end

  defp run({:help, _}) do
    IO.puts(@moduledoc)
  end

  defp run(_) do
    run({:help, []})
  end
end
