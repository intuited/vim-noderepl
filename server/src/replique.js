// Snappy responses to requests for completion and evaluation.
// This module doesn't really do much other than organize existing code.
// Most of its work is done by node's builtin repl module.
// It provides the ability to maintain a set of evaluation contexts
// and also provides access to evaluation without forcing the results
// to be stringified.
// A server can be run and accessed via requests in JSON format.
// If this file is run as a script, that is what will happen.


var vm = require('vm');
var repl = require('repl');

function stub() {
  console.log('A stub was called.');
}

/**
 * Create a base context containing the default globals.
 * This is used to initialize newly created contexts.
 */
var baseContext = (function () {
  var context = {};
  for (var e in global) context[e] = global[e]; 
  return context;
})();

/**
 * A context for evaluation and completion.
 * Based on repl.js's `resetContext` function.
 */
function Context() {
  var i, newContext = vm.createContext();

  // Add all the globals which existed at this module's initialization
  for (i in baseContext) newContext[i] = baseContext[i];

  // Make the node-replique context available from within its REPLs.
  newContext.nodeReplique = {};
  for (i in global) newContext.nodeReplique[i] = global[i];

  newContext.module = module;
  newContext.require = require;
  newContext.global = newContext;
  newContext.global.global = newContext;
  this.context = newContext;
}

/**
 * Types for evaluation results
 */
function Success(value) {
  this.result = 'success';
  this.value = value;
}
function Error(error) {
  this.result = 'error';
  this.value = error.stack || error.toString();
}
function SyntaxError(error) {
  this.result = 'syntaxError';
  this.value = error;
}


/**
 *  Evaluate `expression` in this context.
 *  Returns a Success, Error, or SyntaxError object.
 *  These types all have a `result` attribute, which indicates their type,
 *  and a `value` attribute, which holds their value or information.
 */
Context.prototype.evaluate = function(expression) {
  try {
    value = vm.runInContext(expression, this.context);
  } catch (error) {
    // repl.js says "instanceof doesn't work across context switches."
    if (error && error.constructor
              && error.constructor.name === "SyntaxError")
    {
      return new SyntaxError(error);
    } else {
      return new Error(error);
    }
  }
  return new Success(value);
};

/**
 *  Provide completion for `expression` in this context.
 *  Returns an object containing
 *    completions: an array of completions for `expression`
 *    completed: the substring on which completion was performed
 */
Context.prototype.complete = function(expression) {
  // Here I'm slightly worried because I don't understand why
  // repl.REPLServer.prototype.complete passes "repl"
  // as a third parameter to Script.runInContext.
  //
  // I *think* it just gets ignored,
  // but since the repl module just serves one context for all repls
  // it could be getting used as a context identifier in a problematic way.
  //
  // Anyway, this conjures up a `repl.REPLServer`-like object
  // to handle completion.
  var fakeRepl = {
    commands: {},
    context: this.context
  };
  var result = repl.REPLServer.prototype.complete.call(fakeRepl, expression);
  return { completions: result[0], completed: result[1] };
};


exports.Context = Context;


if (!module.parent) {
  console.log('Supposed to be launching a REPL server here.');
  // TODO: write this.
}
