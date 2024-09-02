
:- module(syntax,
          [ /(syn_shebang, 2)
          ]).

% (+Stream, -Lines)
syn_shebang(Stream, [Line]) :-
    =(Bang, "#!"),
    string_length(Bang, Len),
    peek_string(Stream, Len, Bang),
    read_line_to_string(Stream, Line).

syn_shebang(_, []).
