// Snappy responses to requests for completion and evaluation.
//
// This module doesn't really do much other than organize existing code.
// Most of its work is done by node's builtin repl module.
// It provides the ability to maintain a set of evaluation contexts
// and also provides access to evaluation without forcing the results
// to be stringified.
// A server can be run and accessed via requests in JSON format.
// If this file is run as a script, that is what will happen.


// Used for evaluation
var vm = require('vm');
// Used for completion
var repl = require('repl');

var net = require('net');
var util = require('util');


/**
 * Types for evaluation results
 */
var results = {
  Success: function Success(value) {
    this.result = 'success';
    this.value = value;
  },
  Error: function Error(error) {
    this.result = 'error';
    this.value = error.stack || error.toString();
  },
  SyntaxError: function SyntaxError(error) {
    this.result = 'syntaxError';
    this.value = error;
  },
};


/**
 * Create a base context containing the default globals.
 * This is used to initialize newly created contexts.
 */
var baseContext = (function () {
  var e, context = {};
  for (e in global) context[e] = global[e]; 
  return context;
}());


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
Context.prototype = {
  /**
   *  Evaluate `expression` in this context.
   *  Returns a Success, Error, or SyntaxError object.
   *  These types all have a `result` attribute, which indicates their type,
   *  and a `value` attribute, which holds their value or information.
   */
  evaluate: function evaluate(expression) {
    var value;

    try {
      value = vm.runInContext(expression, this.context);
      console.log('evaluate: runInContext returned value: ' + value);  //~~
    } catch (error) {
      // repl.js says "instanceof doesn't work across context switches."
      if (error && error.constructor
                && error.constructor.name === "SyntaxError")
      {
        return new results.SyntaxError(error);
      } else {
        return new results.Error(error);
      }
    }
    return new results.Success(value);
  },

  /**
   *  Provide completion for `expression` in this context.
   *  Returns an object containing
   *    completions: an array of completions for `expression`
   *    completed: the substring on which completion was performed
   */
  complete: function complete(expression) {
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
  },
};
exports.Context = Context;


/**
 * Collection of contexts available to a server.
 * Unique context names can be requested.
 * A unique context name consists of an arbitrary prefix ending in a non-digit,
 * followed by a numeric ID.
 * The ID will be higher than that of any context name with the same prefix
 * yet used.
 * Contexts implicitly created (autovivified) by `.get` will increase the ID
 * if their name ends with one or more digits.
 */
function Contexts() {
  // Stores the contexts.  For internal use only.
  this.contexts = {};
  // Tracks the highest numeric suffix used for unique contexts.
  this.uniqueIDs = {};
}
Contexts.prototype = {
  /**
   * Return the context with the given name, or a new one.
   * `contextName` defaults to "default".
   */
  get: function (contextName) {
    var match;

    // Avoid conflicts with contents of Object.prototype.
    contextName = ':' + (contextName === undefined ? "default" : contextName);
    console.log('contextName: ' + contextName);

    if (this.contexts[contextName] === undefined) {
      this.contexts[contextName] = new Context();

      // Raise the ID suffix if appropriate.
      match = /^(.*?)(\d+)$/.exec(contextName);
      if (match && (this.uniqueIDs[match[1]] === undefined ||
                    this.uniqueIDs[match[1]] < match[2])) {
        this.uniqueIDs[match[1]] = match[2];
      }
    }
    return this.contexts[contextName];
  },

  /**
   * Creates a new uniquely-numbered context using the given prefix.
   * The context is stored in this object, and the name is returned.
   * The prefix cannot end in a number.
   * The prefix defaults to the empty string.
   * The name of the new context is returned.
   */
  uniqueContext: function (prefix) {
    if (/\d$/.exec(prefix)) {
      throw new Error('Unique context prefix ' + JSON.stringify(prefix) +
                      'cannot end in a number.');
    }

    prefix = ':' + (prefix || '');

    var id = this.uniqueIDs[prefix] ? Number(this.uniqueIDs[prefix]) + 1 : 1;
    var contextName = prefix + id;
    var context = new Context();

    this.uniqueIDs[prefix] = id;
    this.contexts[contextName] = context;

    // Strip the initial ':' and return.
    return contextName.substr(1);
  },
};
exports.Contexts = Contexts;


/**
 * A server for data requests.
 * Usage consists of creating a server and making it listen:
 *     server = Server();
 *     server.listen(4994);
 */
function Server() {
  this.contexts = new Contexts();
  this.server = net.createServer(this.onConnection.bind(this));
  this.listen = this.server.listen.bind(this.server);
}
exports.Server = Server;
Server.prototype = {
  onConnection: function onConnection(stream) {
    stream.setEncoding('utf8');

    var received = {text: ''};
    stream.on('data', this.onData.bind(this, stream, received));

    stream.on('end', function () {
      stream.end();
    });
  },

  /**
   * Accumulate code until a full, valid JSON-format request arrives,
   * then attempt to handle it.
   */
  onData: function onData(stream, received, chunk) {
    received.text += chunk;
    try {
      received.request = JSON.parse(received.text);
    } catch (e) {
      // This means the JSON was incorrectly formed
      // and is presumably incomplete.
      // We go back to waiting for another chunk.
      // TODO: check if there are any errors possible here
      //       which do not indicate incomplete JSON.
      console.log(util.inspect(['partial request', received.text]));  //~~
      return;
    }
    received.text = '';
    // TODO: go through and actually make sure that exceptions
    //       can't bubble up here.
    this.reply(received.request, stream);
  },

  /**
   * Replies to a parsed request.
   * The top-level object contains
   * -   command: "evaluate", "complete", or "uniqueContext".
   * -   context (optional): name of the evaluation context.  Created on demand.
   * -   code: the string to be evaled or completed.
   */
  reply: function reply(request, stream) {
    var command;

    console.log(util.inspect(['parsed request', request]));  //~~
    if (this.isValidCommand(request.command)) {
      return stream.write(JSON.stringify(this[request.command](request)));
    }
  },

  /**
   * Handlers for the three types of commands.
   * The method called is determined
   * by the `command` attribute of the decoded request.
   * Each method's return value is an object with
   * a `command` value equal to the method name
   * and other attributes which depend on the command.
   */

  evaluate: function (request) {
    var context = this.contexts.get(request.context);
    var result = context.evaluate(request.code);
    if (result instanceof results.Success) {
      result.value = this.formatValue(result.value);
    } else {
      result.value = this.formatMessage(result.value);
    }
    result.command = 'evaluate';
    return result;
  },
  complete: function (request) {
    var context = this.contexts.get(request.context);
    var result = context.complete(request.code);
    result.command = 'complete';
    return result;
  },
  uniqueContext: function (request) {
    var contextName = this.contexts.uniqueContext(request.context);
    return {
      command: 'uniqueContext',
      context: contextName
    };
  },
    
  /**
   * Formatter for successful evaluations.
   */
  formatValue: function (value) { return util.inspect(value) + "\n"; },
  /**
   * Formatter for errors.
   */
  formatMessage: function (message) { return message + "\n"; },

  isValidCommand: function isValidCommand(command) {
    return (['evaluate', 'complete', 'uniqueContext'].indexOf(command) > -1);
  },
};


if (!module.parent) {
  console.log('Supposed to be launching a REPL server here.');
  // TODO: write this.
}
