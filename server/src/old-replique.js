// TODO:
// -    Context name should be included with responses.
// -    At some point it would be nice to add a way to delete contexts.
//      -   This could cause problematic interactions with createUniqueContext.
// -    Transfer `console.log` calls over to some other logging mechanism.
//      -   a verbose or debug option would be useful for this.
// -    The server should be an object that can be instantiated
//      with the port it should run on.
// -    Reorganize this code so that there are two different request handlers
//      with process, format, etc. methods
//      rather than grouping by role and then request type.
// -    Context creation seems to be wrapping the context in which it happens.
//      This results in e.g. `writers`, `handlers`, `command` being included.
// -    Separate socket interaction layer from REPL functionality
// -    Remember why I didn't just use the core repl module in the first place
//      -   I think this was partly because of its readline integration.
//          However, webrepl seems to be able to use it successfully.
//          Node commit ba80d4d8a9e6141c00fe60b6fb65983a7f7b8fd9
//          ("Fixes non-raw REPL/Debugger on Posix.") may be relevant here.
//      -   Core repl doesn't provide context-switching functionality.
//      -   Core repl seems to be designed to output the prompt.

// Create a base context containing the default globals.
// This is used to set the contents of newly created contexts.
var baseGlobals = (function () {
  var globals = {};
  for (var e in global) globals[e] = global[e]; 
  return globals;
})();
var net = require('net');
var util = require('util');
var Script = process.binding('evals').Script;
var repl = require('repl');

net.createServer(function (stream) {
  // Accumulate code until a valid JSON string arrives,
  // then attempt to evaluate it.
  var request = '';

  stream.setEncoding('utf8');

  stream.on('data', function (chunk) {
    request += chunk;
    try {
      request = JSON.parse(request);
    } catch (e) {
      // This means the JSON was incorrectly formed
      // and is presumably incomplete.
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
   * TODO: I should also solve the mystery of why node's repl complete routine
   *       is written in such a way that it doesn't complete attributes
   *       of prototypes derived from using `Object.create`.
   */
  function derive(base, additions) {
    var attr, derived = Object.create(base);
    for (attr in additions) {
      derived[attr] = additions[attr];
    }
    return derived;
  }

  /**
   * Another one that should probably be acquired from a library.
   * TODO: Actually this is built in to node's Function prototype.
   *       Revise code to use it.
   */
  function bind(obj, method) {
    return function () {
      return method.apply(obj, arguments);
    };
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
        var i, newContext = Script.createContext();

        // Add all the globals which existed at this module's initialization
        for (i in baseGlobals) newContext[i] = baseGlobals[i];

        // Make the node-replique context available from within its REPLs.
        newContext.nodeReplique = {};
        for (i in global) newContext.nodeReplique[i] = global[i];

        newContext.module = module;
        newContext.require = require;
        return newContext;
      },

    get:
      /**
       * Make sure there's a valid name and a context for that name.
       * `name` defaults to "default".
       */
      function (name) {
        name = name || "default";
        if (!this.contexts[name]) {
          this.contexts[name] = this.createContext();
        } else if (!this.contexts.hasOwnProperty(name)) {
          // Ensure that this isn't a builtin method of Object
          throw NameError("Context name " + name
                          + " conflicts with Object builtin.");
        }
        return this.contexts[name];
      },

    createUniqueContext:
      /**
       * Creates a new uniquely-numbered context using the given prefix.
       * The context is stored in this object, and the name is returned.
       */
      function (prefix) {
        var i = 1;
        var contextName = prefix + String(i);
        while (this.contexts.hasOwnProperty(contextName)) {
          contextName = prefix + String(++i);
        }
        this.contexts[contextName] = this.createContext(contextName);
        return contextName;
      }
  };
  contexts = new Contexts();


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
    return (['evaluate', 'complete', 'uniqueContext'].indexOf(command) > -1
      ? handlers[command](contexts,
                          new writers[command](stream),
                          request)
      : invalidRequest(request, stream));
  }


/**
 * Output formatters (writers)
 * ^^^^^^^^^^^^^^^^^^^^^^^^^^^
 */

  /**
   * Base prototype for writing responses to streams.
   * How can I arrange for the constructor to be included in the derivation?
   */
  function Writer(stream) {
    stream.write('testing in Writer\n'); //~~
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
  };

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
  CompletionWriter.prototype = derive(Writer.prototype, {
    write:
      function (completions) {
        return this.writeString({ completions: completions[0],
                                  completed: completions[1] });
      }
  });

  function ContextWriter(stream) {
    this.stream = stream;
  }
  ContextWriter.prototype = derive(Writer.prototype, {
    write:
      function (context) {
        return this.writeString({ newContext: context });
      }
  });


  writers = {
    evaluate: EvalRouter,
    complete: CompletionWriter,
    uniqueContext: ContextWriter
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
    var value;

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
  function complete(context, writer, expression) {
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
      context: context
    };
    writer.write(
      repl.REPLServer.prototype.complete.call(fakeRepl, expression)
    );
  }

  /**
   * Create a new context with the given prefix and write its name.
   */
  function createUniqueContext(prefix, writer) {
    var contextName = contexts.createUniqueContext(prefix);
    writer.write(contextName);
  }

  /**
   * TODO: Reorganize the whole thing.  Right now this isn't actually used.
   */
  processors = {
    evaluate: evaluate,
    complete: complete,
    uniqueContext: createUniqueContext
  };


/**
 * Handlers
 * ^^^^^^^^
 */

  /**
   * TODO: Figure out how this should actually work.
   *       `evaluate` and `complete` are being used in 2 places.
   */

  function evalRequest(contexts, routes, request) {
    console.log('evalRequest called.');  //~~
    return evaluate(contexts.get(request.context),
                    routes, request.code);
  }

  function completeRequest(contexts, writer, request) {
    return complete(contexts.get(request.context),
                    writer, request.code);
  }

  function uniqueContextRequest(contexts, writer, request) {
    return createUniqueContext(request.context, writer);
  }

  handlers = {
    evaluate: evalRequest,
    complete: completeRequest,
    uniqueContext: uniqueContextRequest
  };