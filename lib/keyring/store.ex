defmodule Keyring.Store do
  @moduledoc """
  Content-addressed storage backed by redb (via Rust NIF).

  Every piece of data is stored as a BLAKE3-hashed blob.
  Deduplication is automatic — same content = same hash = stored once.

  Tables:
  - blobs:     BLAKE3Hash → raw bytes
  - documents: DocumentId → DocumentMeta (JSON)
  - doc_data:  DocumentId → CRDT state bytes
  """

  alias Keyring.Native

  @type blob_hash :: <<_::256>>

  @doc "Open or create a content store at the given path."
  @spec open(String.t()) :: {:ok, reference()} | {:error, term()}
  def open(path) do
    Native.store_open(path)
  end

  @doc "Store a blob. Returns the BLAKE3 hash."
  @spec put_blob(reference(), binary()) :: {:ok, blob_hash()} | {:error, term()}
  def put_blob(store, data) when is_binary(data) do
    Native.store_put_blob(store, data)
  end

  @doc "Retrieve a blob by its BLAKE3 hash."
  @spec get_blob(reference(), blob_hash()) :: {:ok, binary()} | {:error, :not_found}
  def get_blob(store, hash) do
    Native.store_get_blob(store, hash)
  end

  @doc "Check if a blob exists."
  @spec has_blob?(reference(), blob_hash()) :: boolean()
  def has_blob?(store, hash) do
    Native.store_has_blob(store, hash)
  end

  @doc "Store a document (metadata + CRDT state)."
  @spec put_document(reference(), map()) :: :ok | {:error, term()}
  def put_document(store, document) do
    Native.store_put_document(store, document)
  end

  @doc "Retrieve a document by ID."
  @spec get_document(reference(), binary()) :: {:ok, map()} | {:error, :not_found}
  def get_document(store, id) do
    Native.store_get_document(store, id)
  end

  @doc "List documents in a keyring."
  @spec list_documents(reference(), binary()) :: {:ok, [map()]}
  def list_documents(store, keyring_id) do
    Native.store_list_documents(store, keyring_id)
  end

  @doc "Delete a document by ID."
  @spec delete_document(reference(), binary()) :: :ok | {:error, :not_found}
  def delete_document(store, id) do
    Native.store_delete_document(store, id)
  end
end
