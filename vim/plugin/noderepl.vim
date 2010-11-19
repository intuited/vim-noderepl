command NodeRepl call noderepl#StartRepl()

inoremap <Plug>NodeReplEnterHook <Esc>:call b:noderepl.enterHook()<CR>
inoremap <Plug>NodeReplUpHistory <C-O>:call b:noderepl.upHistory()<CR>
inoremap <Plug>NodeReplDownHistory <C-O>:call b:noderepl.downHistory()<CR>
