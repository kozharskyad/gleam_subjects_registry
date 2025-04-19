-module(subjects_registry_erlang_ffi).
-export(['receive'/0]).

'receive'() ->
  receive
    Value -> {ok, Value}
  end.
