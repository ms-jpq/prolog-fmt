
:- module(util,
          [ /(uuid_padded, 2)
          ]).

x_uuid(X_UUID) :-
    uuid(UUID),
    split_string(UUID, "-", "", Parts),
    atomics_to_string(["X"|Parts], "", X_UUID).

uuid_padded(String, Padded) :-
    x_uuid(Prefix),
    string_length(Prefix, PLen),
    string_length(String, SLen),
    is(Padding, max(0, -(-(SLen, PLen), 2))),
    length(PS, Padding),
    maplist(=("_"), PS),
    atomics_to_string([Prefix|PS], "", Holder),
    atom_string(Padded, Holder).
