import gleam/dict
import gleam/erlang/atom
import gleam/erlang/process

pub const server_id = "subjects_registry"

type DoNotLeak

type RegistryMessage(message) {
  Ready
  ParentPid(pid: process.Pid)
  Get(client_pid: process.Pid, id: String)
  Put(client_pid: process.Pid, id: String, subject: process.Subject(message))
}

@external(erlang, "subjects_registry_erlang_ffi", "receive")
fn receive() -> Result(RegistryMessage(message), Nil)

@external(erlang, "subjects_registry_erlang_ffi", "receive")
fn receive_resolve() -> Result(process.Subject(message), Nil)

@external(erlang, "subjects_registry_erlang_ffi", "receive")
fn receive_register() -> Result(Nil, Nil)

@external(erlang, "erlang", "send")
fn raw_send(a: process.Pid, b: message) -> DoNotLeak

fn registry_atom() {
  atom.create_from_string(server_id)
}

/// Start registry, returning new process's PID
pub fn start() {
  let registry_pid = process.start(registry_init, True)
  raw_send(registry_pid, ParentPid(process.self()))
  let assert Ok(Ready) = receive()
  Ok(registry_pid)
}

fn registry_init() {
  let assert Ok(ParentPid(parent_pid)) = receive()
  let registry_pid = process.self()
  let assert Ok(_) = process.register(registry_pid, registry_atom())
  raw_send(parent_pid, Ready)
  registry_loop(dict.new())
}

fn registry_loop(state: dict.Dict(String, process.Subject(message))) {
  let state = case receive() {
    Ok(Get(client_pid, atom)) -> {
      let assert Ok(subject) = state |> dict.get(atom)
      raw_send(client_pid, subject)
      state
    }
    Ok(Put(client_pid, atom, subject)) -> {
      let new_state = state |> dict.insert(atom, subject)
      raw_send(client_pid, Ok(Nil))
      new_state
    }
    _ -> state
  }
  registry_loop(state)
}

/// Get subject from registry by string ID
pub fn resolve(id: String) {
  let assert Ok(registry_pid) = process.named(registry_atom())
  raw_send(registry_pid, Get(process.self(), id))
  let assert Ok(subject) = receive_resolve()
  subject
}

/// Put subject to registry with string ID
pub fn register(id: String, subject: process.Subject(message)) {
  let assert Ok(registry_pid) = process.named(registry_atom())
  raw_send(registry_pid, Put(process.self(), id, subject))
  let assert Ok(_) = receive_register()
  Nil
}

/// Reply to subject's message.
/// This is plain re-export `process.send` function for convenient
pub fn reply(subject: process.Subject(message), message: message) -> Nil {
  process.send(subject, message)
}

/// Resolve and asynchronously call a named subject,
/// rejects any response
pub fn send(id: String, message: message) -> Nil {
  reply(resolve(id), message)
}

/// Resolve and synchronously call a named subject,
/// returning response message
pub fn call(
  id: String,
  make_request: fn(process.Subject(response)) -> request,
  within timeout: Int,
) -> response {
  process.call(resolve(id), make_request, timeout)
}
