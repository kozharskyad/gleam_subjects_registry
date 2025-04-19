import gleam/dict
import gleam/erlang/atom
import gleam/erlang/process

pub const server_id = "subjects_registry"

pub type RegistryError {
  UnrecognizedMessage
  SubjectNotFound
  SubjectAlreadyRegistered
}

type DoNotLeak

type RegistryMessage(message) {
  Ready
  ParentPid(pid: process.Pid)
  Get(client_pid: process.Pid, id: String)
  Put(client_pid: process.Pid, id: String, subject: process.Subject(message))
}

@external(erlang, "subjects_registry_erlang_ffi", "receive")
fn receive() -> RegistryMessage(message)

@external(erlang, "subjects_registry_erlang_ffi", "receive")
fn receive_resolve() -> Result(process.Subject(message), RegistryError)

@external(erlang, "subjects_registry_erlang_ffi", "receive")
fn receive_register() -> Result(Nil, RegistryError)

@external(erlang, "erlang", "send")
fn raw_send(a: process.Pid, b: message) -> DoNotLeak

fn registry_atom() {
  atom.create_from_string(server_id)
}

fn registry_pid() {
  let assert Ok(pid) = process.named(registry_atom())
  pid
}

/// Start registry, returning new process's PID
pub fn start() {
  let registry_pid = process.start(registry_init, True)
  // 1->
  raw_send(registry_pid, ParentPid(process.self()))
  // 2<-
  let assert Ready = receive()
  Ok(registry_pid)
}

fn registry_init() {
  // 1<-
  let assert ParentPid(parent_pid) = receive()
  let assert Ok(_) = process.register(process.self(), registry_atom())
  // 2->
  raw_send(parent_pid, Ready)
  registry_loop(dict.new())
}

fn registry_loop(state: dict.Dict(String, process.Subject(message))) {
  // 3<-
  let state = case receive() {
    Get(client_pid, id) -> {
      case dict.get(state, id) {
        // 4->
        Ok(subject) -> raw_send(client_pid, Ok(subject))
        Error(_) -> raw_send(client_pid, Error(SubjectNotFound))
      }
      state
    }
    Put(client_pid, id, subject) -> {
      case dict.has_key(state, id) {
        False -> {
          let new_state = dict.insert(state, id, subject)
          // 5->
          raw_send(client_pid, Ok(Nil))
          new_state
        }
        True -> {
          // 5->
          raw_send(client_pid, Error(SubjectAlreadyRegistered))
          state
        }
      }
    }
    _ -> state
  }
  registry_loop(state)
}

/// Get subject from registry by string ID
pub fn resolve(id: String) {
  // 3->
  raw_send(registry_pid(), Get(process.self(), id))
  // 4<-
  receive_resolve()
}

/// Put subject to registry with string ID
pub fn register(id: String, subject: process.Subject(message)) {
  // 3->
  raw_send(registry_pid(), Put(process.self(), id, subject))
  // 5<-
  receive_register()
}

/// Reply to subject's message.
/// This is plain re-export `process.send` function for convenient
pub fn reply(subject: process.Subject(message), message: message) {
  process.send(subject, message)
}

/// Resolve and asynchronously call a named subject,
/// rejects any response
pub fn send(id: String, message: message) {
  case resolve(id) {
    Ok(subject) -> Ok(reply(subject, message))
    Error(error) -> Error(error)
  }
}

/// Resolve and synchronously call a named subject,
/// returning response message
pub fn call(
  id: String,
  make_request: fn(process.Subject(response)) -> request,
  within timeout: Int,
) {
  case resolve(id) {
    Ok(subject) -> Ok(process.call(subject, make_request, timeout))
    Error(error) -> Error(error)
  }
}
