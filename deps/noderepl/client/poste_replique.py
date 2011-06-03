#!/usr/bin/env python
"""Post to a replique server and convey the response."""
import json
import socket
import logging
import encodings

post_log = logging.getLogger('post')


ENCODING = 'utf_8'

def _string_encode(string):
    """Encodes `string` using the selected encoding.

    Uses the normalized value of the ENCODING module variable.
    This defaults to UTF-8.

    This function, and the ENCODING value itself,
    determine the character encoding which will be used to convey server responses.
    """
    return encodings.search_function(ENCODING).encode(string)[0]


class Poste(object):
    attribs = ['command', 'code', 'context']
    def __init__(self, code, context=None):
        self.code = code
        if context:
            self.context = context
    def __str__(self):
        """The stringification can be sent directly to the server."""
        attribs = ((a, getattr(self, a, None)) for a in self.attribs)
        attribs = dict((key, value) for key, value in attribs
                       if value is not None)
        return json.dumps(attribs)

class Postes(object):
    """Container for request types."""

    class Evaluate(Poste):
        command = 'evaluate'

    class Complete(Poste):
        command = 'complete'

    class UniqueContext(Poste):
        """Used to request creation of a new, unique context.

        The `context` parameter should contain the prefix for the new context.
        """
        command = 'uniqueContext'


def Replique(replique):
    """Cast a parsed server response to an object of that type."""
    for t in _Replique.__subclasses__():
        if all(k in replique and v == replique[k]
               for k, v in t.attribs.items()):
            return t(replique)
    raise ValueError("Unknown type for replique {0}".format(replique))

class _Replique(object):
    """ABC of the various types of repliques.

    A response from the node server is type-cast
    to one of this class's descendants
    based on a match against its `attribs` attribute.
    """
    def __init__(self, replique):
        self.replique = replique
    def __repr__(self):
        return "{0}({1})".format(self.__class__.__name__, self.replique)
    def __str__(self):
        return _string_encode(str(self.replique[self.display]))

class Repliques(object):
    """Container for response types."""

    class Success(_Replique):
        attribs = {'command': 'evaluate', 'result': 'success'}
        display = 'value'

    class SyntaxError(_Replique):
        """
        Repliques of this type usually indicate that the passed code was incomplete.
        """
        attribs = {'command': 'evaluate', 'result': 'syntaxError'}
        display = 'value'

    class Error(_Replique):
        attribs = {'command': 'evaluate', 'result': 'error'}
        display = 'value'

    class Completions(_Replique):
        attribs = {'command': 'complete'}
        display = 'completions'
        def __iter__(self):
            return iter(self.replique['completions'])

    class NewContext(_Replique):
        """Indicates that a new context was successfully created."""
        attribs = {'command': 'uniqueContext'}
        display = 'context'


def post(poste, host='localhost', port=4994, timeout=2):
    """Posts `poste` and returns the response.

    `poste` should be one of the classes defined in `Postes` --
    subclasses of the `Poste` class.

    The return value will be
    an instance of one of the classes defined in `Repliques`.
    These are all subclasses of `_Replique`.
    """
    skt = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
    skt.connect((host, port))
    skt.settimeout(timeout)
    skt.sendall(str(poste))
    received = ''
    while True:
        received += skt.recv(4096)
        try:
            replique = json.loads(received)
        except ValueError:
            # Presumably there is more to come which will complete the JSON.
            post_log.debug("ValueError exception"
                           " when parsing received buffer: '{0}'"
                           .format(received))
        except Exception as e:
            post_log.warning('Non-ValueError exception occurred'
                             ' while parsing JSON response: {0}'
                             .format(e))
        else:
            return Replique(replique)


def main():
    import argparse
    parser = argparse.ArgumentParser(description="Communicate with a replique server.")
    parser.add_argument('-s', '--server', default='localhost')
    parser.add_argument('-p', '--port', type=int, default=4994)
    parser.add_argument('-c', '--context', default=None,
        help="Name of the context in which to execute this command.  "
             "A new one will be created if necessary.")
    parser.add_argument('-t', '--timeout', default=2,
        help="Timeout when waiting for a response from the server.  "
             "Normally this won't need to be changed.")
    parser.add_argument('command', choices=['evaluate', 'complete'],
        help="The command to be executed on the remote server.")
    parser.add_argument('code',
        help="The code to execute the command on.")
    options = parser.parse_args()

    PostType = {'evaluate': Postes.Evaluate,
                'complete': Postes.Complete}[options.command]
    poste = PostType(options.code, context=options.context)
    print post(poste, host=options.server, port=options.port)


if __name__ == '__main__':
    main()
