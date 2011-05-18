// Snappy responses to requests for completion and evaluation.
// This module doesn't really do much other than organize existing code.
// Most of its work is done by node's builtin repl module.
// It provides the ability to maintain a set of evaluation contexts
// and also provides access to evaluation without forcing the results
// to be stringified.
// A server can be run and accessed via requests in JSON format.
// If this file is run as a script, that is what will happen.

function stub() {
  console.log('A stub was called.');
}


// A context for evaluation and completion
function Context() {
}

//  Returns an object whose single key indicates the result type:
//    'value', 'error', or 'syntaxError'.
Context.prototype.evaluate = function(expression) {
  stub()
}

//  Returns an object containing
//    completions: an array of completions for `expression`
//    completed: the substring on which completion was performed
Context.prototype.complete = function(expression) {
  stub()
}


exports.Context = Context


if (!module.parent) {
  console.log('Supposed to be launching a REPL server here.');
  // TODO: write this.
}
