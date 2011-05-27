``poste_replique``
==================

Library and command line client to facilitate communication
with a `node`_ `replique`_ server.

.. _node: http://nodejs.org
.. _replique: http://github.com/intuited/noderepl


CLI Usage
---------

You will need to have a running replique server.
See the replique documentation for more info.

To connect with the Python CLI::

    $ poste.py evaluate '["hello", "world"].join(" ")'
    'hello world'

All evaluations take place in a persistent environment.

It is possible to use a different persistent environment
by specifying a context::

    $ poste.py evaluate --context CLI-test 'var test = "testing"'
    undefined
    $ poste.py evaluate --context CLI-test 'test'
    'testing'
    $ poste.py evaluate 'test'
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

.. _noderepl: http://github.com/intuited/noderepl


Protocol
--------

See the documentation for the replique server (found in the `noderepl`_ repo)
for information on replique's communication protocol.
