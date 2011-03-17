" TODO:
"   -   Make function naming/capitalization/initial-underscoring consistent
"   -   Repl._id should be called Repl._context


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
    let repl#Repl._history = []
    let repl#Repl._historyDepth = 0

    " Creates a repl in a new buffer.
    " The new dictionary instance is stored in `b:repl`.
    funct! repl#Repl.New(name, unique) dict
        let instance = copy(self)

        new
        setlocal buftype=nofile
        setlocal noswapfile

        call instance._InitConnectInfo()

        call instance._SetupHistory()

        call instance._WriteReplHeader()

        let instance._id = instance._getReplContext(a:name, a:unique)

        call instance._InitializeRepl()

        let instance._buffer = bufnr("%")

        let b:repl = instance

        call instance._SetFileType()

        call instance._SetupCompletion()

        normal! G
        startinsert!
    endfunct

    " Implementation-independent initialization methods
    " It may make sense to override some of these;
    " however, it is not necessary.

        " Set up the connect info dictionary.
        " See the declaration of `g:repl_connect` for more info.
        funct! repl#Repl._InitConnectInfo() dict
            let self.connect_info = {}
        endfunct

        " Set up the history-related key mappings.
        funct! repl#Repl._SetupHistory() dict
            " TODO: rename these plug commands.
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
                let self._history = [cmd] + self._history
                call self.showPrompt()
            else
                execute "normal! GA\<CR>x"
                normal! ==x
                startinsert!
            endif
        endfunction

        " Handles cycling back in the history, normally via CTRL-UP.
        function! repl#Repl.upHistory() dict
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

        " Handles cycling forward in the history, normally via CTRL-DOWN.
        function! repl#Repl.downHistory() dict
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

        " Parse the command out of the text at the cursor position
        function! repl#Repl.getCommand() dict
            let ln = line("$")

            " XXX: The prompt needs to be escaped.
            while getline(ln) !~ "^" . self._prompt && ln > 0
                let ln = ln - 1
            endwhile

            " Special Case: User deleted Prompt by accident. Insert a new one.
            if ln == 0
                call self.showPrompt()
                return ""
            endif

            let cmd = repl#Yank("l", ln . "," . line("$") . "yank l")

            " XXX: The prompt needs to be escaped.
            let cmd = substitute(cmd, "^" . self._prompt . "\\s*", "", "")
            let cmd = substitute(cmd, "\n$", "", "")
            return cmd
        endfunction

        " Delete the last command in the buffer
        function! repl#Repl.deleteLast() dict
            normal! G

            " XXX: This could hit an endless loop?
            " TODO: Escape `self._prompt`
            while getline("$") !~ self._prompt
                normal! dd
            endwhile

            normal! dd
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
            " Runs the repl command in self's context (held in `self._id`).
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
