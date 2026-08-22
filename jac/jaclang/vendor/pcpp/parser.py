#!/usr/bin/python
# Python C99 conforming preprocessor parser config
# (C) 2017-2020 Niall Douglas http://www.nedproductions.biz/
# and (C) 2007-2017 David Beazley http://www.dabeaz.com/
# Started: Feb 2017
#
# This C preprocessor was originally written by David Beazley and the
# original can be found at https://github.com/dabeaz/ply/blob/master/ply/cpp.py
# This edition substantially improves on standards conforming output,
# getting quite close to what clang or GCC outputs.

from __future__ import generators, print_function, absolute_import, division

import sys, re, os

in_production = 1  # Set to 0 if editing pcpp implementation!

# Some Python 3 compatibility shims
if sys.version_info.major < 3:
    STRING_TYPES = (str, unicode)
else:
    STRING_TYPES = str

# -----------------------------------------------------------------------------
# Default preprocessor lexer definitions.   These tokens are enough to get
# a basic preprocessor working.   Other modules may import these if they want
# -----------------------------------------------------------------------------

tokens = (
   'CPP_ID','CPP_INTEGER', 'CPP_FLOAT', 'CPP_STRING', 'CPP_CHAR', 'CPP_WS', 'CPP_LINECONT', 'CPP_COMMENT1', 'CPP_COMMENT2',
   'CPP_POUND','CPP_DPOUND', 'CPP_PLUS', 'CPP_MINUS', 'CPP_STAR', 'CPP_FSLASH', 'CPP_PERCENT', 'CPP_BAR',
   'CPP_AMPERSAND', 'CPP_TILDE', 'CPP_HAT', 'CPP_LESS', 'CPP_GREATER', 'CPP_EQUAL', 'CPP_EXCLAMATION',
   'CPP_QUESTION', 'CPP_LPAREN', 'CPP_RPAREN', 'CPP_LBRACKET', 'CPP_RBRACKET', 'CPP_LCURLY', 'CPP_RCURLY',
   'CPP_DOT', 'CPP_COMMA', 'CPP_SEMICOLON', 'CPP_COLON', 'CPP_BSLASH', 'CPP_SQUOTE', 'CPP_DQUOTE',

   'CPP_DEREFERENCE', 'CPP_MINUSEQUAL', 'CPP_MINUSMINUS', 'CPP_LSHIFT', 'CPP_LESSEQUAL', 'CPP_RSHIFT',
   'CPP_GREATEREQUAL', 'CPP_LOGICALOR', 'CPP_OREQUAL', 'CPP_LOGICALAND', 'CPP_ANDEQUAL', 'CPP_EQUALITY',
   'CPP_INEQUALITY', 'CPP_XOREQUAL', 'CPP_MULTIPLYEQUAL', 'CPP_DIVIDEEQUAL', 'CPP_PLUSEQUAL', 'CPP_PLUSPLUS',
   'CPP_PERCENTEQUAL', 'CPP_LSHIFTEQUAL', 'CPP_RSHIFTEQUAL'
)

literals = "+-*/%|&~^<>=!?()[]{}.,;:\\\'\""

# Whitespace, but don't match past the end of a line
def t_CPP_WS(t):
    r'([ \t]+|\n)'
    t.lexer.lineno += t.value.count("\n")
    return t

# Line continuation, accept whitespace between the backslash and new line
def t_CPP_LINECONT(t):
    r'\\[ \t]*\n'
    t.value = t.value[1:-1]
    t.lexer.lineno += 1
    return t
_string_literal_linecont_pat = re.compile(r'\\[ \t]*\n')

t_CPP_POUND = r'\#'
t_CPP_DPOUND = r'\#\#'
t_CPP_PLUS = r'\+'
t_CPP_MINUS = r'-'
t_CPP_STAR = r'\*'
t_CPP_FSLASH = r'/'
t_CPP_PERCENT = r'%'
t_CPP_BAR = r'\|'
t_CPP_AMPERSAND = r'&'
t_CPP_TILDE = r'~'
t_CPP_HAT = r'\^'
t_CPP_LESS = r'<'
t_CPP_GREATER = r'>'
t_CPP_EQUAL = r'='
t_CPP_EXCLAMATION = r'!'
t_CPP_QUESTION = r'\?'
t_CPP_LPAREN = r'\('
t_CPP_RPAREN = r'\)'
t_CPP_LBRACKET = r'\['
t_CPP_RBRACKET = r'\]'
t_CPP_LCURLY = r'{'
t_CPP_RCURLY = r'}'
t_CPP_DOT = r'\.'
t_CPP_COMMA = r','
t_CPP_SEMICOLON = r';'
t_CPP_COLON = r':'
t_CPP_BSLASH = r'\\'
t_CPP_SQUOTE = r"'"
t_CPP_DQUOTE = r'"'

t_CPP_DEREFERENCE = r'->'
t_CPP_MINUSEQUAL = r'-='
t_CPP_MINUSMINUS = r'--'
t_CPP_LSHIFT = r'<<'
t_CPP_LESSEQUAL = r'<='
t_CPP_RSHIFT = r'>>'
t_CPP_GREATEREQUAL = r'>='
t_CPP_LOGICALOR = r'\|\|'
t_CPP_OREQUAL = r'\|='
t_CPP_LOGICALAND = r'&&'
t_CPP_ANDEQUAL = r'&='
t_CPP_EQUALITY = r'=='
t_CPP_INEQUALITY = r'!='
t_CPP_XOREQUAL = r'^='
t_CPP_MULTIPLYEQUAL = r'\*='
t_CPP_DIVIDEEQUAL = r'/='
t_CPP_PLUSEQUAL = r'\+='
t_CPP_PLUSPLUS = r'\+\+'
t_CPP_PERCENTEQUAL = r'%='
t_CPP_LSHIFTEQUAL = r'<<='
t_CPP_RSHIFTEQUAL = r'>>='


# Identifier
t_CPP_ID = r'[A-Za-z_][\w_]*'

# Integer literal
def CPP_INTEGER(t):
    r'(((((0x)|(0X))[0-9a-fA-F]+)|(\d+))([uU][lL]|[lL][uU]|[uU]|[lL])?)'
    return t

t_CPP_INTEGER = CPP_INTEGER

# Floating literal
t_CPP_FLOAT = r'((\d+)(\.\d+)(e(\+|-)?(\d+))?|(\d+)e(\+|-)?(\d+))([lL]|[fF])?'

# String literal
def t_CPP_STRING(t):
    r'\"([^\\\n]|(\\(.|\n)))*?\"'
    t.value, subs_made = _string_literal_linecont_pat.subn('', t.value)
    t.lexer.lineno += subs_made + t.value.count("\n")
    return t

# Character constant 'c' or L'c'
def t_CPP_CHAR(t):
    r'(L)?\'([^\\\n]|(\\(.|\n)))*?\''
    t.lexer.lineno += t.value.count("\n")
    return t

# Comment
def t_CPP_COMMENT1(t):
    r'(/\*(.|\n)*?\*/)'
    ncr = t.value.count("\n")
    t.lexer.lineno += ncr
    return t

# Line comment
def t_CPP_COMMENT2(t):
    r'(//[^\n]*)'
    return t
    
def t_error(t):
    t.type = t.value[0]
    t.value = t.value[0]
    t.lexer.skip(1)
    return t


# Python 2/3 compatible way of importing a subpackage
oldsyspath = sys.path
sys.path = [ os.path.join( os.path.dirname( os.path.abspath(__file__) ), "ply" ) ] + sys.path
from ply import lex, yacc
from ply.lex import LexToken
sys.path = oldsyspath
del oldsyspath

# -----------------------------------------------------------------------------
# trigraph()
# 
# Given an input string, this function replaces all trigraph sequences. 
# The following mapping is used:
#
#     ??=    #
#     ??/    \
#     ??'    ^
#     ??(    [
#     ??)    ]
#     ??!    |
#     ??<    {
#     ??>    }
#     ??-    ~
# -----------------------------------------------------------------------------

_trigraph_pat = re.compile(r'''\?\?[=/\'\(\)\!<>\-]''')
_trigraph_rep = {
    '=':'#',
    '/':'\\',
    "'":'^',
    '(':'[',
    ')':']',
    '!':'|',
    '<':'{',
    '>':'}',
    '-':'~'
}

def trigraph(input):
    return _trigraph_pat.sub(lambda g: _trigraph_rep[g.group()[-1]],input)

def default_lexer():
    return lex.lex(optimize=in_production)

# ------------------------------------------------------------------
# Macro object
#
# This object holds information about preprocessor macros
#
#    .name      - Macro name (string)
#    .value     - Macro value (a list of tokens)
#    .arglist   - List of argument names
#    .variadic  - Boolean indicating whether or not variadic macro
#    .vararg    - Name of the variadic parameter
#
# When a macro is created, the macro replacement token sequence is
# pre-scanned and used to create patch lists that are later used
# during macro expansion
# ------------------------------------------------------------------

class Macro(object):
    def __init__(self,name,value,arglist=None,variadic=False):
        self.name = name
        self.value = value
        self.arglist = arglist
        self.variadic = variadic
        if variadic:
            self.vararg = arglist[-1]
        self.source = None
        self.lineno = None
    def __repr__(self):
        return "%s(%s)=%s" % (self.name, self.arglist, self.value)

# ------------------------------------------------------------------
# Preprocessor event hooks
#
# Override these to customise preprocessing
# ------------------------------------------------------------------

class Action(object):
    """What kind of abort processing to do in OutputDirective"""
    IgnoreAndPassThrough = 0
    """Abort processing (don't execute), but pass the directive through to output"""
    IgnoreAndRemove = 1
    """Abort processing (don't execute), and remove from output"""

class OutputDirective(Exception):
    """Raise this exception to abort processing of a preprocessor directive and
    to instead output it as is into the output"""
    def __init__(self, action):
        self.action = action

class PreprocessorHooks(object):
    """Override these in your subclass of Preprocessor to customise preprocessing"""
    def __init__(self):
        self.lastdirective = None

    def on_error(self,file,line,msg):
        """Called when the preprocessor has encountered an error, e.g. malformed input.
        
        The default simply prints to stderr and increments the return code.
        """
        print("%s:%d error: %s" % (file,line,msg), file = sys.stderr)
        self.return_code += 1
        
    def on_file_open(self,is_system_include,includepath):
        """Called to open a file for reading.
        
        This hook provides the ability to use ``chardet``, or any other mechanism,
        to inspect a file for its text encoding, and open it appropriately. Be
        aware that this function is used to probe for possible include file locations,
        so ``includepath`` may not exist. If it does not, raise the appropriate
        ``IOError`` exception.
        
        The default calls ``io.open(includepath, 'r', encoding = self.assume_encoding)``,
        examines if it starts with a BOM (if so, it removes it), and returns the file
        object opened. This raises the appropriate exception if the path was not found.
        """
        if sys.version_info.major < 3:
            assert self.assume_encoding is None
            ret = open(includepath, 'r')
        else:
            ret = open(includepath, 'r', encoding = self.assume_encoding)
        bom = ret.read(1)
        #print(repr(bom))
        if bom != '\ufeff':
            ret.seek(0)
        return ret

    def on_include_not_found(self,is_malformed,is_system_include,curdir,includepath):
        """Called when a #include wasn't found.
        
        Raise OutputDirective to pass through or remove, else return
        a suitable path. Remember that Preprocessor.add_path() lets you add search paths.
        
        The default calls ``self.on_error()`` with a suitable error message about the
        include file not found if ``is_malformed`` is False, else a suitable error
        message about a malformed #include, and in both cases raises OutputDirective
        (pass through).
        """
        if is_malformed:
            self.on_error(self.lastdirective.source,self.lastdirective.lineno, "Malformed #include statement: %s" % includepath)
        else:
            self.on_error(self.lastdirective.source,self.lastdirective.lineno, "Include file '%s' not found" % includepath)
        raise OutputDirective(Action.IgnoreAndPassThrough)
        
    def on_unknown_macro_in_defined_expr(self,tok):
        """Called when an expression passed to an #if contained a defined operator
        performed on something unknown.
        
        Return True if to treat it as defined, False if to treat it as undefined,
        raise OutputDirective to pass through without execution, or return None to
        pass through the mostly expanded #if expression apart from the unknown defined.
        
        The default returns False, as per the C standard.
        """
        return False

    def on_unknown_macro_in_expr(self,ident):
        """Called when an expression passed to an #if contained an unknown identifier.
        
        Return what value the expression evaluator ought to use, or return None to
        pass through the mostly expanded #if expression.
        
        The default returns an integer 0, as per the C standard.
        """
        return 0
    
    def on_unknown_macro_function_in_expr(self,ident):
        """Called when an expression passed to an #if contained an unknown function.
        
        Return a callable which will be invoked by the expression evaluator to
        evaluate the input to the function, or return None to pass through the
        mostly expanded #if expression.
        
        The default returns a lambda which returns integer 0, as per the C standard.
        """
        return lambda x : 0
    
    def on_directive_handle(self,directive,toks,ifpassthru,precedingtoks):
        """Called when there is one of
        
        define, include, undef, ifdef, ifndef, if, elif, else, endif
        
        Return True to execute and remove from the output, raise OutputDirective
        to pass through or remove without execution, or return None to execute
        AND pass through to the output (this only works for #define, #undef).
        
        The default returns True (execute and remove from the output).

        directive is the directive, toks is the tokens after the directive,
        ifpassthru is whether we are in passthru mode, precedingtoks is the
        tokens preceding the directive from the # token until the directive.
        """
        self.lastdirective = directive
        return True
        
    def on_directive_unknown(self,directive,toks,ifpassthru,precedingtoks):
        """Called when the preprocessor encounters a #directive it doesn't understand.
        This is actually quite an extensive list as it currently only understands:
        
        define, include, undef, ifdef, ifndef, if, elif, else, endif
        
        Return True to remove from the output, raise OutputDirective
        to pass through or remove, or return None to
        pass through into the output.
        
        The default handles #error and #warning by printing to stderr and returning True
        (remove from output). For everything else it returns None (pass through into output).

        directive is the directive, toks is the tokens after the directive,
        ifpassthru is whether we are in passthru mode, precedingtoks is the
        tokens preceding the directive from the # token until the directive.
        """
        if directive.value == 'error':
            print("%s:%d error: %s" % (directive.source,directive.lineno,''.join(tok.value for tok in toks)), file = sys.stderr)
            self.return_code += 1
            return True
        elif directive.value == 'warning':
            print("%s:%d warning: %s" % (directive.source,directive.lineno,''.join(tok.value for tok in toks)), file = sys.stderr)
            return True
        return None
        
    def on_potential_include_guard(self,macro):
        """Called when the preprocessor encounters an #ifndef macro or an #if !defined(macro)
        as the first non-whitespace thing in a file. Unlike the other hooks, macro is a string,
        not a token.
        """
        pass
    
    def on_comment(self,tok):
        """Called when the preprocessor encounters a comment token. You can modify the token
        in place. You must return True to let the comment pass through, else it will be removed.
        
        Returning False or None modifies the token to become whitespace, becoming a single space
        if the comment is a block comment, else a single new line if the comment is a line comment.
        """
        return None

