" Creates a repl in a new buffer.
funct! noderepl#StartRepl()
    call noderepl#Repl.New()
endfunct

let noderepl#Repl = copy(vimclojure#Repl)

" Creates a repl in a new buffer.
" The new dictionary instance is stored in `b:noderepl`.
" This function is called by the StartRepl plugin that's mapped to \sr.
funct! noderepl#Repl.New() dict
    let instance = copy(self)

    new
    setlocal buftype=nofile
    setlocal noswapfile

    call instance._SetupHistory()

    call instance._WriteReplHeader()

    let instance._id = instance._NewReplContext()
    call instance._InitializeRepl()
    let instance._buffer = bufnr("%")

    let b:noderepl = instance

    setfiletype clojure

    normal! G
    startinsert!
endfunct

" Various functions called by the New method:

    " Set up the history-related key mappings.
    funct! noderepl#Repl._SetupHistory()
        " TODO: rename these plug commands.
        if !hasmapto("<Plug>NodereplEnterHook")
            imap <buffer> <silent> <CR> <Plug>NodereplEnterHook
        endif
        if !hasmapto("<Plug>NodereplUpHistory")
            imap <buffer> <silent> <C-Up> <Plug>NodereplUpHistory
        endif
        if !hasmapto("<Plug>NodereplDownHistory")
            imap <buffer> <silent> <C-Down> <Plug>NodereplDownHistory
        endif
    endfunct

    " Write the REPL intro line, including the first prompt.
    " This function should write to the current buffer
    " and not change which buffer is current.
    funct! noderepl#Repl._WriteReplHeader()
        call append(line("$"), ["Node", self._prompt . " "])
    endfunct

    " Communicates with the running node instance
    " and returns the name of a new repl context.
    funct! noderepl#Repl._NewReplContext()
        " TODO: implement this stub
        return "vim-noderepl"
    endfunct

    " Perform any node-side initialization like requiring modules.
    " VimClojure requires its stacktrace module.
    funct! noderepl#Repl._InitializeRepl()
        " TODO: See if anything needs to go here.
    endfunct
