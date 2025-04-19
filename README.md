# Gleam Subjects Registry

## Description

Singleton registry for OTP Actor subjects.

## Example usage

### Sources

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

### Run example

```bash
$ gleam shell
  Compiling testproj3
   Compiled in 0.17s
    Running Erlang shell
Erlang/OTP 27 [erts-15.2.5] [source] [64-bit] [smp:14:14] [ds:14:14:10] [async-threads:1] [jit] [dtrace]

Eshell V15.2.5 (press Ctrl+G to abort, type help(). for help)
1> main:main().
{ok,<0.86.0>}
2> test_actor:inc().
1
3> test_actor:inc().
2
4> test_actor:inc().
3
5> test_actor:dec().
2
6> test_actor:dec().
1
7> test_actor:dec().
0
8> test_actor:dec().
-1
9> test_actor:dec().
-2
10> test_actor:dec().
-3
11> q().
ok
```
