defmodule Keyring.Identity do
  @moduledoc """
  Cryptographic identity for mesh nodes.

  Wraps Rust NIFs for:
  - Ed25519 keypair generation & signing
  - BLAKE3 hashing
  - NodeId derivation (BLAKE3 of public key)

  Delegates to `Keyring.Native` for the actual cryptographic operations.
  """

  alias Keyring.Native

  @type node_id :: <<_::256>>
  @type keypair :: %{secret: binary(), public: binary(), node_id: node_id()}

  @doc "Generate a new Ed25519 keypair and derive the NodeId."
  @spec generate_keypair() :: keypair()
  def generate_keypair do
    Native.generate_keypair()
  end

  @doc "Derive NodeId from a public key: BLAKE3(pubkey)."
  @spec node_id(binary()) :: node_id()
  def node_id(public_key) when byte_size(public_key) == 32 do
    Native.blake3_hash(public_key)
  end

  @doc "Sign data with a secret key."
  @spec sign(binary(), binary()) :: binary()
  def sign(data, secret_key) do
    Native.ed25519_sign(data, secret_key)
  end

  @doc "Verify a signature against a public key."
  @spec verify(binary(), binary(), binary()) :: boolean()
  def verify(data, signature, public_key) do
    Native.ed25519_verify(data, signature, public_key)
  end

  @doc "BLAKE3 hash of arbitrary data."
  @spec blake3(binary()) :: <<_::256>>
  def blake3(data) do
    Native.blake3_hash(data)
  end

  @doc "Short hex representation of a node ID (first 8 bytes)."
  @spec short_id(node_id()) :: String.t()
  def short_id(<<prefix::binary-size(8), _::binary>>) do
    Base.encode16(prefix, case: :lower)
  end
end
