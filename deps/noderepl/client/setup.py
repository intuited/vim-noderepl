try:
    from setuptools import setup
except ImportError:
    from distutils.core import setup

import textwrap

def format_desc(desc):
    return textwrap.fill(textwrap.dedent(desc), 200)

def format_trove(trove):
    return textwrap.dedent(trove).strip().split('\n')

def split_keywords(keywords):
    return textwrap.dedent(keywords).strip().replace('\n', ' ').split(' ')

def file_contents(filename):
    with open(filename) as f:
        return f.read()

setup(
    name = "poste_replique",
    version = "0.1.5",
    maintainer = "Ted Tibbetts",
    maintainer_email = "intuited@gmail.com",
    url = "http://github.com/intuited/poste_replique",
    description = format_desc("""
        CLI and Python API for client-side communication
        with a persistent REPL server.
        """),
    long_description = file_contents('README.txt'),
    classifiers = format_trove("""
        Development Status :: 4 - Beta
        Intended Audience :: Developers
        License :: OSI Approved :: BSD License
        Operating System :: OS Independent
        Programming Language :: Python
        Programming Language :: Python :: 2
        Topic :: Utilities
        Topic :: Software Development :: User Interfaces
        """),
    keywords = split_keywords("""
        node client repl
        """),
    py_modules = ['poste_replique'],
    scripts = ["poste_replique.py"]
    )
