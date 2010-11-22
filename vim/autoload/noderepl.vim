" Creates a repl in a new buffer.
funct! noderepl#StartRepl()
    call g:noderepl#Repl.New()
endfunct

python import vim, sys, os
python sys.path.insert(0, os.path.join(vim.eval("expand('<sfile>:p:h')"),
                                     \ "noderepl"))
python import poste

" Holds connection details like port and server
" which can be overridden by setting repl dictionary elements.
" The elements should correspond to
" keyword arguments to the Python function `poste.post`.
let g:noderepl_connect = {}


let noderepl#Repl = copy(vimclojure#Repl)

" Creates a repl in a new buffer.
" The new dictionary instance is stored in `b:noderepl`.
" This function is called by the StartRepl plugin that's mapped to \sr.
funct! noderepl#Repl.New() dict
    let instance = copy(self)

    new
    setlocal buftype=nofile
    setlocal noswapfile

    call instance._InitConnectInfo()

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

    " Set up the connect info dictionary.
    " See the declaration of `g:noderepl_connect` for more info.
    funct! noderepl#Repl._InitConnectInfo() dict
        let self.connect_info = {}
    endfunct

    " Set up the history-related key mappings.
    funct! noderepl#Repl._SetupHistory() dict
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
    funct! noderepl#Repl._WriteReplHeader() dict
        call append(line("$"), ["Node", self._prompt . " "])
    endfunct

    " Communicates with the running node instance
    " and returns the name of a new repl context.
    funct! noderepl#Repl._NewReplContext() dict
        " TODO: implement this stub
        "       after writing node code to create uniquely named contexts.
        return "vim-noderepl"
    endfunct

    " Perform any node-side initialization like requiring modules.
    " VimClojure requires its stacktrace module.
    funct! noderepl#Repl._InitializeRepl() dict
        " TODO: See if anything needs to go here.
    endfunct


" Callback functions to interface with the interpreter

    function! noderepl#Repl.enterHook() dict
        let cmd = self.getCommand()

        " Special Case: Showed prompt (or user just hit enter).
        if cmd == ""
            return
        endif

        " Not supporting this vimclojure#Repl functionality (yet?)
        ""++  if self.isReplCommand(cmd)
        ""++      call self.doReplCommand(cmd)
        ""++      return
        ""++  endif

        let [syntax_okay, result] = self.RunReplCommand(cmd)

        if syntax_okay
            call self.showText(result)

            let self._historyDepth = 0
            let self._history = [cmd] + self._history
            call self.showPrompt()
        else
            execute "normal! GA\<CR>x"
            normal! ==x
            startinsert!
        endif
    endfunction

""__  dragons

    " Runs the repl command in self's context (held in `self._id`).
    " Return:
    "   [syntax_okay, result] where
    "       syntax_okay is non-zero if `cmd` was parsed correctly
    "       result is the result.
    funct! noderepl#Repl.RunReplCommand(cmd)
        " TODO write this!
        let connect_info = extend(copy(self.connect_info), g:noderepl_connect)

        python NodeRepl.run_repl_command(vim.eval("a:cmd"),
                                       \ vim.eval("l:connect_info"),
                                       \ context=vim.eval("self._id"))
    endfunct

""^^ dragons

    function! vimclojure#Repl.upHistory() dict
        let histLen = len(self._history)
        let histDepth = self._historyDepth

        if histLen > 0 && histLen > histDepth
            let cmd = self._history[histDepth]
            let self._historyDepth = histDepth + 1

            call self.deleteLast()

            call self.showText(self._prompt . " " . cmd)
        endif

        normal! G$
    endfunction

    function! vimclojure#Repl.downHistory() dict
        let histLen = len(self._history)
        let histDepth = self._historyDepth

        if histDepth > 0 && histLen > 0
            let self._historyDepth = histDepth - 1
            let cmd = self._history[self._historyDepth]

            call self.deleteLast()

            call self.showText(self._prompt . " " . cmd)
        elseif histDepth == 0
            call self.deleteLast()
            call self.showText(self._prompt . " ")
        endif

        normal! G$
    endfunction

python <<EOF
class NodeRepl(object):
    @staticmethod
    def escape_string(string):
        """Escape a string for vim evaluation."""
        return "'{0}'".format(string.replace("'", "''"))

    @staticmethod
    def run_repl_command(cmd, post_args, context=None):
        """Pass the REPL command `cmd` to node for evaluation.
        
        The dictionary `post_args` is used as keyword arguments to `poste.post`.
        """
        result = poste.post(poste.Evaluate(cmd, context=context), **post_args)
        success = 0 if isinstance(result, poste.SynError) else 1
        result = NodeRepl.escape_string(str(result))
        vim.command("return [{0}, {1}]".format(success, result))
EOF
