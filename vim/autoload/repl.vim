" TODO:
"   -   Make function naming/capitalization/initial-underscoring consistent
"   -   Have NodeReplContext echo the context if no argument is provided
"   -   Maybe rework command structure 
"       so that `:Repl` can handle things like changing/displaying context
"   -   Make it possible to show the context in the prompt
"   -   Retain history across sessions
"   -   Refactory history into an object

" General-purpose support functions.
    " These were acquired directly from VimClojure
    " and have not really been processed.

    function! repl#WithSaved(closure)
        let v = a:closure.get(a:closure.tosafe)
        let r = a:closure.f()
        call a:closure.set(a:closure.tosafe, v)
        return r
    endfunction

    function! repl#WithSavedPosition(closure)
        let a:closure['tosafe'] = "."
        let a:closure['get'] = function("getpos")
        let a:closure['set'] = function("setpos")
        return repl#WithSaved(a:closure)
    endfunction

    function! repl#WithSavedRegister(closure)
        let a:closure['get'] = function("getreg")
        let a:closure['set'] = function("setreg")
        return repl#WithSaved(a:closure)
    endfunction

    function! repl#Yank(r, how)
        let closure = {'tosafe': a:r, 'yank': a:how}

        function closure.f() dict
            silent execute self.yank
            return getreg(self.tosafe)
        endfunction

        return repl#WithSavedRegister(closure)
    endfunction


" Buffer type that the repl type is based on.
    " Taken directly from VimClojure.

    let repl#Buffer = {}

    function! repl#Buffer.goHere() dict
        execute "buffer! " . self._buffer
    endfunction

    function! repl#Buffer.resize() dict
        call self.goHere()
        let size = line("$")
        if size < 3
            let size = 3
        endif
        execute "resize " . size
    endfunction

    function! repl#Buffer.showText(text) dict
        call self.goHere()
        if type(a:text) == type("")
            let text = split(a:text, '\n')
        else
            let text = a:text
        endif
        call append(line("$"), text)
    endfunction

    function! repl#Buffer.close() dict
        execute "bdelete! " . self._buffer
    endfunction


" The main repl type.
    let repl#Repl = copy(repl#Buffer)

    " TODO: lose the initial underscores on these properties.
    let repl#Repl._header = 'REPL'
    let repl#Repl._prompt = 'REPL=>'
    let repl#Repl._default_context = 'default'


    " Repl creation functions

        " Creates a repl in a new buffer.
        funct! repl#Repl.StartRepl(...)
            let name = a:0 ? a:1 : self._default_context
            let unique = a:0 > 1 ? a:2 : 0

            let instance = copy(self)

            new

            call instance.Init(name, unique)
        endfunct

        " StartReplContext(name=self._default_context, unique=0)
            " If already in a repl, start using a context with the given `name`.
            " If not in a repl, start a new one in a new buffer
            " using the named context.
            " If the named context does not already exist, it is created.
            " 
            " If `unique` is nonzero, a new, unique context is created,
            " using `name` as a prefix.
        funct! repl#Repl.StartReplContext(...)
            let name = a:0 ? a:1 : self._default_context
            let unique = a:0 > 1 ? a:2 : 0
            if exists('b:repl')
                let b:repl._context = b:repl._GetReplContext(name, unique)
            else
                call self.StartRepl(name, unique)
            endif
        endfunct


    " Initialize a new REPL and its buffer.
    " The buffer itself should already be created and focused.
    " The new dictionary instance is stored in `b:repl`.
    funct! repl#Repl.Init(name, unique) dict
        call self._SetupBuffer()

        call self._InitConnectInfo()

        call self._SetupHistory()

        call self._WriteReplHeader()

        let self._context = self._GetReplContext(a:name, a:unique)

        call self._InitializeRepl()

        let self._buffer = bufnr("%")

        let b:repl = self

        call self._SetFileType()

        call self._SetupCompletion()

        call self._Activate()
    endfunct

    " Implementation-independent initialization methods
    " It may make sense to override some of these;
    " however, it is not necessary.

        " Set up the buffer options.
        funct! repl#Repl._SetupBuffer()
            setlocal buftype=nofile
            setlocal noswapfile
        endfunct

        " Set up the connect info dictionary.
        " See the declaration of `g:repl_connect` for more info.
        funct! repl#Repl._InitConnectInfo() dict
            let self.connect_info = {}
        endfunct

        " Set up the history-related key mappings and properties
        funct! repl#Repl._SetupHistory() dict
            let self._history = ['']
            " Edited history is reset each time a command is entered.
            let self._editedHistory = ['']
            let self._historyDepth = 0
            if !hasmapto("<Plug>ReplEnterHook")
                imap <buffer> <silent> <CR> <Plug>ReplEnterHook
            endif
            if !hasmapto("<Plug>ReplUpHistory")
                imap <buffer> <silent> <C-Up> <Plug>ReplUpHistory
            endif
            if !hasmapto("<Plug>ReplDownHistory")
                imap <buffer> <silent> <C-Down> <Plug>ReplDownHistory
            endif
        endfunct

        " Write the REPL intro line, including the first prompt.
        " This function should write to the current buffer
        " and not change which buffer is current.
        funct! repl#Repl._WriteReplHeader() dict
            call append(line("$"), [self._header, self._prompt . " "])
        endfunct

        " See also repl#Repl._GetReplContext,
        " located among the interpreter communication methods.

        " Set up filetype-related items.
        " This hook is called after the buffer has been created and initialized.
        funct! repl#Repl._SetFileType() dict
        endfunct

        " Set up omni completion for the REPL buffer.
        funct! repl#Repl._SetupCompletion() dict
            setlocal omnifunc=repl#OmniCompletion
        endfunct

        " Perform any interpreter initialization, e.g. loading modules.
        " The VimClojure repl loads its stacktrace module here.
        funct! repl#Repl._InitializeRepl() dict
        endfunct

        " Get the buffer ready for user input.
        funct! repl#Repl._Activate()
            normal! G
            startinsert!
        endfunct


    " UI event handlers
        " These just handle the guts of the interface
        " and call out to other methods for any interaction with the interpreter.
        " They should not need to be overridden
        " unless it's desired to customize the behaviour of the interface.

        " Called in response to a press of the ENTER key in insert mode.
        function! repl#Repl.enterHook() dict
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

            let [syntax_okay, result] = self.runReplCommand(cmd)

            if syntax_okay
                call self.showText(result)

                let self._historyDepth = 0
                call insert(self._history, cmd, 1)
                " Reset the editable history to the actual history.
                let self._editedHistory = copy(self._history)
                call self.showPrompt()
            else
                execute "normal! GA\<CR>x"
                normal! ==x
                startinsert!
            endif
        endfunction

        " Change the last REPL command to the one a:delta lines away.
        function! repl#Repl._CycleHistory(delta)
            let depth = self._historyDepth + a:delta
            let depth = max([depth, 0])
            let depth = min([depth, len(self._editedHistory) - 1])

            if self._historyDepth != depth
                " Retain partially-edited commands.
                " These are reset to the actual history when a command is entered.
                let self._editedHistory[self._historyDepth] = self.getCommand()

                let cmd = self._editedHistory[depth]
                let self._historyDepth = depth

                call self.deleteLast()
                call self.showText(self._prompt . " " . cmd)
                normal G$
            endif
        endfunction

        " Handles cycling back in the history, normally via CTRL-UP.
        function! repl#Repl.upHistory() dict
            call self._CycleHistory(1)
        endfunction

        " Handles cycling forward in the history, normally via CTRL-DOWN.
        function! repl#Repl.downHistory() dict
            call self._CycleHistory(-1)
        endfunction


    " Generic omni-completion methods.
        " `self._completeList` is called to interact with the interpreter.

        function! repl#OmniCompletion(findstart, base)
            if exists('b:repl')
                return b:repl.complete(a:findstart, a:base)
            else
                " This shouldn't happen.
                throw "repl#OmniCompletion called on non-repl buffer."
            endif
        endfunct

        funct! repl#Repl.complete(findstart, base) dict
            if a:findstart == 1
                return self._completeFindStart(getline('.'), col('.') - 1)
            else
                return self._completeList(a:base)
            endif
        endfunction

        " TODO: There must be a better way to do this.  Can use 'iskeyword'?
        let repl#Repl._wordChars = '\w\|\.'

        " Finds the start of the text to complete without generating a list.
        " See |complete-functions| for more info.
        " Returns the column of the first character of the chunk of text
        " which should be completed at the cursor position.
        funct! repl#Repl._completeFindStart(line, startCol) dict
            let start = a:startCol
            while start > 0 && a:line[start - 1] =~ self._wordChars
                let start -= 1
            endwhile
            return start
        endfunct


    " Miscellaneous support methods
        " Write a new prompt into the buffer.
        function! repl#Repl.showPrompt() dict
            call self.showText(self._prompt . " ")
            normal! G
            startinsert!
        endfunction

        " Build a regular expression which will find the prompt
        " regardless of vim's case and magic settings
        " Terminating space is optional because the user may have deleted it.
        function! repl#Repl.BuildPromptRE(prompt)
            return '\V\C\^' . escape(self._prompt, '\') . '\s\*'
        endfunction

        " Parse the command out of the text at the cursor position
        function! repl#Repl.getCommand() dict
            let prompt_re = self.BuildPromptRE(self._prompt)

            let ln = search(prompt_re, 'bcnW')

            " Special Case: User deleted Prompt by accident. Insert a new one.
            if ln == 0
                call self.showPrompt()
                return ""
            endif

            let cmd = repl#Yank("l", ln . "," . line("$") . "yank l")

            let cmd = substitute(cmd, prompt_re, "", "")
            let cmd = substitute(cmd, "\n$", "", "")
            return cmd
        endfunction

        " Delete the last command in the buffer, including its prompt
        function! repl#Repl.deleteLast() dict
            normal! G
            let ln = search(self.BuildPromptRE(self._prompt), 'bcW')
            exec ln . ',$delete'
        endfunction


    " Interpreter communication methods
    " ---------------------------------

    " These methods interact with the interpreter
    " and will normally be overridden in extending dicts.

        " getReplContext(name, unique)
            " Communicates with the interpreter
            " and returns the name of a repl context.
            " This base implementation just returns "default",
            " which may be acceptable for implementations
            " which do not need to run code to create a context
            " or to support multiple contexts.
            " In this case, an exception is raised
            " if an attempt is made to select a unique context.
            " Parameters:
            "   name:   The name of the context to be returned.
            "           If the named context does not already exist, it is created.
            "   unique: If non-zero, `a:name` will be used as a prefix
            "           for a new, uniquely-named context.
            " Return:
            "   The name of the created context.
        funct! repl#Repl._GetReplContext(name, unique) dict
            if a:unique
                throw 'Base implementation of _GetReplContext() '
                    \ . 'cannot provide unique contexts.'
            return self._default_context
        endfunct


        " runReplCommand(cmd)
            " Runs the repl command in self's context (held in `self._context`).
            " This method should never be called;
            " it is effectively a virtual method which should be overridden
            " to provide functionality specific to the implementation.
            " Return: `[syntax_okay, result]` where
            "     -   `syntax_okay` is non-zero if `cmd` was parsed correctly.
            "         This should be used to indicate that a command is incomplete.
            "     -   `result` is the result.
        funct! repl#Repl.runReplCommand(cmd)
            throw "repl#Repl.runReplCommand must be overridden in extension dicts."
        endfunct


        " _completeList(base)
            " Generate the list of possible completions.
            " `base` is the text to be completed.
            " This method must be overridden
            " iff the implementation is to provide completion facilities.
        funct! repl#Repl._completeList(base) dict
            return []
        endfunct
