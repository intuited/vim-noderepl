" TODO: generate these commands with a repl#Repl method

" `call call(...)` is used here because `call a#b.c(...)` won't trigger autoload.
command -nargs=* NodeRepl call call(noderepl#Repl.StartRepl, [<f-args>], noderepl#Repl)
command -nargs=* NodeReplContext call call(noderepl#Repl.StartReplContext, [<f-args>], {})
