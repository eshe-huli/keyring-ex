//! Keyring NIF — Rust-backed cryptographic operations for the Elixir mesh runtime.
//!
//! Exposes Ed25519 key generation/signing/verification and BLAKE3 hashing
//! to Elixir via Rustler NIFs. Store and QUIC transport NIFs are stubs
//! for now — will be wired up when redb and quinn are integrated.

use ed25519_dalek::{Signer, SigningKey, Verifier, VerifyingKey};
use rand::rngs::OsRng;
use rustler::{Atom, Binary, Encoder, Env, NewBinary, Term};

mod atoms {
    rustler::atoms! {
        ok,
        error,
        nif_not_loaded,
        not_implemented,
        secret,
        public,
        node_id,
    }
}

// ── Identity / Crypto ──

/// Generate an Ed25519 keypair. Returns a map: %{secret, public, node_id}
#[rustler::nif]
fn generate_keypair(env: Env) -> Term {
    let signing_key = SigningKey::generate(&mut OsRng);
    let verifying_key = signing_key.verifying_key();

    let node_id_hash = blake3::hash(verifying_key.as_bytes());

    let secret_bytes = signing_key.to_bytes();
    let public_bytes = verifying_key.to_bytes();
    let node_id_bytes = node_id_hash.as_bytes();

    let mut secret_bin = NewBinary::new(env, 32);
    secret_bin.as_mut_slice().copy_from_slice(&secret_bytes);

    let mut public_bin = NewBinary::new(env, 32);
    public_bin.as_mut_slice().copy_from_slice(&public_bytes);

    let mut node_id_bin = NewBinary::new(env, 32);
    node_id_bin.as_mut_slice().copy_from_slice(node_id_bytes);

    let map = Term::map_new(env);
    let map = map
        .map_put(atoms::secret().encode(env), Binary::from(secret_bin).to_term(env))
        .unwrap();
    let map = map
        .map_put(atoms::public().encode(env), Binary::from(public_bin).to_term(env))
        .unwrap();
    let map = map
        .map_put(atoms::node_id().encode(env), Binary::from(node_id_bin).to_term(env))
        .unwrap();

    map
}

/// BLAKE3 hash of arbitrary data
#[rustler::nif]
fn blake3_hash<'a>(env: Env<'a>, data: Binary<'a>) -> Binary<'a> {
    let hash = blake3::hash(data.as_slice());
    let mut out = NewBinary::new(env, 32);
    out.as_mut_slice().copy_from_slice(hash.as_bytes());
    out.into()
}

/// Ed25519 sign
#[rustler::nif]
fn ed25519_sign<'a>(env: Env<'a>, data: Binary<'a>, secret_key: Binary<'a>) -> Result<Binary<'a>, Atom> {
    if secret_key.len() != 32 {
        return Err(atoms::error());
    }

    let mut key_bytes = [0u8; 32];
    key_bytes.copy_from_slice(secret_key.as_slice());

    let signing_key = SigningKey::from_bytes(&key_bytes);
    let signature = signing_key.sign(data.as_slice());

    let sig_bytes = signature.to_bytes();
    let mut out = NewBinary::new(env, 64);
    out.as_mut_slice().copy_from_slice(&sig_bytes);
    Ok(out.into())
}

/// Ed25519 verify
#[rustler::nif]
fn ed25519_verify(data: Binary, signature: Binary, public_key: Binary) -> bool {
    if public_key.len() != 32 || signature.len() != 64 {
        return false;
    }

    let mut pub_bytes = [0u8; 32];
    pub_bytes.copy_from_slice(public_key.as_slice());

    let mut sig_bytes = [0u8; 64];
    sig_bytes.copy_from_slice(signature.as_slice());

    let Ok(verifying_key) = VerifyingKey::from_bytes(&pub_bytes) else {
        return false;
    };

    let sig = ed25519_dalek::Signature::from_bytes(&sig_bytes);

    verifying_key.verify(data.as_slice(), &sig).is_ok()
}

// ── Store stubs (redb integration pending) ──

#[rustler::nif]
fn store_open(_path: String) -> (Atom, Atom) {
    (atoms::error(), atoms::not_implemented())
}

#[rustler::nif]
fn store_put_blob(_store: Term, _data: Binary) -> (Atom, Atom) {
    (atoms::error(), atoms::not_implemented())
}

#[rustler::nif]
fn store_get_blob(_store: Term, _hash: Binary) -> (Atom, Atom) {
    (atoms::error(), atoms::not_implemented())
}

#[rustler::nif]
fn store_has_blob(_store: Term, _hash: Binary) -> (Atom, Atom) {
    (atoms::error(), atoms::not_implemented())
}

#[rustler::nif]
fn store_put_document(_store: Term, _doc: Term) -> (Atom, Atom) {
    (atoms::error(), atoms::not_implemented())
}

#[rustler::nif]
fn store_get_document(_store: Term, _id: Binary) -> (Atom, Atom) {
    (atoms::error(), atoms::not_implemented())
}

#[rustler::nif]
fn store_list_documents(_store: Term, _keyring_id: Binary) -> (Atom, Atom) {
    (atoms::error(), atoms::not_implemented())
}

#[rustler::nif]
fn store_delete_document(_store: Term, _id: Binary) -> (Atom, Atom) {
    (atoms::error(), atoms::not_implemented())
}

// ── QUIC stubs ──

#[rustler::nif]
fn quic_connect(_host: String, _port: u16) -> (Atom, Atom) {
    (atoms::error(), atoms::not_implemented())
}

#[rustler::nif]
fn quic_send(_conn: Term, _data: Binary) -> (Atom, Atom) {
    (atoms::error(), atoms::not_implemented())
}

#[rustler::nif]
fn quic_recv(_conn: Term, _timeout_ms: u64) -> (Atom, Atom) {
    (atoms::error(), atoms::not_implemented())
}

#[rustler::nif]
fn quic_close(_conn: Term) -> Atom {
    atoms::ok()
}

#[rustler::nif]
fn quic_listen(_port: u16, _opts: Term) -> (Atom, Atom) {
    (atoms::error(), atoms::not_implemented())
}

#[rustler::nif]
fn quic_accept(_listener: Term) -> (Atom, Atom) {
    (atoms::error(), atoms::not_implemented())
}

rustler::init!("Elixir.Keyring.Native");
