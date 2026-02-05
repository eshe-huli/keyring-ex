defmodule Keyring.Transport do
  @moduledoc """
  Pluggable transport behaviour for node-to-node communication.

  Implementations can use QUIC (default, via Rust NIF), TCP, WebSocket, etc.
  The mesh doesn't care how bytes move — only that they do, reliably.
  """

  @type endpoint :: {String.t(), non_neg_integer()}
  @type conn :: reference()

  @doc "Connect to a remote endpoint."
  @callback connect(endpoint()) :: {:ok, conn()} | {:error, term()}

  @doc "Send data on an open connection."
  @callback send(conn(), binary()) :: :ok | {:error, term()}

  @doc "Receive data (blocking up to timeout_ms)."
  @callback recv(conn(), timeout :: non_neg_integer()) :: {:ok, binary()} | {:error, term()}

  @doc "Close a connection."
  @callback close(conn()) :: :ok

  @doc "Listen for incoming connections."
  @callback listen(port :: non_neg_integer(), opts :: keyword()) :: {:ok, reference()} | {:error, term()}

  @doc "Accept an incoming connection."
  @callback accept(listener :: reference()) :: {:ok, conn()} | {:error, term()}
end

defmodule Keyring.Transport.QUIC do
  @moduledoc """
  QUIC transport implementation via Rust NIF (quinn).

  Provides multiplexed, encrypted connections with built-in TLS 1.3.
  Ideal for the mesh: handles NAT traversal, 0-RTT reconnection,
  and per-stream flow control.
  """

  @behaviour Keyring.Transport

  alias Keyring.Native

  @impl true
  def connect({host, port}) do
    Native.quic_connect(host, port)
  end

  @impl true
  def send(conn, data) do
    Native.quic_send(conn, data)
  end

  @impl true
  def recv(conn, timeout_ms) do
    Native.quic_recv(conn, timeout_ms)
  end

  @impl true
  def close(conn) do
    Native.quic_close(conn)
  end

  @impl true
  def listen(port, opts \\ []) do
    Native.quic_listen(port, opts)
  end

  @impl true
  def accept(listener) do
    Native.quic_accept(listener)
  end
end
