`replique`
==========

The `replique` module provides a server
which can evaluate separate chunks of code in a persistent environment.

It can also perform REPL-like completion.

Multiple contexts are supported, allowing the use of multiple
REPLs on the same server instance without namespace conflicts.

`replique` was developed for use with the vim addon [`noderepl`][],
but functions as a general server, responding to JSON-formatted requests.
For information on how to make requests, see the **Protocol** section.

It can also be used in combination with the Python [`poste_replique`][] module.
`poste_replique` provides a CLI and Python API for interaction with `replique`.

Note that there is not yet a client written for node.


Usage
-----

To start a replique server, run

    $ node src/node-replique.js

The server will open port 4994.

It is not currently possible to set the port with a command-line parameter.
It is possible to use a different port by calling the API.

For example, to run a server on port 1337:

    $ node
    > new (require('replique').Server)().listen(1337);

Subsequently, console output (including, for now, debug logging messages)
will be printed.


Protocol
--------

The replique protocol consists of requests and responses made in JSON format.

A typical exchange looks like this:

Request:

    { command: 'evaluate',
      code: '["hello", "world"].join(" ")'
    }

Response:

    { command: 'evaluate',
      result: 'success',
      value: '"hello world"'
    }

A `context` attribute can also be supplied.
If present, its value should be a string
containing the name of the evaluation context to be used.
If it is not given, the default context ("default") will be used.

The commands `complete` and `uniqueContext` are also available.

`complete` performs completion as done by node's built-in repl.
The attributes in the JSON request should be the same ones,
with `context` being optional.

`uniqueContext` can be used to generate a new, uniquely-named context.
Unique context names are formed by incrementing a numeric suffix
and appending it to an optional prefix.
This is useful to avoid name clashes with existing contexts.
A `uniqueContext` request can, in addition to the `command` attribute,
include the `context` attribute.
In this case its value will be used as the prefix.
Otherwise, the context name will just be a number.

The server will respond as soon as it receives a chunk of data
which concludes a string of properly-formed JSON data.

The properties of the responses vary by command and result.
See the test suite for a thorough set of examples.


Issues
------

Parsing of the requests is implemented by attempting to decode
repeatedly concatenated chunks of data,
which is not particularly efficent if there are multiple chunks
for a single command.

Additionally, parsing displays the same somewhat wonky behaviour
as node's built-in REPL.
See [node issue #807][] for details.


[`noderepl`]: http://github.com/intuited/noderepl
[`poste_replique`]: http://pypi.python.org/pypi/poste_replique
[node issue #807]: https://github.com/joyent/node/issues/807
