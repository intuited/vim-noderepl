// Snappy responses to requests for completion and evaluation.
// TODO:
//  -   Context name should be included with responses.
var net = require('net');
var util = require('util');
var Script = process.binding('evals').Script;

net.createServer(function (stream) {
  // Accumulate code until a valid JSON string arrives,
  // then attempt to evaluate it.
  var request = '';

  stream.setEncoding('utf8');

  stream.write("Testing stream writing.\n");  //~~

  stream.on('data', function (chunk) {
    stream.write("Testing stream writing in `data` listener.\n");  //~~
    request += chunk;
    try {
      request = JSON.parse(request);
    } catch (e) {
      // This means the JSON was incorrectly formed, presumably incomplete.
      // We go back to waiting for another chunk.
      // TODO: check if there are any errors possible here
      //       which do not indicate incomplete JSON.
      console.log(util.inspect(['partial request', request]));  //~~
      return;
    }
    try {
      // TODO: go through and actually make sure that exceptions
      //       can't bubble up here.
      reply(request, stream);
    } finally {
      request = '';
    }
  });
  stream.on('end', function () {
    stream.write("Testing stream writing in `end` listener.\n");  //~~
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
 * Replies to a parsed request.
 * The top-level object contains
 * -   command: "evaluate" or "complete"
 * -   context (optional): name of the evaluation context.  Created on demand.
 * -   code: the string to be evaled or completed.
 */
function reply(request, stream) {
  console.log(util.inspect(['parsed request', request]));  //~~
  command = request.command;
  return ['evaluate', 'complete'].indexOf(command) > -1
    ? handlers[command](contexts,
                        new writers[command](stream),
                        request)
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
  stream.write('testing in Writer\n') //~~
  this.stream = stream;
}
Writer.prototype = {
  writeString:
    function (value) {
      console.log('Writer.writeString called.  stream: ' + this.stream);  //~~
      this.stream.write(this.stringify(value));
    },

  stringify: JSON.stringify,

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
      console.log('routes.success called.');  //~~
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
      var content = error.stack || error.toString();
      return this.writeString({
        error: this.formatMessage(error.stack)
      });
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

  console.log('evaluate called.');  //~~
  try {
    console.log('calling runInContext...');  //~~
    value = Script.runInContext(expression, context);
    console.log('...runInContext returned value: ' + value);  //~~
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
  console.log('evalRequest called.');  //~~
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
