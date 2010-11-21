command NodeRepl call noderepl#StartRepl()

inoremap <Plug>NodereplEnterHook <Esc>:call b:noderepl.enterHook()<CR>
inoremap <Plug>NodereplUpHistory <C-O>:call b:noderepl.upHistory()<CR>
inoremap <Plug>NodereplDownHistory <C-O>:call b:noderepl.downHistory()<CR>
