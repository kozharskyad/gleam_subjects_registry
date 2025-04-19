# Gleam Subjects Registry

## Description

Singleton registry for OTP Actor subjects.

## Example usage

```toml
# gleam.toml
...
[dependencies]
subjects_registry = { git = "https://github.com/kozharskyad/gleam_subjects_registry.git", ref = "main" }
...
```

```gleam
// main.gleam

import gleam/otp/static_supervisor as sup
import subjects_registry
import test_actor

pub fn main() {
  sup.new(sup.OneForOne)
  |> sup.add(sup.worker_child(
    id: subjects_registry.server_id,
    run: subjects_registry.start,
  ))
  |> sup.add(sup.worker_child(
    id: test_actor.subject_name,
    run: test_actor.start,
  ))
  |> sup.start_link
}
```

```gleam
// test_actor.gleam

import gleam/erlang/process
import gleam/otp/actor
import subjects_registry

pub const subject_name = "test_actor"

pub type Message {
  Inc(caller: process.Subject(Int))
  Dec(callse: process.Subject(Int))
}

pub fn start() {
  let assert Ok(subject) = actor.start(0, handle_messages)
  subjects_registry.register(subject_name, subject)
  Ok(process.subject_owner(subject))
}

fn handle_messages(message: Message, state: Int) {
  case message {
    Inc(caller) -> {
      let new_state = state + 1
      subjects_registry.reply(caller, new_state)
      actor.continue(new_state)
    }
    Dec(caller) -> {
      let new_state = state - 1
      subjects_registry.reply(caller, new_state)
      actor.continue(new_state)
    }
  }
}

pub fn inc() {
  subjects_registry.call(subject_name, Inc, within: 1000)
}

pub fn dec() {
  subjects_registry.call(subject_name, Dec, within: 1000)
}
```
