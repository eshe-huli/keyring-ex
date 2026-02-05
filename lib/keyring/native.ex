defmodule Keyring.Native do
  @moduledoc """
  Rust NIF bindings via Rustler.

  This module defines the NIF function stubs. The actual implementations
  live in native/keyring_nif/src/lib.rs and are loaded at runtime.

  Functions cover:
  - Ed25519 key generation, signing, verification
  - BLAKE3 hashing
  - redb content store operations
  - QUIC transport (quinn)
  """

  use Rustler,
    otp_app: :keyring,
    crate: "keyring_nif"

  # ── Identity / Crypto ──

  @doc "Generate Ed25519 keypair. Returns %{secret: binary, public: binary, node_id: binary}."
  def generate_keypair(), do: :erlang.nif_error(:nif_not_loaded)

  @doc "BLAKE3 hash of data."
  def blake3_hash(_data), do: :erlang.nif_error(:nif_not_loaded)

  @doc "Ed25519 sign."
  def ed25519_sign(_data, _secret_key), do: :erlang.nif_error(:nif_not_loaded)

  @doc "Ed25519 verify."
  def ed25519_verify(_data, _signature, _public_key), do: :erlang.nif_error(:nif_not_loaded)

  # ── Content Store (redb) ──

  @doc "Open a redb content store at path."
  def store_open(_path), do: :erlang.nif_error(:nif_not_loaded)

  @doc "Store a blob, return its BLAKE3 hash."
  def store_put_blob(_store, _data), do: :erlang.nif_error(:nif_not_loaded)

  @doc "Get a blob by hash."
  def store_get_blob(_store, _hash), do: :erlang.nif_error(:nif_not_loaded)

  @doc "Check if a blob exists."
  def store_has_blob(_store, _hash), do: :erlang.nif_error(:nif_not_loaded)

  @doc "Store a document."
  def store_put_document(_store, _doc), do: :erlang.nif_error(:nif_not_loaded)

  @doc "Get a document by ID."
  def store_get_document(_store, _id), do: :erlang.nif_error(:nif_not_loaded)

  @doc "List documents in a keyring."
  def store_list_documents(_store, _keyring_id), do: :erlang.nif_error(:nif_not_loaded)

  @doc "Delete a document."
  def store_delete_document(_store, _id), do: :erlang.nif_error(:nif_not_loaded)

  # ── QUIC Transport ──

  @doc "Connect to a QUIC endpoint."
  def quic_connect(_host, _port), do: :erlang.nif_error(:nif_not_loaded)

  @doc "Send data over QUIC."
  def quic_send(_conn, _data), do: :erlang.nif_error(:nif_not_loaded)

  @doc "Receive data from QUIC."
  def quic_recv(_conn, _timeout_ms), do: :erlang.nif_error(:nif_not_loaded)

  @doc "Close QUIC connection."
  def quic_close(_conn), do: :erlang.nif_error(:nif_not_loaded)

  @doc "Start QUIC listener."
  def quic_listen(_port, _opts), do: :erlang.nif_error(:nif_not_loaded)

  @doc "Accept QUIC connection."
  def quic_accept(_listener), do: :erlang.nif_error(:nif_not_loaded)
end
