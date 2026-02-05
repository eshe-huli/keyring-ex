defmodule Keyring.MixProject do
  use Mix.Project

  def project do
    [
      app: :keyring,
      version: "0.1.0",
      elixir: "~> 1.14",
      start_permanent: Mix.env() == :prod,
      compilers: Mix.compilers(),
      deps: deps()
    ]
  end

  def application do
    [
      extra_applications: [:logger],
      mod: {Keyring.Application, []}
    ]
  end

  defp deps do
    [
      # Rust NIFs
      {:rustler, "~> 0.34.0"},

      # Clustering
      {:libcluster, "~> 3.3"},

      # Distributed process registry & supervisor
      {:horde, "~> 0.9"},

      # CRDTs for distributed state
      {:delta_crdt, "~> 0.6"},

      # PubSub
      {:phoenix_pubsub, "~> 2.1"},

      # Serialization
      {:jason, "~> 1.4"},
      {:protobuf, "~> 0.12"}
    ]
  end
end
