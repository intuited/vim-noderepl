" TODO:
"   -   Make function naming/capitalization/initial-underscoring consistent
"   -   I think the StartRepl* functions and default_context
"       should be moved into the Repl object so they can be overridden.
"   -   Repl._id should be called Repl._context

" The name of the context to be used by default.
" Individual REPLs can use a different context
" by calling noderepl#StartReplContext.
let noderepl#default_context = 'vim-noderepl'

" noderepl#StartRepl(name=noderepl#default_context, unique=0)
" Creates a repl in a new buffer.
" This is called by the NodeRepl command.
funct! noderepl#StartRepl(...)
    let name = a:0 ? a:1 : g:noderepl#default_context
    let unique = a:0 > 1 ? a:2 : 0
    call g:noderepl#Repl.New(name, unique)
endfunct

" noderepl#StartReplContext(name=noderepl#default_context, unique=0)
"
" If already in a repl, start using a context with the given `name`.
" If not in a repl, start a new one in a new buffer
" using the named context.
" If the named context does not already exist, it is created.
" 
" If `unique` is nonzero, a new, unique context is created,
" using `name` as a prefix.
funct! noderepl#StartReplContext(...)
    let name = a:0 ? a:1 : g:noderepl#default_context
    let unique = a:0 > 1 ? a:2 : 0
    if exists('b:noderepl')
        let b:noderepl._id = b:noderepl._getReplContext(name, unique)
    else
        call noderepl#StartRepl(name, unique)
    endif
endfunct


" Holds connection details like port and server
" which can be overridden by setting repl dictionary elements.
" The elements should correspond to
" keyword arguments to the Python function `poste.post`.
let g:noderepl_connect = {}


" General-purpose support functions.
" These were acquired directly from VimClojure.
    function! noderepl#WithSaved(closure)
        let v = a:closure.get(a:closure.tosafe)
        let r = a:closure.f()
        call a:closure.set(a:closure.tosafe, v)
        return r
    endfunction

    function! noderepl#WithSavedPosition(closure)
        let a:closure['tosafe'] = "."
        let a:closure['get'] = function("getpos")
        let a:closure['set'] = function("setpos")
        return noderepl#WithSaved(a:closure)
    endfunction

    function! noderepl#WithSavedRegister(closure)
        let a:closure['get'] = function("getreg")
        let a:closure['set'] = function("setreg")
        return noderepl#WithSaved(a:closure)
    endfunction

    function! noderepl#Yank(r, how)
        let closure = {'tosafe': a:r, 'yank': a:how}

        function closure.f() dict
            silent execute self.yank
            return getreg(self.tosafe)
        endfunction

        return noderepl#WithSavedRegister(closure)
    endfunction


" Buffer type that the repl type is based on.
" Taken directly from VimClojure.
    let noderepl#Buffer = {}

    function! noderepl#Buffer.goHere() dict
        execute "buffer! " . self._buffer
    endfunction

    function! noderepl#Buffer.resize() dict
        call self.goHere()
        let size = line("$")
        if size < 3
            let size = 3
        endif
        execute "resize " . size
    endfunction

    function! noderepl#Buffer.showText(text) dict
        call self.goHere()
        if type(a:text) == type("")
            let text = split(a:text, '\n')
        else
            let text = a:text
        endif
        call append(line("$"), text)
    endfunction

    function! noderepl#Buffer.close() dict
        execute "bdelete! " . self._buffer
    endfunction


let noderepl#Repl = copy(noderepl#Buffer)

let noderepl#Repl._prompt = "Node=>"
let noderepl#Repl._history = []
let noderepl#Repl._historyDepth = 0

" Creates a repl in a new buffer.
" The new dictionary instance is stored in `b:noderepl`.
funct! noderepl#Repl.New(name, unique) dict
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

    let b:noderepl = instance

    call instance._SetFileType()

    call instance._SetupCompletion()

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
    " and returns the name of a repl context.
    " Parameters:
    "   name:   The name of the context to be returned.
    "           If the named context does not already exist, it is created.
    "   unique: If non-zero, the name will be used as a prefix
    "           for a new, uniquely-named context.
    " Return:
    "   The name of the created context.
    funct! noderepl#Repl._getReplContext(name, unique) dict
        " TODO: implement this stub
        "       after writing node code to create uniquely named contexts.
        " TODO: It should also be possible to select a context
        "       when executing :NodeRepl.
        let connect_info = extend(copy(g:noderepl_connect), self.connect_info)

        if a:unique
            python vim.command("return {0}".format(
                   \ NodeRepl.create_unique_context(
                     \ vim.eval('a:name'),
                     \ vim.eval('l:connect_info'))))
        else
            " If the new context doesn't need to have a unique name,
            " it will be autovivified when the first REPL command is run.
            return a:name
        endif
    endfunct

    " Set up filetype-related items.
    " This hook is called after the buffer has been created and initialized.
    funct! noderepl#Repl._SetFileType() dict
        setfiletype javascript
    endfunct

    " Set up omni completion for the REPL buffer.
    funct! noderepl#Repl._SetupCompletion() dict
        setlocal omnifunc=noderepl#OmniCompletion
    endfunct

    " Perform any node-side initialization like requiring modules.
    " The VimClojure repl loads its stacktrace module here.
    funct! noderepl#Repl._InitializeRepl() dict
        " TODO: See if anything needs to go here.
    endfunct


" Callback functions to interface with the interpreter

    " Called in response to a press of the ENTER key in insert mode.
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
    function! noderepl#Repl.upHistory() dict
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
    function! noderepl#Repl.downHistory() dict
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

" Methods which actually interact with the interpreter
    " Runs the repl command in self's context (held in `self._id`).
    " Return: `[syntax_okay, result]` where
    "     -   `syntax_okay` is non-zero if `cmd` was parsed correctly.
    "         This should be used to indicate that a command is incomplete.
    "     -   `result` is the result.
    funct! noderepl#Repl.runReplCommand(cmd)
        let connect_info = extend(copy(g:noderepl_connect), self.connect_info)

        python vim.command("return {0}".format(
                           \ NodeRepl.run_repl_command(
                             \ vim.eval("a:cmd"),
                             \ vim.eval("l:connect_info"),
                             \ context=vim.eval("self._id"))))
    endfunct



" Other support methods
    function! noderepl#Repl.showPrompt() dict
        call self.showText(self._prompt . " ")
        normal! G
        startinsert!
    endfunction

    function! noderepl#Repl.getCommand() dict
        let ln = line("$")

        while getline(ln) !~ "^" . self._prompt && ln > 0
            let ln = ln - 1
        endwhile

        " Special Case: User deleted Prompt by accident. Insert a new one.
        if ln == 0
            call self.showPrompt()
            return ""
        endif

        let cmd = noderepl#Yank("l", ln . "," . line("$") . "yank l")

        let cmd = substitute(cmd, "^" . self._prompt . "\\s*", "", "")
        let cmd = substitute(cmd, "\n$", "", "")
        return cmd
    endfunction

    function! noderepl#Repl.deleteLast() dict
        normal! G

        while getline("$") !~ self._prompt
            normal! dd
        endwhile

        normal! dd
    endfunction



" Omni-completion
    function! noderepl#OmniCompletion(findstart, base)
        if exists('b:noderepl')
            return b:noderepl.complete(a:findstart, a:base)
        else
            " This shouldn't happen.
            throw "noderepl#OmniCompletion called on non-repl buffer."
        endif
    endfunct

    funct! noderepl#Repl.complete(findstart, base) dict
        if a:findstart == 1
            return self._completeFindStart(getline('.'), col('.') - 1)
        else
            return self._completeList(a:base)
        endif
    endfunction

    " TODO: There must be a better way to do this.  Can use 'iskeyword'?
    let noderepl#Repl._wordChars = '\w\|\.'

    " Handles the completion case where a:findstart == 0.
    " Returns the column of the first character of the chunk of text
    " which should be completed at the cursor position.
    funct! noderepl#Repl._completeFindStart(line, startCol) dict
        let start = a:startCol
        while start > 0 && a:line[start - 1] =~ self._wordChars
            let start -= 1
        endwhile
        return start
    endfunct

    funct! noderepl#Repl._completeList(base) dict
        let connect_info = extend(copy(g:noderepl_connect), self.connect_info)

        " python vim.command('return {0}'.format(str(["one", "two", "three"])))
        python base = vim.eval('a:base')
        python ci = vim.eval('l:connect_info')
        python cx = vim.eval('self._id')
        python vim.command("return {0}".format(
               \ NodeRepl.complete(
                 \ vim.eval('a:base'),
                 \ vim.eval('l:connect_info'),
                 \ vim.eval('self._id'))))
        ""__  works
        python vim.command("return {0}".format(
               \ [
                 \ vim.eval('a:base'),
                 \ vim.eval('l:connect_info'),
                 \ vim.eval('self._id')]))
        ""__  should be this; doesn't work
        python vim.command("return {0}".format(
                           \ NodeRepl.complete(
                             \ vim.eval('a:base'),
                             \ vim.eval('l:connect_info'),
                             \ context=vim.eval('self._id'))))
    endfunct



python <<EOF
import vim, sys, os
sys.path.insert(0, os.path.join(vim.eval("expand('<sfile>:p:h')"),
                                "noderepl"))
import poste

class NodeRepl(object):
    """Glue code to streamline calls to the Python `poste` module."""

    @staticmethod
    def escape_string(string):
        """Escape a string for vim evaluation."""
        return "'{0}'".format(string.replace("'", "''"))

    @staticmethod
    def run_repl_command(cmd, post_args={}, context=None):
        """Pass the REPL command `cmd` to node for evaluation.
        
        The dictionary `post_args` contains keyword arguments to `poste.post`.

        Returns a string which can be evaled in vim
        to obtain the List [syntax_okay, result].
        See noderepl#Repl.runReplCommand for details.
        """
        result = poste.post(poste.Evaluate(cmd, context=context), **post_args)
        success = 0 if isinstance(result, poste.SynError) else 1
        result = NodeRepl.escape_string(str(result))
        return "[{0}, {1}]".format(success, result)

    @staticmethod
    def complete(base, post_args={}, context=None):
        """Complete the `base` expression in `context`.

        Returns a string which can be evaled in vim
        to obtain the list of completions.
        """
        request = poste.Complete(base, context=context)
        completions = poste.post(request, **post_args)
        # TODO: guard against presence of "'" within completion strings.
        completions = map(str, completions)
        return str(completions)

    @staticmethod
    def create_unique_context(prefix, post_args={}):
        request = poste.UniqueContext("", context=prefix)
        return NodeRepl.escape_string(str(poste.post(request, **post_args)))
EOF
