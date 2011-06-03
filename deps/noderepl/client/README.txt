``poste_replique``
==================

Library and command line client to facilitate communication
with a `node`_ `replique`_ server.

``poste_replique`` can be used to do evaluation and completion
of javascript code on a persistent node REPL.

The replique server is distributed (along with ``poste_replique``)
as part of the vim `noderepl`_ addon.

``replique`` can also be installed separately with npm::
    npm install replique

.. _node: http://nodejs.org
.. _replique: http://search.npmjs.org/#/replique
.. _noderepl: http://github.com/intuited/noderepl


CLI Usage
---------

You will need to have a running replique server.
See the replique documentation for more info.

To connect with the Python CLI::

    $ poste_replique.py evaluate '["hello", "world"].join(" ")'
    'hello world'

All evaluations take place in a persistent environment.

It is possible to use a different persistent environment
by specifying a context::

    $ poste_replique.py evaluate --context CLI-test 'var test = "testing"'
    undefined
    $ poste_replique.py evaluate --context CLI-test 'test'
    'testing'
    $ poste_replique.py evaluate 'test'
    undefined

Not specifying a context is equivalent to specifying the context "default".

It's also possible to specify a different host and/or port
using the ``--server`` and ``--port`` options.


API Usage
---------

The API is fairly straightforward.

Communication with the server consists of calling the `post` function.

See the source code or the docstrings for more information.

An example of usage can be found in the vim addon `noderepl`_.


Protocol
--------

See the documentation for the replique server (found in the `noderepl`_ repo)
for information on replique's communication protocol.
