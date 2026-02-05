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
│  ┌──────────────────────────────────────────────┐│
│  │  ClusterHandler — nodeup/down → CRDT wiring  ││
│  └──────────────────────────────────────────────┘│
│                                                  │
│  ═══════════ Rust NIFs (Rustler) ═══════════════ │
└─────────────────────────────────────────────────┘
```

## Modules

| Module | Purpose |
|--------|---------|
| `Keyring.Application` | OTP supervision tree, starts all services |
| `Keyring.ClusterHandler` | Monitors `nodeup`/`nodedown`, wires DeltaCrdt neighbours |
| `Keyring.Coordinator` | Presence, task routing, health via DeltaCrdt + PubSub |
| `Keyring.Sync` | Merkle DAG synchronization protocol |
| `Keyring.Identity` | Ed25519 keypair gen, BLAKE3 hashing, node IDs |
| `Keyring.Store` | Content-addressed storage (redb backend) |
| `Keyring.Transport` | Pluggable transport behaviour (QUIC default) |
| `Keyring.Plugin` | WASM plugin runtime (placeholder) |
| `Keyring.Native` | Rust NIF bindings via Rustler |

## How Clustering Works

1. **libcluster** discovers peers using the configured strategy (Epmd for dev, Gossip for LAN).
2. **ClusterHandler** receives `nodeup`/`nodedown` events from `:net_kernel` and calls `DeltaCrdt.set_neighbours/2` so the CRDT knows who to replicate with.
3. **Coordinator** registers each node in the shared `AWLWWMap` CRDT with heartbeats every 5 s. When diffs arrive from remote nodes, `on_state_change/1` fires and the local presence map is rebuilt.
4. **Sync** subscribes to topology events and triggers Merkle DAG sync rounds with newly joined peers.
5. **Phoenix.PubSub** broadcasts all presence and topology changes so any module can react.

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
```

## Running a Distributed Cluster (2 Nodes)

Open **two terminals** and run:

**Terminal 1:**
```bash
elixir --name keyring1@127.0.0.1 --cookie keyring_secret -S mix run --no-halt
```

**Terminal 2:**
```bash
elixir --name keyring2@127.0.0.1 --cookie keyring_secret -S mix run --no-halt
```

You should see in the logs:
- `[libcluster:keyring] connected to :"keyring2@127.0.0.1"` — nodes discovered each other
- `[ClusterHandler] 🟢 Node connected: keyring2@127.0.0.1` — CRDT neighbours wired
- `[Coordinator] CRDT add: node:keyring2@127.0.0.1 → :active` — presence replicated

Or use the mix task shortcut:
```bash
# Terminal 1
mix keyring.start keyring1

# Terminal 2
mix keyring.start keyring2
```

### Configuration

The default topology uses `Cluster.Strategy.Epmd` with a static host list
(`keyring1@127.0.0.1`, `keyring2@127.0.0.1`). To add more nodes, update
`config/config.exs`:

```elixir
config :keyring, :cluster_topologies, [
  keyring: [
    strategy: Cluster.Strategy.Epmd,
    config: [
      hosts: [
        :"keyring1@127.0.0.1",
        :"keyring2@127.0.0.1",
        :"keyring3@127.0.0.1"
      ]
    ]
  ]
]
```

For LAN multicast discovery, switch to `Cluster.Strategy.Gossip`.

### Verifying the Cluster

From an `iex` session on either node:

```elixir
# List connected Erlang nodes
Node.list()
# => [:"keyring2@127.0.0.1"]

# See all active nodes in the CRDT
Keyring.Coordinator.active_nodes()
# => [%{node: :"keyring1@127.0.0.1", ...}, %{node: :"keyring2@127.0.0.1", ...}]

# See the full presence map
Keyring.Coordinator.presence()

# Check sync peers
Keyring.Sync.connected_peers()
```

## Development

```bash
# Run tests
mix test

# Format code
mix format

# Interactive shell as a named node
iex --name keyring1@127.0.0.1 --cookie keyring_secret -S mix
```

## Rust NIFs

The `native/keyring_nif/` crate provides:
- **Ed25519**: key generation, signing, verification (via `ed25519-dalek`)
- **BLAKE3**: content hashing
- **redb**: embedded key-value store (pending)
- **QUIC**: transport via quinn (pending)

## License

Private — all rights reserved.
