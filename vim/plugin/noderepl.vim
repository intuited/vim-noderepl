command -nargs=* NodeRepl call noderepl#StartRepl(<f-args>)
command -nargs=* NodeReplContext call noderepl#StartReplContext(<f-args>)

inoremap <Plug>NodereplEnterHook <Esc>:call b:noderepl.enterHook()<CR>
inoremap <Plug>NodereplUpHistory <C-O>:call b:noderepl.upHistory()<CR>
inoremap <Plug>NodereplDownHistory <C-O>:call b:noderepl.downHistory()<CR>
