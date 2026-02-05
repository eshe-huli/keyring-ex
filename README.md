# Keyring

Distributed agent mesh runtime — Elixir/OTP implementation.

Keyring is a peer-to-peer network of autonomous nodes that share data through
content-addressed storage, form trust groups (keyrings), and coordinate work
using CRDTs for eventually-consistent distributed state.

## Architecture

```
┌─────────────────────────────────────────────────┐
│                  Keyring Node                    │
│                                                  │
│  ┌──────────┐  ┌───────────┐  ┌──────────────┐  │
│  │ Identity  │  │   Store   │  │ Coordinator  │  │
│  │ Ed25519   │  │   redb    │  │   DeltaCrdt  │  │
│  │ BLAKE3    │  │ BLAKE3→Blob│  │  Presence    │  │
│  └──────────┘  └───────────┘  └──────────────┘  │
│                                                  │
│  ┌──────────┐  ┌───────────┐  ┌──────────────┐  │
│  │   Sync   │  │ Transport │  │   Plugin     │  │
│  │ MerkleDAG│  │   QUIC    │  │   WASM       │  │
│  └──────────┘  └───────────┘  └──────────────┘  │
│                                                  │
│  ═══════════ Rust NIFs (Rustler) ═══════════════ │
└─────────────────────────────────────────────────┘
```

## Modules

| Module | Purpose |
|--------|---------|
| `Keyring.Identity` | Ed25519 keypair gen, BLAKE3 hashing, node IDs |
| `Keyring.Store` | Content-addressed storage (redb backend) |
| `Keyring.Coordinator` | Presence, task routing, health via DeltaCrdt |
| `Keyring.Sync` | Merkle DAG synchronization protocol |
| `Keyring.Transport` | Pluggable transport behaviour (QUIC default) |
| `Keyring.Plugin` | WASM plugin runtime (placeholder) |
| `Keyring.Native` | Rust NIF bindings via Rustler |

## Prerequisites

- Elixir ≥ 1.14
- Erlang/OTP ≥ 25
- Rust (stable) — for Rustler NIFs

## Getting Started

```bash
# Fetch dependencies
mix deps.get

# Compile (includes Rust NIF)
mix compile

# Start interactive shell
iex -S mix

# Generate a keypair
iex> Keyring.Identity.generate_keypair()
```

## Development

```bash
# Run tests
mix test

# Format code
mix format

# Start a named node for clustering
iex --sname node1 -S mix
```

## Rust NIFs

The `native/keyring_nif/` crate provides:
- **Ed25519**: key generation, signing, verification (via `ed25519-dalek`)
- **BLAKE3**: content hashing
- **redb**: embedded key-value store (pending)
- **QUIC**: transport via quinn (pending)

## License

Private — all rights reserved.
