
:- module(xform,
          [ /(parse_text, 3),
            /(unparse_text, 3)
          ]).

p_token([str(String, Placeholder)|XS]) -->
    [ 0'0,
      0'',
      0'\\,
      X
    ],
    { string_codes(String,
                   [ 0'0,
                     0'',
                     0'\\,
                     X
                   ]),
      uuid_padded(String, Placeholder)
    },
    p_token(XS).

p_token([str(String, Placeholder)|XS]) -->
    [ 0'0,
      0'',
      X
    ],
    { string_codes(String,
                   [ 0'0,
                     0'',
                     X
                   ]),
      uuid_padded(String, Placeholder)
    },
    p_token(XS).

p_token([norm(X)|XS]) -->
    [X],
    { maplist(dif(X), `\`'"`)
    },
    p_token(XS).

p_token([]) -->
    [].

p_others_inner([norm(C)|Tokens], CS, Syntax) :-
    append(CS, [C], Codes),
    p_others_inner(Tokens, Codes, Syntax).

p_others_inner([str(String, Placeholder)|Tokens], Codes, [no(Str), str(String, Placeholder)|Syntax]) :-
    string_codes(Str, Codes),
    p_others_inner(Tokens, [], Syntax).

p_others_inner([], Codes, [no(String)]) :-
    string_codes(String, Codes).

p_others(Syntax) -->
    p_token(Tokens),
    { p_others_inner(Tokens, [], Syntax)
    }.

p_string_inner(Mark, [0'\\, X|XS]) -->
    [0'\\, X],
    { memberchk(X,
                [0'\\, Mark])
    },
    p_string_inner(Mark, XS).

p_string_inner(Mark, [X|XS]) -->
    [X],
    { dif(X, Mark)
    },
    p_string_inner(Mark, XS).

p_string_inner(_, []) -->
    [].

p_str(Mark, XS) -->
    [Mark],
    p_string_inner(Mark, XS),
    [Mark].

p_string(Mark, no(String)) -->
    p_str(Mark, XS),
    { append([Mark|XS], [Mark], Codes),
      string_codes(String, Codes)
    }.

p_codes(Mark, str(String, Placeholder)) -->
    p_str(Mark, XS),
    { append([Mark|XS], [Mark], Codes),
      string_codes(String, Codes),
      uuid_padded(String, Placeholder)
    }.

p_strings([String]) -->
    (   p_string(0'', String)
    ;   p_string(0'", String)
    ;   p_codes(0'`, String)
    ).

p_strings([]) -->
    [].

p_grammar([]) -->
    [].

p_grammar(Syntax) -->
    p_others(S1),
    p_strings(S2),
    p_grammar(S3),
    { append(S1, S2, S),
      append(S, S3, Syntax)
    }.

build_mapping([no(String)|StrIn], [String|StrOut], Mapping) :-
    build_mapping(StrIn, StrOut, Mapping).

build_mapping([str(String, Placeholder)|StrIn], [Slot|StrOut], [=(Placeholder, String)|Mapping]) :-
    atomics_to_string(['"{', Placeholder, '}"'], "", Slot),
    build_mapping(StrIn, StrOut, Mapping).

build_mapping([], [], []).

parse_text(StreamIn, Mapping, TextOut) :-
    phrase_from_stream(p_grammar(Parsed), StreamIn),
    build_mapping(Parsed, IR, Mapping),
    atomics_to_string(IR, "", TextOut).

unparse_text(TextIn, Mapping, TextOut) :-
    re_replace(/('"(\\{X[0-9a-f]{32}_*\\})"', g),
               "$1",
               TextIn,
               IR),
    interpolate_string(IR, TextOut, Mapping, []).
