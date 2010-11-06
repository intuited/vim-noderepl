// Snappy responses to requests for completion and evaluation.
var net = require('net');
var util = require('util');
var Script = process.binding('evals').Script;

net.createServer(function (stream) {
  // Accumulate code until the end of input,
  // then attempt to evaluate it.
  var request = '';

  stream.setEncoding('utf8');

  stream.on('data', function (chunk) {
    request += chunk;
  });
  stream.on('end', function () {
    reply(request, stream);
    stream.end();
  });
}).listen(4994);

  
/**
 * Utility functions
 * ^^^^^^^^^^^^^^^^^
 */

/**
 * Add all attributes from `additions` to an instantiation of `base`.
 * Am I missing something?  Is there a standard way to do this?
 *
 * I should also solve the mystery of why the repl complete routine
 * is written in such a way that it doesn't complete attributes
 * of prototypes derived from using `Object.create`.
 */
function derive(base, additions) {
  var derived = Object.create(base);
  for (attr in additions) {
    derived[attr] = additions[attr];
  }
  return derived;
}

/**
 * Another one that should probably be acquired from a library.
 */
function bind(obj, method) {
  return function () {
    return method.apply(obj, arguments);
  }
}


/**
 * What happens when the object-as-dictionary abstraction leaks.
 */
function NameError(message) {
  this.name = "NameError";
  this.message = message;
}
NameError.prototype = derive(Error.prototype);


/**
 * Contexts
 * ^^^^^^^^
 */

/**
 * Holds the string-indexed set of evaluation contexts.
 * Can be initialized with an object.
 */
function Contexts(contexts) {
  this.contexts = contexts || {};
}
Contexts.prototype = {
  createContext:
    /**
     * Initialize a new context.
     * Based on repl.js's `resetContext` function.
     */
    function () {
      var newContext = Script.createContext();
      for (var i in global) newContext[i] = global[i];
        //??  Not sure if this is appropriate.
      newContext.module = module;
      newContext.require = require;
      return newContext;
    },

  get:
    /**
     * Make sure there's a valid name and a context for that name.
     */
    function (name) {
      var name = name || "default";
      if (!this.contexts[name]) {
        this.contexts[name] = this.createContext();
      } else if (!this.contexts.hasOwnProperty(name)) {
        // Ensure that this isn't a builtin method of Object
        throw NameError("Context name " + name
                        + " conflicts with Object builtin.");
      }
      return this.contexts[name];
    },
}
contexts = new Contexts()


/**
 * Main routing functionality
 * ^^^^^^^^^^^^^^^^^^^^^^^^^^
 */

/**
 * Requests should be made in JSON format.
 * The top-level object contains
 * -   command: "evaluate" or "complete"
 * -   context (optional): name of the evaluation context.  Created on demand.
 * -   code: the string to be evaled or completed.
 */
function reply(request, stream) {
  var inspect = require('util').inspect;
  console.log(inspect(['request', request]));
  request = JSON.parse(request);
  console.log(inspect(['parsed request', request]));
  command = request.command;
  return ['evaluate', 'complete'].indexOf(command) > -1
    ? handlers[command](contexts, writers[command], request)
    : invalidRequest(request, stream);
}


/**
 * Output formatters
 * ^^^^^^^^^^^^^^^^^
 */

/**
 * Base prototype for writing responses to streams.
 * How can I arrange for the constructor to be included in the derivation?
 */
function Writer(stream) {
  this.stream = stream;
}
Writer.prototype = {
  writeString:
    function (value) {
      this.stream.write(this.stringify(value));
    },

  _stringify: JSON.stringify,

  formatValue:
    /**
     * The default value formatter.
     */
    function (value) { return util.inspect(value) + "\n"; },

  formatMessage:
    /**
     * The default formatter of error messages.
     */
    function (message) { return message + "\n"; },
}

/**
 * Implements the protocol for responses to eval requests.
 */
function EvalRouter(stream) {
  this.stream = stream;
}
EvalRouter.prototype = derive(Writer.prototype, {
  success:
    function (value) {
      return this.writeString({
        value: this.formatValue(value)
      });
    },
  syntaxError:  // (Usually?) indicates an incomplete expression.
    function (error) {
      return this.writeString({
        syntaxError: this.formatMessage(error)
      });
    },
  error:
    function (error) {
      // On error: Print the error and clear the buffer
      if (error.stack) {
        return this.stream.write(this.formatMessage(error.stack));
      } else {
        return this.stream.write(this.formatMessage(error.toString()));
      }
    },
});

function CompletionWriter(stream) {
  this.stream = stream;
}
CompletionWriter.prototype = derive(Writer, {
  write:
    function (completions) {
      this.writeString({ completions: completions[0],
                         completed: completions[1] });
    }
});

writers = {
  evaluate: EvalRouter,
  complete: CompletionWriter
};
    

/**
 * Processors
 * ^^^^^^^^^^
 */

/**
 * Evaluate the request in the appropriate context.
 * A method of `routes` is called to process the result or error state.
 */
function evaluate(context, routes, expression) {
  var value, error;

  try {
    value = Script.runInContext(context, expression);
  } catch (error) {
    // repl.js says "instanceof doesn't work across context switches."
    if (error && error.constructor
              && error.constructor.name === "SyntaxError")
    {
      return routes.syntaxError(error);
    } else {
      return routes.error(error);
    }
  }
  return routes.success(value);
}

/**
 * Complete the `expression` and `write` the result.
 */
function complete(context, write, expression) {
  // Here I'm slightly worried because I don't understand why
  // repl.REPLServer.prototype.complete passes "repl"
  // as a third parameter to Script.runInContext.
  //
  // I *think* it just gets ignored,
  // but since the repl module just serves one context for all repls
  // it could be getting used as a context identifier in a problematic way.
  var fake_repl = {
    commands: {},
    context: context
  };
  write(repl.REPLServer.prototype.complete.call(fake_repl, expression));
}

processors = {
  evaluate: evaluate,
  complete: complete
};


/**
 * Handlers
 * ^^^^^^^^
 */

function evalRequest(contexts, routes, request) {
  return evaluate(contexts.get(request.context),
                  routes, request.code);
}

function completeRequest(contexts, write, request) {
  return complete(contexts.get(request.context),
                  write, request.code);
}

handlers = {
  evaluate: evalRequest,
  complete: completeRequest
};
