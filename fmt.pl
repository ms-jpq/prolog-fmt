#!/usr/bin/env -S -- swipl

:- use_module(/(/(modules, internal), util)).

:- use_module(/(/(modules, internal), syntax)).

:- use_module(/(/(modules, internal), xform)).

:- initialization(main, main).


p_comment_line_inner(Prefix) -->
    [ 0'/,
      0'*,
      X
    ],
    { maplist(dif(X), `/ `),
      =(Prefix, [0'/, 0'*, 0' , X])
    }.

p_comment_line_inner(Prefix) -->
    [0'*, X],
    { maplist(dif(X), `/ `),
      =(Prefix, [0' , 0'*, 0' , X])
    }.

p_comment_line_inner(Prefix) -->
    [0'%, X],
    { dif(X, 0' ),
      =(Prefix, [0'%, 0' , X])
    }.

p_comment_line_inner(Prefix) -->
    `/*`,
    { =(Prefix, `/*`)
    }.

p_comment_line_inner(Prefix) -->
    `*`,
    { =(Prefix, ` *`)
    }.

p_comment_line_inner(Prefix) -->
    `*/`,
    { =(Prefix, ` */`)
    }.

p_comment_line_inner(Prefix) -->
    [X],
    { maplist(dif(X), `%*`),
      =(Prefix, [0' , 0'*, 0' , X])
    }.

p_comment_line_inner([]) -->
    [].

p_comment_line(Line, Parsed) :-
    normalize_space(string(NoSpaces), Line),
    string_codes(NoSpaces, Codes),
    phrase(p_comment_line_inner(Head),
           Codes,
           Tail),
    append(Head, Tail, ParsedCodes),
    string_codes(Parsed, ParsedCodes).

p_comment_pos(-1, -1, _Lo, 0).

p_comment_pos(L1, H1, _Lo, Delta) :-
    is(Delta, +(-(H1, L1), 1)).

p_comments(_, _, [], []).

p_comments(&(Stripped, Floor), #(Seen1, L1, H1), [-(Position, Comment)|Comments], [-([Row, 0, Hi], Lines, comment(_))|LS]) :-
    string_lines(Comment, CommentLines),
    maplist(p_comment_line, CommentLines, Lines),
    stream_position_data(line_count, Position, L),
    length(Lines, Len),
    is(Lo, -(L, Floor)),
    is(Hi, -(+(Lo, Len), 1)),
    p_comment_pos(L1, H1, Lo, Delta),
    is(Seen2, -(Seen1, Delta)),
    is(Row, +(Seen2, Lo)),
    p_comments(&(Stripped, Floor),
               #(Seen2, Lo, Hi),
               Comments,
               LS).

p_terms_inner(Row, [Line|Lines], [-([Row, 1, 0], Line, term(Indent))|LS]) :-
    normalize_space(string(NoSpaces), Line),
    string_length(NoSpaces, L1),
    string_length(Line, L2),
    is(L3, -(L2, L1)),
    length(Indents, L3),
    maplist(=(0' ), Indents),
    string_codes(Indent, Indents),
    is(R, +(Row, 1)),
    p_terms_inner(R, Lines, LS).

p_terms_inner(_, [], []).

p_term(Term, Names, Parsed) :-
    with_output_to(string(String),
                   ( current_output(Stream),
                     portray_clause(Stream,
                                    Term,
                                    [ variable_names(Names),
                                      ignore_ops(true),
                                      quoted(true)
                                    ])
                   )),
    string_lines(String, Lines),
    p_terms_inner(0, Lines, Parsed).

pprint_rows(Indent, [-(_, Lines, comment(_))|LS], Adjusted) :-
    reverse(Lines, RL),
    maplist(string_concat(Indent), RL, IR),
    append(IR, AS, Adjusted),
    pprint_rows(Indent, LS, AS).

pprint_rows(_, [-(_, Line, term(Indent))|LS], [Line|AS]) :-
    pprint_rows(Indent, LS, AS).

pprint_rows(_, [], []).

pprint(StreamIn, _, _) :-
    at_end_of_stream(StreamIn).

pprint(StreamIn, StreamOut, Stripped) :-
    read_term(StreamIn,
              Term,
              [ variable_names(Names),
                term_position(Position),
                comments(Comments)
              ]),
    stream_position_data(line_count, Position, Row),
    p_term(Term, Names, ParsedTerm),
    p_comments(&(Stripped, Row),
               #(0, -1, -1),
               Comments,
               ParsedComments),
    append(ParsedTerm, ParsedComments, Rows),
    sort(1, @>=, Rows, Sorted),
    nl(StreamOut),
    pprint_rows("", Sorted, Adjusted),
    reverse(Adjusted, Lines),
    maplist(writeln(StreamOut), Lines),
    pprint(StreamIn, StreamOut, Stripped).

main(_Argv) :-
    with_output_to(string(NL),
                   ( current_output(Stream),
                     nl(Stream)
                   )),
    parse_text(user_input, Mapping, Preprocessed),
    string_lines(Preprocessed, Lines),
    non_empty(Lines, NonEmpty, Stripped),
    atomic_list_concat(NonEmpty, NL, Joined),
    open_string(Joined, StreamIn),
    syn_shebang(StreamIn, Line),
    with_output_to(string(Prettied),
                   ( current_output(StreamOut),
                     maplist(writeln(StreamOut), Line),
                     pprint(StreamIn,
                            StreamOut,
                            Stripped)
                   )),
    unparse_text(Prettied, Mapping, Output),
    write(user_output, Output).
