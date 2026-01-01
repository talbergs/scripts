; Tree-sitter query for PHP translation function calls
; Extracts msgid strings based on function signature:
;   _(msgid)            -> arg 1
;   _s(msgid)           -> arg 1
;   _n(singular,plural) -> args 1,2
;   _x(msgid,ctx)       -> arg 1
;   _xs(msgid,ctx)      -> arg 1
;   _xn(sing,plur,n,ctx)-> args 1,2

; Match _(string) - extract first argument
(function_call_expression
  function: (name) @_fn
  (#eq? @_fn "_")
  arguments: (arguments
    .
    (argument) @arg1))

; Match _s(string) - extract first argument
(function_call_expression
  function: (name) @_fn
  (#eq? @_fn "_s")
  arguments: (arguments
    .
    (argument) @arg1))

; Match _n(singular, plural) - extract first two arguments
(function_call_expression
  function: (name) @_fn
  (#eq? @_fn "_n")
  arguments: (arguments
    .
    (argument) @arg1
    .
    (argument) @arg2))

; Match _x(msgid, context) - extract first argument only
(function_call_expression
  function: (name) @_fn
  (#eq? @_fn "_x")
  arguments: (arguments
    .
    (argument) @arg1))

; Match _xs(msgid, context) - extract first argument only
(function_call_expression
  function: (name) @_fn
  (#eq? @_fn "_xs")
  arguments: (arguments
    .
    (argument) @arg1))

; Match _xn(singular, plural, n, context) - extract first two arguments
(function_call_expression
  function: (name) @_fn
  (#eq? @_fn "_xn")
  arguments: (arguments
    .
    (argument) @arg1
    .
    (argument) @arg2))
