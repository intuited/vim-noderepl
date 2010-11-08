#!/usr/bin/env python
"""Post to a replique server and convey the response."""
import json
import socket
import logging

post_log = logging.getLogger('post')

class Poste(object):
    attribs = ['command', 'code', 'context']
    def __init__(self, code, context=None):
        self.code = code
        if context:
            self.context = context
    def __str__(self):
        """The stringification can be sent directly to the server."""
        attribs = ((a, getattr(self, a, None)) for a in self.attribs)
        attribs = dict(kv for kv in attribs if kv[1] is not None)
        return json.dumps(attribs)

class Evaluate(Poste):
    command = 'evaluate'

class Complete(Poste):
    command = 'complete'


def Replique(replique):
    """Parse a server response into an object of that type."""
    for t in _Replique.__subclasses__():
        if t.result in replique:
            return t(replique)
    raise ValueError("No result key found in replique '{0}'"
                    .format(replique))

class _Replique(object):
    def __init__(self, replique):
        self.replique = replique
    def __repr__(self):
        return "{0}({1})".format(self.__class__.__name__, self.replique)
    def __str__(self):
        return self.replique[self.result]

class Value(_Replique):
    result = u'value'

class SynError(_Replique):
    result = 'syntaxError'

class Error(_Replique):
    result = 'error'

class Completions(_Replique):
    result = 'completions'


def post(poste, host='localhost', port=4994, timeout=2):
    """Posts `poste` and returns the response."""
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

    PostType = {'evaluate': Evaluate, 'complete': Complete}[options.command]
    poste = PostType(options.code, context=options.context)
    print post(poste, host=options.server, port=options.port)


if __name__ == '__main__':
    main()
