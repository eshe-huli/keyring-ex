defmodule Mix.Tasks.Keyring.Start do
  @moduledoc """
  Start a named Keyring node for clustering.

  Usage:

      mix keyring.start              # starts keyring1@127.0.0.1
      mix keyring.start keyring2     # starts keyring2@127.0.0.1
      mix keyring.start keyring2 --cookie secret  # custom cookie

  The node uses `--name` (full names) so it works on a single machine.
  The default cookie is `keyring_secret`.
  """

  use Mix.Task

  @shortdoc "Start a named Keyring node"

  @impl true
  def run(args) do
    {opts, positional, _} =
      OptionParser.parse(args, strict: [cookie: :string, host: :string])

    node_name = List.first(positional) || "keyring1"
    host = Keyword.get(opts, :host, "127.0.0.1")
    cookie = Keyword.get(opts, :cookie, "keyring_secret")

    full_name = "#{node_name}@#{host}"

    Mix.shell().info("Starting Keyring node: #{full_name}")

    elixir = System.find_executable("elixir") || "elixir"

    cmd_args = [
      "--name",
      full_name,
      "--cookie",
      cookie,
      "-S",
      "mix",
      "run",
      "--no-halt"
    ]

    Mix.shell().info("$ #{elixir} #{Enum.join(cmd_args, " ")}")

    # Replace the current process with the Elixir node
    :os.cmd(String.to_charlist("#{elixir} #{Enum.join(cmd_args, " ")}"))
  end
end
