" TODO:
"   -   I think the StartRepl* functions and default_context
"       should be moved into the repl#Repl object
"       so that they can be overridden.

" The name of the context to be used by default.
" Individual REPLs can use a different context
" by calling noderepl#StartReplContext.
let noderepl#default_context = 'vim-noderepl'

" The path to the Python `poste.py` module.
let noderepl#poste_path = 'noderepl'

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



let noderepl#Repl = copy(repl#Repl)

let noderepl#Repl._header = "node"
let noderepl#Repl._prompt = "node=>"

" Set up filetype-related items.
" This hook is called after the buffer has been created and initialized.
funct! noderepl#Repl._SetFileType() dict
    setfiletype javascript
endfunct


" Methods which actually interact with the interpreter
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

    " Generate the list of possible completions.
    funct! noderepl#Repl._completeList(base) dict
        let connect_info = extend(copy(g:noderepl_connect), self.connect_info)

        " python vim.command('return {0}'.format(str(["one", "two", "three"])))
        python base = vim.eval('a:base')
        python ci = vim.eval('l:connect_info')
        python cx = vim.eval('self._id')
        " TODO: sort out the lingering debug cases below
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
                                vim.eval("noderepl#poste_path")))
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
