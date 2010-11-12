" Creates a repl in a new buffer.
funct! noderepl#StartRepl()
    call noderepl#Repl.New()
endfunct

let noderepl#Repl = copy(vimclojure#Repl)

" Creates a repl in a new buffer.
" The new dictionary instance is stored in `b:vimclojure_repl`.
" This function is called by the StartRepl plugin that's mapped to \sr.
function! vimclojure#Repl.New() dict
    let instance = copy(self)

    new
    setlocal buftype=nofile
    setlocal noswapfile

    if !hasmapto("<Plug>ClojureReplEnterHook")
        imap <buffer> <silent> <CR> <Plug>ClojureReplEnterHook
    endif
    if !hasmapto("<Plug>ClojureReplUpHistory")
        imap <buffer> <silent> <C-Up> <Plug>ClojureReplUpHistory
    endif
    if !hasmapto("<Plug>ClojureReplDownHistory")
        imap <buffer> <silent> <C-Down> <Plug>ClojureReplDownHistory
    endif

    call append(line("$"), ["Clojure", self._prompt . " "])

    let instance._id = vimclojure#ExecuteNail("Repl", "-s")
    call vimclojure#ExecuteNailWithInput("Repl",
                \ "(require 'clojure.contrib.stacktrace)", "-r",
                \ "-i", instance._id)
    let instance._buffer = bufnr("%")

    let b:vimclojure_repl = instance

    setfiletype clojure

    normal! G
    startinsert!
endfunction
