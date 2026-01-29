"""A simplified lexical analyzer for shell-like syntaxes used by jaccomplete."""

import os
import sys
from collections import deque
from io import StringIO
from typing import Optional


class shlex:
    """A lexical analyzer class for simple shell-like syntaxes."""

    def __init__(self, instream=None, infile=None, posix=False, punctuation_chars=False):
        if isinstance(instream, str):
            instream = StringIO(instream)
        if instream is not None:
            self.instream = instream
            self.infile = infile
        else:
            self.instream = sys.stdin
            self.infile = None
        self.posix = posix
        self.eof = None if posix else ''
        self.commenters = '#'
        self.wordchars = 'abcdfeghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789_'
        self.whitespace = ' \t\r\n'
        self.whitespace_split = False
        self.quotes = '\'"'
        self.escape = '\\'
        self.escapedquotes = '"'
        self.state: Optional[str] = ' '
        self.pushback: deque = deque()
        self.lineno = 1
        self.debug = 0
        self.token = ''
        self.source = None
        
        if not punctuation_chars:
            punctuation_chars = ''
        elif punctuation_chars is True:
            punctuation_chars = '();<>|&'
        self.punctuation_chars = punctuation_chars
        if punctuation_chars:
            self._pushback_chars: deque = deque()
            self.wordchars += '~-./*?='
            t = self.wordchars.maketrans(dict.fromkeys(punctuation_chars))
            self.wordchars = self.wordchars.translate(t)

        # jaccomplete: Record last wordbreak position
        self.last_wordbreak_pos = None
        self.wordbreaks = ''

    def push_token(self, tok):
        """Push a token onto the stack popped by the get_token method"""
        self.pushback.appendleft(tok)

    def get_token(self):
        """Get a token from the input stream (or from stack if it's nonempty)"""
        if self.pushback:
            return self.pushback.popleft()
        raw = self.read_token()
        while raw == self.eof:
            return self.eof
        return raw

    def read_token(self):
        quoted = False
        escapedstate = ' '
        while True:
            if self.punctuation_chars and self._pushback_chars:
                nextchar = self._pushback_chars.pop()
            else:
                nextchar = self.instream.read(1)
            if nextchar == '\n':
                self.lineno += 1
            
            if self.state is None:
                self.token = ''
                break
            elif self.state == ' ':
                if not nextchar:
                    self.state = None
                    break
                elif nextchar in self.whitespace:
                    if self.token or (self.posix and quoted):
                        break
                    else:
                        continue
                elif nextchar in self.commenters:
                    self.instream.readline()
                    self.lineno += 1
                elif self.posix and nextchar in self.escape:
                    escapedstate = 'a'
                    self.state = nextchar
                elif nextchar in self.wordchars:
                    self.token = nextchar
                    self.state = 'a'
                elif nextchar in self.punctuation_chars:
                    self.token = nextchar
                    self.state = 'c'
                elif nextchar in self.quotes:
                    if not self.posix:
                        self.token = nextchar
                    self.state = nextchar
                elif self.whitespace_split:
                    self.token = nextchar
                    self.state = 'a'
                    # jaccomplete: Record last wordbreak position
                    if nextchar in self.wordbreaks:
                        self.last_wordbreak_pos = len(self.token) - 1
                else:
                    self.token = nextchar
                    if self.token or (self.posix and quoted):
                        break
                    else:
                        continue
            elif self.state in self.quotes:
                quoted = True
                if not nextchar:
                    raise ValueError("No closing quotation")
                if nextchar == self.state:
                    if not self.posix:
                        self.token += nextchar
                        self.state = ' '
                        break
                    else:
                        self.state = 'a'
                elif self.posix and nextchar in self.escape and self.state in self.escapedquotes:
                    escapedstate = self.state
                    self.state = nextchar
                else:
                    self.token += nextchar
            elif self.state in self.escape:
                if not nextchar:
                    raise ValueError("No escaped character")
                if escapedstate in self.quotes and nextchar != self.state and nextchar != escapedstate:
                    self.token += self.state
                self.token += nextchar
                self.state = escapedstate
            elif self.state in ('a', 'c'):
                if not nextchar:
                    self.state = None
                    break
                elif nextchar in self.whitespace:
                    self.state = ' '
                    if self.token or (self.posix and quoted):
                        break
                    else:
                        continue
                elif nextchar in self.commenters:
                    self.instream.readline()
                    self.lineno += 1
                    if self.posix:
                        self.state = ' '
                        if self.token or (self.posix and quoted):
                            break
                        else:
                            continue
                elif self.posix and nextchar in self.quotes:
                    self.state = nextchar
                elif self.posix and nextchar in self.escape:
                    escapedstate = 'a'
                    self.state = nextchar
                elif self.state == 'c':
                    if nextchar in self.punctuation_chars:
                        self.token += nextchar
                    else:
                        if nextchar not in self.whitespace:
                            self._pushback_chars.append(nextchar)
                        self.state = ' '
                        break
                elif nextchar in self.wordchars or nextchar in self.quotes or self.whitespace_split:
                    self.token += nextchar
                    # jaccomplete: Record last wordbreak position
                    if nextchar in self.wordbreaks:
                        self.last_wordbreak_pos = len(self.token) - 1
                else:
                    if self.punctuation_chars:
                        self._pushback_chars.append(nextchar)
                    else:
                        self.pushback.appendleft(nextchar)
                    self.state = ' '
                    if self.token or (self.posix and quoted):
                        break
                    else:
                        continue
        
        result: Optional[str] = self.token
        self.token = ''
        if self.posix and not quoted and result == '':
            result = None
        # jaccomplete: Record last wordbreak position
        if self.state == ' ':
            self.last_wordbreak_pos = None
        return result

    def __iter__(self):
        return self

    def __next__(self):
        token = self.get_token()
        if token == self.eof:
            raise StopIteration
        return token
