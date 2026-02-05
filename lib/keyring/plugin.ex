defmodule Keyring.Plugin do
  @moduledoc """
  WASM plugin runtime — execute sandboxed plugins on the mesh.

  Plugins are WASM modules that can:
  - Read from the content store
  - Publish events to PubSub
  - Call identity functions (signing, hashing)
  - NOT access the network directly (sandbox)

  The runtime will use wasmtime via Rust NIF.
  This is a placeholder — full implementation pending.
  """

  @type plugin_id :: String.t()
  @type plugin_manifest :: %{
          id: plugin_id(),
          name: String.t(),
          version: String.t(),
          wasm_hash: binary(),
          permissions: [atom()]
        }

  @doc "Load a WASM plugin from a blob hash."
  @spec load(binary()) :: {:ok, plugin_manifest()} | {:error, term()}
  def load(_wasm_hash) do
    {:error, :not_implemented}
  end

  @doc "Execute a plugin function."
  @spec call(plugin_id(), String.t(), [term()]) :: {:ok, term()} | {:error, term()}
  def call(_plugin_id, _function, _args) do
    {:error, :not_implemented}
  end

  @doc "List loaded plugins."
  @spec list() :: [plugin_manifest()]
  def list do
    []
  end

  @doc "Unload a plugin."
  @spec unload(plugin_id()) :: :ok
  def unload(_plugin_id) do
    :ok
  end
end
