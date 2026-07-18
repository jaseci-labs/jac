#!/usr/bin/python
# Python C99 conforming preprocessor useful for generating single include files
# (C) 2017-2021 Niall Douglas http://www.nedproductions.biz/
# and (C) 2007-2017 David Beazley http://www.dabeaz.com/
# Started: Feb 2017
#
# This C preprocessor was originally written by David Beazley and the
# original can be found at https://github.com/dabeaz/ply/blob/master/ply/cpp.py
# This edition substantially improves on standards conforming output,
# getting quite close to what clang or GCC outputs.

from __future__ import generators, print_function, absolute_import, division

import sys, os, re, codecs, time, copy, traceback
if __name__ == '__main__' and __package__ is None:
    sys.path.append( os.path.dirname( os.path.dirname( os.path.abspath(__file__) ) ) )
from .parser import STRING_TYPES, default_lexer, trigraph, Macro, Action, OutputDirective, PreprocessorHooks
from .evaluator import Evaluator

# Some Python 3 compatibility shims
if sys.version_info.major < 3:
    FILE_TYPES = file
    clock = time.clock
else:
    xrange = range
    import io
    FILE_TYPES = io.IOBase
    clock = time.process_time

__all__ = ['Preprocessor', 'PreprocessorHooks', 'OutputDirective', 'Action', 'Evaluator']

# ------------------------------------------------------------------
# File inclusion timings
#
# Useful for figuring out how long a sequence of preprocessor inclusions actually is
# ------------------------------------------------------------------

class FileInclusionTime(object):
    """The seconds taken to #include another file"""
    def __init__(self,including_path,included_path,included_abspath,depth):
        self.including_path = including_path
        self.included_path = included_path
        self.included_abspath = included_abspath
        self.depth = depth
        self.elapsed = 0.0

# ------------------------------------------------------------------
# Preprocessor object
#
# Object representing a preprocessor.  Contains macro definitions,
# include directories, and other information
# ------------------------------------------------------------------

class Preprocessor(PreprocessorHooks):    
    def __init__(self,lexer=None):
        super(Preprocessor, self).__init__()
        if lexer is None:
            lexer = default_lexer()
        self.lexer = lexer
        self.evaluator = Evaluator(self.lexer)
        self.macros = { }
        self.path = []           # list of -I formal search paths for includes
        self.temp_path = []      # list of temporary search paths for includes
        self.rewrite_paths = [(re.escape(os.path.abspath('') + os.sep) + '(.*)', '\\1')]
        self.passthru_includes = None
        self.include_once = {}
        self.include_depth = 0
        self.include_times = []  # list of FileInclusionTime
        self.return_code = 0
        self.debugout = None
        self.auto_pragma_once_enabled = True
        self.line_directive = '#line'
        self.compress = False
        self.assume_encoding = None

        # Probe the lexer for selected tokens
        self.__lexprobe()

        tm = time.localtime()
        self.define("__DATE__ \"%s\"" % time.strftime("%b %d %Y",tm))
        self.define("__TIME__ \"%s\"" % time.strftime("%H:%M:%S",tm))
        self.define("__PCPP__ 1")
        self.expand_linemacro = True
        self.expand_filemacro = True
        self.expand_countermacro = True
        self.linemacro = 0
        self.linemacrodepth = 0
        self.countermacro = 0
        self.parser = None

    # -----------------------------------------------------------------------------
    # tokenize()
    #
    # Utility function. Given a string of text, tokenize into a list of tokens
    # -----------------------------------------------------------------------------

    def tokenize(self,text):
        """Utility function. Given a string of text, tokenize into a list of tokens"""
        tokens = []
        self.lexer.input(text)
        while True:
            tok = self.lexer.token()
            if not tok: break
            tok.source = ''
            tokens.append(tok)
        return tokens

    # ----------------------------------------------------------------------
    # __lexprobe()
    #
    # This method probes the preprocessor lexer object to discover
    # the token types of symbols that are important to the preprocessor.
    # If this works right, the preprocessor will simply "work"
    # with any suitable lexer regardless of how tokens have been named.
    # ----------------------------------------------------------------------

    def __lexprobe(self):

        # Determine the token type for identifiers
        self.lexer.input("identifier")
        tok = self.lexer.token()
        if not tok or tok.value != "identifier":
            print("Couldn't determine identifier type")
        else:
            self.t_ID = tok.type

        # Determine the token type for integers
        self.lexer.input("12345")
        tok = self.lexer.token()
        if not tok or int(tok.value) != 12345:
            print("Couldn't determine integer type")
        else:
            self.t_INTEGER = tok.type
            self.t_INTEGER_TYPE = type(tok.value)

        # Determine the token type for character
        self.lexer.input("'a'")
        tok = self.lexer.token()
        if not tok or tok.value != "'a'":
            print("Couldn't determine character type")
        else:
            self.t_CHAR = tok.type
            
        # Determine the token type for strings enclosed in double quotes
        self.lexer.input("\"filename\"")
        tok = self.lexer.token()
        if not tok or tok.value != "\"filename\"":
            print("Couldn't determine string type")
        else:
            self.t_STRING = tok.type

        # Determine the token type for whitespace--if any
        self.lexer.input("  ")
        tok = self.lexer.token()
        if not tok or tok.value != "  ":
            self.t_SPACE = None
        else:
            self.t_SPACE = tok.type

        # Determine the token type for newlines
        self.lexer.input("\n")
        tok = self.lexer.token()
        if not tok or tok.value != "\n":
            self.t_NEWLINE = None
            print("Couldn't determine token for newlines")
        else:
            self.t_NEWLINE = tok.type

        # Determine the token type for line continuations
        self.lexer.input("\\     \n")
        tok = self.lexer.token()
        if not tok or tok.value != "     ":
            self.t_LINECONT = None
            print("Couldn't determine token for line continuations")
        else:
            self.t_LINECONT = tok.type

        self.t_WS = (self.t_SPACE, self.t_NEWLINE, self.t_LINECONT)

        self.lexer.input("##")
        tok = self.lexer.token()
        if not tok or tok.value != "##":
            print("Couldn't determine token for token pasting operator")
        else:
            self.t_DPOUND = tok.type

        self.lexer.input("?")
        tok = self.lexer.token()
        if not tok or tok.value != "?":
            print("Couldn't determine token for ternary operator")
        else:
            self.t_TERNARY = tok.type

        self.lexer.input(":")
        tok = self.lexer.token()
        if not tok or tok.value != ":":
            print("Couldn't determine token for ternary operator")
        else:
            self.t_COLON = tok.type

        self.lexer.input("/* comment */")
        tok = self.lexer.token()
        if not tok or tok.value != "/* comment */":
            print("Couldn't determine comment type")
        else:
            self.t_COMMENT1 = tok.type

        self.lexer.input("// comment")
        tok = self.lexer.token()
        if not tok or tok.value != "// comment":
            print("Couldn't determine comment type")
        else:
            self.t_COMMENT2 = tok.type
            
        self.t_COMMENT = (self.t_COMMENT1, self.t_COMMENT2)

        # Check for other characters used by the preprocessor
        chars = [ '<','>','#','##','\\','(',')',',','.']
        for c in chars:
            self.lexer.input(c)
            tok = self.lexer.token()
            if not tok or tok.value != c:
                print("Unable to lex '%s' required for preprocessor" % c)

    # ----------------------------------------------------------------------
    # add_path()
    #
    # Adds a search path to the preprocessor.  
    # ----------------------------------------------------------------------

    def add_path(self,path):
        """Adds a search path to the preprocessor. """
        self.path.append(path)
        # If the search path being added is relative, or has a common ancestor to the
        # current working directory, add a rewrite to relativise includes from this
        # search path
        relpath = None
        try:
            relpath = os.path.relpath(path)
        except: pass
        if relpath is not None:
            self.rewrite_paths += [(re.escape(os.path.abspath(path) + os.sep) + '(.*)', os.path.join(relpath, '\\1'))]


    # ----------------------------------------------------------------------
    # group_lines()
    #
    # Given an input string, this function splits it into lines.  Trailing whitespace
    # is removed. This function forms the lowest level of the preprocessor---grouping
    # text into a line-by-line format.
    # ----------------------------------------------------------------------

    def group_lines(self,input,abssource):
        r"""Given an input string, this function splits it into lines.  Trailing whitespace
        is removed. This function forms the lowest level of the preprocessor---grouping
        text into a line-by-line format.
        """
        lex = self.lexer.clone()
        lines = [x.rstrip() for x in input.splitlines()]

        input = "\n".join(lines)
        lex.input(input)
        lex.lineno = 1

        current_line = []
        while True:
            tok = lex.token()
            if not tok:
                break
            tok.source = abssource
            current_line.append(tok)
            if tok.type in self.t_WS and tok.value == '\n':
                yield current_line
                current_line = []

        if current_line:
            nltok = copy.copy(current_line[-1])
            nltok.type = self.t_NEWLINE
            nltok.value = '\n'
            current_line.append(nltok)
            yield current_line

    # ----------------------------------------------------------------------
    # tokenstrip()
    # 
    # Remove leading/trailing whitespace tokens from a token list
    # ----------------------------------------------------------------------

    def tokenstrip(self,tokens):
        """Remove leading/trailing whitespace tokens from a token list"""
        i = 0
        while i < len(tokens) and tokens[i].type in self.t_WS:
            i += 1
        del tokens[:i]
        i = len(tokens)-1
        while i >= 0 and tokens[i].type in self.t_WS:
            i -= 1
        del tokens[i+1:]
        return tokens


    # ----------------------------------------------------------------------
    # collect_args()
    #
    # Collects comma separated arguments from a list of tokens.   The arguments
    # must be enclosed in parenthesis.  Returns a tuple (tokencount,args,positions)
    # where tokencount is the number of tokens consumed, args is a list of arguments,
    # and positions is a list of integers containing the starting index of each
    # argument.  Each argument is represented by a list of tokens.
    #
    # When collecting arguments, leading and trailing whitespace is removed
    # from each argument.  
    #
    # This function properly handles nested parenthesis and commas---these do not
    # define new arguments.
    # ----------------------------------------------------------------------

    def collect_args(self,tokenlist,ignore_errors=False):
        """Collects comma separated arguments from a list of tokens.   The arguments
        must be enclosed in parenthesis.  Returns a tuple (tokencount,args,positions)
        where tokencount is the number of tokens consumed, args is a list of arguments,
        and positions is a list of integers containing the starting index of each
        argument.  Each argument is represented by a list of tokens.
        
        When collecting arguments, leading and trailing whitespace is removed
        from each argument.  
        
        This function properly handles nested parenthesis and commas---these do not
        define new arguments."""
        args = []
        positions = []
        current_arg = []
        nesting = 1
        tokenlen = len(tokenlist)
    
        # Search for the opening '('.
        i = 0
        while (i < tokenlen) and (tokenlist[i].type in self.t_WS):
            i += 1

        if (i < tokenlen) and (tokenlist[i].value == '('):
            positions.append(i+1)
        else:
            if not ignore_errors:
                self.on_error(tokenlist[0].source,tokenlist[0].lineno,"Missing '(' in macro arguments")
            return 0, [], []

        i += 1

        while i < tokenlen:
            t = tokenlist[i]
            if t.value == '(':
                current_arg.append(t)
                nesting += 1
            elif t.value == ')':
                nesting -= 1
                if nesting == 0:
                    args.append(self.tokenstrip(current_arg))
                    positions.append(i)
                    return i+1,args,positions
                current_arg.append(t)
            elif t.value == ',' and nesting == 1:
                args.append(self.tokenstrip(current_arg))
                positions.append(i+1)
                current_arg = []
            else:
                current_arg.append(t)
            i += 1
    
        # Missing end argument
        if not ignore_errors:
            self.on_error(tokenlist[-1].source,tokenlist[-1].lineno,"Missing ')' in macro arguments")
        return 0, [],[]

    # ----------------------------------------------------------------------
    # macro_prescan()
    #
    # Examine the macro value (token sequence) and identify patch points
    # This is used to speed up macro expansion later on---we'll know
    # right away where to apply patches to the value to form the expansion
    # ----------------------------------------------------------------------
    
    def macro_prescan(self,macro):
        """Examine the macro value (token sequence) and identify patch points
        This is used to speed up macro expansion later on---we'll know
        right away where to apply patches to the value to form the expansion"""
        macro.patch     = []             # Standard macro arguments 
        macro.str_patch = []             # String conversion expansion
        macro.var_comma_patch = []       # Variadic macro comma patch
        i = 0
        #print("BEFORE", macro.value)
        #print("BEFORE", [x.value for x in macro.value])
        while i < len(macro.value):
            if macro.value[i].type == self.t_ID and macro.value[i].value in macro.arglist:
                argnum = macro.arglist.index(macro.value[i].value)
                # Conversion of argument to a string
                j = i - 1
                while j >= 0 and macro.value[j].type in self.t_WS:
                    j -= 1
                if j >= 0 and macro.value[j].value == '#':
                    macro.value[i] = copy.copy(macro.value[i])
                    macro.value[i].type = self.t_STRING
                    while i > j:
                        del macro.value[j]
                        i -= 1
                    macro.str_patch.append((argnum,i))
                    continue
                # Concatenation
                elif (i > 0 and macro.value[i-1].value == '##'):
                    macro.patch.append(('t',argnum,i))
                    i += 1
                    continue
                elif ((i+1) < len(macro.value) and macro.value[i+1].value == '##'):
                    macro.patch.append(('t',argnum,i))
                    i += 1
                    continue
                # Standard expansion
                else:
                    macro.patch.append(('e',argnum,i))
            elif macro.value[i].value == '##':
                if macro.variadic and (i > 0) and (macro.value[i-1].value == ',') and \
                        ((i+1) < len(macro.value)) and (macro.value[i+1].type == self.t_ID) and \
                        (macro.value[i+1].value == macro.vararg):
                    macro.var_comma_patch.append(i-1)
            i += 1
        macro.patch.sort(key=lambda x: x[2],reverse=True)
        #print("AFTER", macro.value)
        #print("AFTER", [x.value for x in macro.value])
        #print(macro.patch)

    # ----------------------------------------------------------------------
    # macro_expand_args()
    #
    # Given a Macro and list of arguments (each a token list), this method
    # returns an expanded version of a macro.  The return value is a token sequence
    # representing the replacement macro tokens
    # ----------------------------------------------------------------------

    def macro_expand_args(self,macro,args):
        """Given a Macro and list of arguments (each a token list), this method
        returns an expanded version of a macro.  The return value is a token sequence
        representing the replacement macro tokens"""
        # Make a copy of the macro token sequence
        rep = [copy.copy(_x) for _x in macro.value]

        # Make string expansion patches.  These do not alter the length of the replacement sequence
        str_expansion = {}
        for argnum, i in macro.str_patch:
            if argnum not in str_expansion:
                # Strip all non-space whitespace before stringization
                tokens = copy.copy(args[argnum])
                for j in xrange(len(tokens)):
                    if tokens[j].type in self.t_WS and tokens[j].type != self.t_LINECONT:
                        tokens[j].value = ' '
                # Collapse all multiple whitespace too
                j = 0
                while j < len(tokens) - 1:
                    if tokens[j].type in self.t_WS and tokens[j+1].type in self.t_WS:
                        del tokens[j+1]
                    else:
                        j += 1
                str = "".join([x.value for x in tokens])
                str = str.replace("\\","\\\\").replace('"', '\\"')
                str_expansion[argnum] = '"' + str + '"'
            rep[i] = copy.copy(rep[i])
            rep[i].value = str_expansion[argnum]

        # Make the variadic macro comma patch.  If the variadic macro argument is empty, we get rid
        comma_patch = False
        if macro.variadic and not args[-1]:
            for i in macro.var_comma_patch:
                rep[i] = None
                comma_patch = True

        # Make all other patches.   The order of these matters.  It is assumed that the patch list
        # has been sorted in reverse order of patch location since replacements will cause the
        # size of the replacement sequence to expand from the patch point.
        
        expanded = { }
        #print("***", macro)
        #print(macro.patch)
        for ptype, argnum, i in macro.patch:
            #print([x.value for x in rep])
            # Concatenation.   Argument is left unexpanded
            if ptype == 't':
                rep[i:i+1] = args[argnum]
            # Normal expansion.  Argument is macro expanded first
            elif ptype == 'e':
                #print('*** Function macro arg', rep[i], 'replace with', args[argnum], 'which expands into', self.expand_macros(copy.copy(args[argnum])))
                if argnum not in expanded:
                    expanded[argnum] = self.expand_macros(copy.copy(args[argnum]))
                rep[i:i+1] = expanded[argnum]

        # Get rid of removed comma if necessary
        if comma_patch:
            rep = [_i for _i in rep if _i]
            
        # Do a token concatenation pass, stitching any tokens separated by ## into a single token
        while len(rep) and rep[0].type == self.t_DPOUND:
            del rep[0]
        while len(rep) and rep[-1].type == self.t_DPOUND:
            del rep[-1]
        i = 1
        stitched = False
        while i < len(rep) - 1:
            if rep[i].type == self.t_DPOUND:
                j = i + 1
                while rep[j].type == self.t_DPOUND:
                    j += 1
                rep[i-1] = copy.copy(rep[i-1])
                rep[i-1].type = None
                rep[i-1].value += rep[j].value
                while j >= i:
                    del rep[i]
                    j -= 1
                stitched = True
            else:
                i += 1
        if stitched:
            # Stitched tokens will have unknown type, so figure those out now
            i = 0
            lex = self.lexer.clone()
            while i < len(rep):
                if rep[i].type is None:
                    lex.input(rep[i].value)
                    toks = []
                    while True:
                        tok = lex.token()
                        if not tok:
                            break
                        toks.append(tok)
                    if len(toks) != 1:
                        # Split it once again
                        while len(toks) > 1:
                            rep.insert(i+1, copy.copy(rep[i]))
                            rep[i+1].value = toks[-1].value
                            rep[i+1].type = toks[-1].type
                            toks.pop()
                        rep[i].value = toks[0].value
                        rep[i].type = toks[0].type
                    else:
                        rep[i].type = toks[0].type
                i += 1

        #print rep
        return rep


    # ----------------------------------------------------------------------
    # expand_macros()
    #
    # Given a list of tokens, this function performs macro expansion.
    # ----------------------------------------------------------------------

    def expand_macros(self,tokens,expanding_from=[]):
        """Given a list of tokens, this function performs macro expansion."""
        # Each token needs to track from which macros it has been expanded from to prevent recursion
        for tok in tokens:
            if not hasattr(tok, 'expanded_from'):
                tok.expanded_from = []
        i = 0
        #print("*** EXPAND MACROS in", "".join([t.value for t in tokens]), "expanding_from=", expanding_from)
        #print(tokens)
        #print([(t.value, t.expanded_from) for t in tokens])
        while i < len(tokens):
            t = tokens[i]
            if self.linemacrodepth == 0:
                self.linemacro = t.lineno
            self.linemacrodepth = self.linemacrodepth + 1
            if t.type == self.t_ID:
                if t.value in self.macros and t.value not in t.expanded_from and t.value not in expanding_from:
                    # Yes, we found a macro match
                    m = self.macros[t.value]
                    if m.arglist is None:
                        # A simple macro
                        rep = [copy.copy(_x) for _x in m.value]
                        ex = self.expand_macros(rep, expanding_from + [t.value])
                        #print("\nExpanding macro", m, "\ninto", ex, "\nreplacing", tokens[i:i+1])
                        for e in ex:
                            e.source = t.source
                            e.lineno = t.lineno
                            if not hasattr(e, 'expanded_from'):
                                e.expanded_from = []
                            e.expanded_from.append(t.value)
                        tokens[i:i+1] = ex
                    else:
                        # A macro with arguments
                        j = i + 1
                        while j < len(tokens) and (tokens[j].type in self.t_WS or tokens[j].type in self.t_COMMENT):
                            j += 1
                        # A function like macro without an invocation list is to be ignored
                        if j == len(tokens) or tokens[j].value != '(':
                            i = j
                        else:
                            tokcount,args,positions = self.collect_args(tokens[j:], True)
                            if tokcount == 0:
                                # Unclosed parameter list, just bail out
                                break
                            if (not m.variadic
                                # A no arg or single arg consuming macro is permitted to be expanded with nothing
                                and (args != [[]] or len(m.arglist) > 1)
                                and len(args) !=  len(m.arglist)):
                                self.on_error(t.source,t.lineno,"Macro %s requires %d arguments but was passed %d" % (t.value,len(m.arglist),len(args)))
                                i = j + tokcount
                            elif m.variadic and len(args) < len(m.arglist)-1:
                                if len(m.arglist) > 2:
                                    self.on_error(t.source,t.lineno,"Macro %s must have at least %d arguments" % (t.value, len(m.arglist)-1))
                                else:
                                    self.on_error(t.source,t.lineno,"Macro %s must have at least %d argument" % (t.value, len(m.arglist)-1))
                                i = j + tokcount
                            else:
                                if m.variadic:
                                    if len(args) == len(m.arglist)-1:
                                        args.append([])
                                    else:
                                        args[len(m.arglist)-1] = tokens[j+positions[len(m.arglist)-1]:j+tokcount-1]
                                        del args[len(m.arglist):]
                                else:
                                    # If we called a single arg macro with empty, fake extend args
                                    while len(args) < len(m.arglist):
                                        args.append([])
                                        
                                # Get macro replacement text
                                rep = self.macro_expand_args(m,args)
                                ex = self.expand_macros(rep, expanding_from + [t.value])
                                for e in ex:
                                    e.source = t.source
                                    e.lineno = t.lineno
                                    if not hasattr(e, 'expanded_from'):
                                        e.expanded_from = []
                                    e.expanded_from.append(t.value)
                                # A non-conforming extension implemented by the GCC and clang preprocessors
                                # is that an expansion of a macro with arguments where the following token is
                                # an identifier inserts a space between the expansion and the identifier. This
                                # differs from Boost.Wave incidentally (see https://github.com/ned14/pcpp/issues/29)
                                if len(tokens) > j+tokcount and tokens[j+tokcount].type in self.t_ID:
                                    #print("*** token after expansion is", tokens[j+tokcount])
                                    newtok = copy.copy(tokens[j+tokcount])
                                    newtok.type = self.t_SPACE
                                    newtok.value = ' '
                                    ex.append(newtok)
                                #print("\nExpanding macro", m, "\n\ninto", ex, "\n\nreplacing", tokens[i:j+tokcount])
                                tokens[i:j+tokcount] = ex
                    self.linemacrodepth = self.linemacrodepth - 1
                    if self.linemacrodepth == 0:
                        self.linemacro = 0
                    continue
                elif self.expand_linemacro and t.value == '__LINE__':
                    t.type = self.t_INTEGER
                    t.value = self.t_INTEGER_TYPE(self.linemacro)
                elif self.expand_countermacro and t.value == '__COUNTER__':
                    t.type = self.t_INTEGER
                    t.value = self.t_INTEGER_TYPE(self.countermacro)
                    self.countermacro += 1
                
            i += 1
            self.linemacrodepth = self.linemacrodepth - 1
            if self.linemacrodepth == 0:
                self.linemacro = 0
        return tokens

    # ----------------------------------------------------------------------    
    # evalexpr()
    # 
    # Evaluate an expression token sequence for the purposes of evaluating
    # integral expressions.
    # ----------------------------------------------------------------------

    def evalexpr(self,tokens):
        """Evaluate an expression token sequence for the purposes of evaluating
        integral expressions."""
        if not tokens:
            self.on_error('unknown', 0, "Empty expression")
            return (0, None)
        # tokens = tokenize(line)
        # Search for defined macros
        partial_expansion = False
        def replace_defined(tokens):
            i = 0
            while i < len(tokens):
                if tokens[i].type == self.t_ID and tokens[i].value == 'defined':
                    j = i + 1
                    needparen = False
                    result = "0L"
                    while j < len(tokens):
                        if tokens[j].type in self.t_WS:
                            j += 1
                            continue
                        elif tokens[j].type == self.t_ID:
                            if tokens[j].value in self.macros:
                                result = "1L"
                            else:
                                repl = self.on_unknown_macro_in_defined_expr(tokens[j])
                                if repl is None:
                                    partial_expansion = True
                                    result = 'defined('+tokens[j].value+')'
                                else:
                                    result = "1L" if repl else "0L"
                            if not needparen: break
                        elif tokens[j].value == '(':
                            needparen = True
                        elif tokens[j].value == ')':
                            break
                        else:
                            self.on_error(tokens[i].source,tokens[i].lineno,"Malformed defined()")
                        j += 1
                    if result.startswith('defined'):
                        tokens[i].type = self.t_ID
                        tokens[i].value = result
                    else:
                        tokens[i].type = self.t_INTEGER
                        tokens[i].value = self.t_INTEGER_TYPE(result)
                    del tokens[i+1:j+1]
                i += 1
            return tokens
        # Replace any defined(macro) before macro expansion
        tokens = replace_defined(tokens)
        tokens = self.expand_macros(tokens)
        # Replace any defined(macro) after macro expansion
        tokens = replace_defined(tokens)
        if not tokens:
            return (0, None)
        class IndirectToMacroHook(object):
            def __init__(self, p):
                self.__preprocessor = p
                self.partial_expansion = False
            def __contains__(self, key):
                return True
            def __getitem__(self, key):
                if key.startswith('defined('):
                    self.partial_expansion = True
                    return 0
                repl = self.__preprocessor.on_unknown_macro_in_expr(key)
                #print("*** IndirectToMacroHook[", key, "] returns", repl, file = sys.stderr)
                if repl is None:
                    self.partial_expansion = True
                    return key
                return repl
        evalvars = IndirectToMacroHook(self)
        class IndirectToMacroFunctionHook(object):
            def __init__(self, p):
                self.__preprocessor = p
                self.partial_expansion = False
            def __contains__(self, key):
                return True
            def __getitem__(self, key):
                repl = self.__preprocessor.on_unknown_macro_function_in_expr(key)
                #print("*** IndirectToMacroFunctionHook[", key, "] returns", repl, file = sys.stderr)
                if repl is None:
                    self.partial_expansion = True
                    return key
                return repl
        evalfuncts = IndirectToMacroFunctionHook(self)
        try:
            result = self.evaluator(tokens, functions = evalfuncts, identifiers = evalvars).value()
            partial_expansion = partial_expansion or evalvars.partial_expansion or evalfuncts.partial_expansion
        except OutputDirective:
            raise
        except Exception as e:
            partial_expansion = partial_expansion or evalvars.partial_expansion or evalfuncts.partial_expansion
            if not partial_expansion:
                self.on_error(tokens[0].source,tokens[0].lineno,"Could not evaluate expression due to %s (passed to evaluator: '%s')" % (repr(e), ''.join([tok.value for tok in tokens])))
            result = 0
        return (result, tokens) if partial_expansion else (result, None)

    # ----------------------------------------------------------------------
    # parsegen()
    #
    # Parse an input string
    # ----------------------------------------------------------------------
    def parsegen(self,input,source=None,abssource=None):
        """Parse an input string"""
        rewritten_source = source
        if abssource:
            rewritten_source = abssource
            for rewrite in self.rewrite_paths:
                temp = re.sub(rewrite[0], rewrite[1], rewritten_source)
                if temp != abssource:
                    rewritten_source = temp
                    if os.sep != '/':
                        rewritten_source = rewritten_source.replace(os.sep, '/')
                    break

        # Replace trigraph sequences
        t = trigraph(input)
        lines = self.group_lines(t, rewritten_source)

        if not source:
            source = ""
        if not rewritten_source:
            rewritten_source = ""
            
        my_include_times_idx = len(self.include_times)
        self.include_times.append(FileInclusionTime(self.macros['__FILE__'] if '__FILE__' in self.macros else None, source, abssource, self.include_depth))
        self.include_depth += 1
        my_include_time_begin = clock()
        if self.expand_filemacro:
            self.define("__FILE__ \"%s\"" % rewritten_source)

        self.source = abssource
        chunk = []
        enable = True
        iftrigger = False
        ifpassthru = False
        class ifstackentry(object):
            def __init__(self,enable,iftrigger,ifpassthru,startlinetoks):
                self.enable = enable
                self.iftrigger = iftrigger
                self.ifpassthru = ifpassthru
                self.rewritten = False
                self.startlinetoks = startlinetoks
        ifstack = []
        # True until any non-whitespace output or anything with effects happens.
        at_front_of_file = True
        # True if auto pragma once still a possibility for this #include
        auto_pragma_once_possible = self.auto_pragma_once_enabled
        # =(MACRO, 0) means #ifndef MACRO or #if !defined(MACRO) seen, =(MACRO,1) means #define MACRO seen
        include_guard = None
        self.on_potential_include_guard(None)

        for x in lines:
            all_whitespace = True
            skip_auto_pragma_once_possible_check = False
            # Handle comments
            for i,tok in enumerate(x):
                if tok.type in self.t_COMMENT:
                    if not self.on_comment(tok):
                        if tok.type == self.t_COMMENT1:
                            tok.value = ' '
                        elif tok.type == self.t_COMMENT2:
                            tok.value = '\n'
                        tok.type = 'CPP_WS'
            # Skip over whitespace
            for i,tok in enumerate(x):
                if tok.type not in self.t_WS and tok.type not in self.t_COMMENT:
                    all_whitespace = False
                    break
            output_and_expand_line = True
            output_unexpanded_line = False
            if tok.value == '#':
                precedingtoks = [ tok ]
                output_and_expand_line = False
                try:
                    # Preprocessor directive      
                    i += 1
                    while i < len(x) and x[i].type in self.t_WS:
                        precedingtoks.append(x[i])
                        i += 1
                    dirtokens = self.tokenstrip(x[i:])
                    if dirtokens:
                        name = dirtokens[0].value
                        args = self.tokenstrip(dirtokens[1:])
                    
                        if self.debugout is not None:
                            print("%d:%d:%d %s:%d #%s %s" % (enable, iftrigger, ifpassthru, dirtokens[0].source, dirtokens[0].lineno, dirtokens[0].value, "".join([tok.value for tok in args])), file = self.debugout)
                            #print(ifstack)

                        handling = self.on_directive_handle(dirtokens[0],args,ifpassthru,precedingtoks)
                        assert handling == True or handling == None
                    else:
                        name = ""
                        args = []
                        raise OutputDirective(Action.IgnoreAndRemove)
                        
                    if name == 'define':
                        at_front_of_file = False
                        if enable:
                            for tok in self.expand_macros(chunk):
                                yield tok
                            chunk = []
                            if include_guard and include_guard[1] == 0:
                                if include_guard[0] == args[0].value and len(args) == 1:
                                    include_guard = (args[0].value, 1)
                                    # If ifpassthru is only turned on due to this include guard, turn it off
                                    if ifpassthru and not ifstack[-1].ifpassthru:
                                        ifpassthru = False
                            self.define(args)
                            if self.debugout is not None:
                                print("%d:%d:%d %s:%d      %s" % (enable, iftrigger, ifpassthru, dirtokens[0].source, dirtokens[0].lineno, repr(self.macros[args[0].value])), file = self.debugout)
                            if handling is None:
                                for tok in x:
                                    yield tok
                    elif name == 'include':
                        if enable:
                            for tok in self.expand_macros(chunk):
                                yield tok
                            chunk = []
                            oldfile = self.macros['__FILE__'] if '__FILE__' in self.macros else None
                            if args and args[0].value != '<' and args[0].type != self.t_STRING:
                                args = self.tokenstrip(self.expand_macros(args))
                            # print('***', ''.join([x.value for x in args]), file = sys.stderr)
                            for tok in self.include(args, x):
                                yield tok
                            if oldfile is not None:
                                self.macros['__FILE__'] = oldfile
                            self.source = abssource
                    elif name == 'undef':
                        at_front_of_file = False
                        if enable:
                            for tok in self.expand_macros(chunk):
                                yield tok
                            chunk = []
                            self.undef(args)
                            if handling is None:
                                for tok in x:
                                    yield tok
                    elif name == 'ifdef':
                        at_front_of_file = False
                        ifstack.append(ifstackentry(enable,iftrigger,ifpassthru,x))
                        if enable:
                            ifpassthru = False
                            if not args[0].value in self.macros:
                                res = self.on_unknown_macro_in_defined_expr(args[0])
                                if res is None:
                                    ifpassthru = True
                                    ifstack[-1].rewritten = True
                                    raise OutputDirective(Action.IgnoreAndPassThrough)
                                elif res is True:
                                    iftrigger = True
                                else:
                                    enable = False
                                    iftrigger = False
                            else:
                                iftrigger = True
                    elif name == 'ifndef':
                        if not ifstack and at_front_of_file:
                            self.on_potential_include_guard(args[0].value)
                            include_guard = (args[0].value, 0)
                        at_front_of_file = False
                        ifstack.append(ifstackentry(enable,iftrigger,ifpassthru,x))
                        if enable:
                            ifpassthru = False
                            if args[0].value in self.macros:
                                enable = False
                                iftrigger = False
                            else:
                                res = self.on_unknown_macro_in_defined_expr(args[0])
                                if res is None:
                                    ifpassthru = True
                                    ifstack[-1].rewritten = True
                                    raise OutputDirective(Action.IgnoreAndPassThrough)
                                elif res is True:
                                    enable = False
                                    iftrigger = False
                                else:
                                    iftrigger = True
                    elif name == 'if':
                        if not ifstack and at_front_of_file:
                            if args[0].value == '!' and args[1].value == 'defined':
                                n = 2
                                if args[n].value == '(': n += 1
                                self.on_potential_include_guard(args[n].value)
                                include_guard = (args[n].value, 0)
                        at_front_of_file = False
                        ifstack.append(ifstackentry(enable,iftrigger,ifpassthru,x))
                        if enable:
                            iftrigger = False
                            ifpassthru = False
                            result, rewritten = self.evalexpr(args)
                            if rewritten is not None:
                                x = x[:i+2] + rewritten + [x[-1]]
                                x[i+1] = copy.copy(x[i+1])
                                x[i+1].type = self.t_SPACE
                                x[i+1].value = ' '
                                ifpassthru = True
                                ifstack[-1].rewritten = True
                                raise OutputDirective(Action.IgnoreAndPassThrough)
                            if not result:
                                enable = False
                            else:
                                iftrigger = True
                    elif name == 'elif':
                        at_front_of_file = False
                        if ifstack:
                            if ifstack[-1].enable:     # We only pay attention if outer "if" allows this
                                if enable and not ifpassthru:         # If already true, we flip enable False
                                    enable = False
                                elif not iftrigger:   # If False, but not triggered yet, we'll check expression
                                    result, rewritten = self.evalexpr(args)
                                    if rewritten is not None:
                                        enable = True
                                        if not ifpassthru:
                                            # This is a passthru #elif after a False #if, so convert to an #if
                                            x[i].value = 'if'
                                        x = x[:i+2] + rewritten + [x[-1]]
                                        x[i+1] = copy.copy(x[i+1])
                                        x[i+1].type = self.t_SPACE
                                        x[i+1].value = ' '
                                        ifpassthru = True
                                        ifstack[-1].rewritten = True
                                        raise OutputDirective(Action.IgnoreAndPassThrough)
                                    if ifpassthru:
                                        # If this elif can only ever be true, simulate that
                                        if result:
                                            newtok = copy.copy(x[i+3])
                                            newtok.type = self.t_INTEGER
                                            newtok.value = self.t_INTEGER_TYPE(result)
                                            x = x[:i+2] + [newtok] + [x[-1]]
                                            raise OutputDirective(Action.IgnoreAndPassThrough)
                                        # Otherwise elide
                                        enable = False
                                    elif result:
                                        enable  = True
                                        iftrigger = True
                        else:
                            self.on_error(dirtokens[0].source,dirtokens[0].lineno,"Misplaced #elif")
                            
                    elif name == 'else':
                        at_front_of_file = False
                        if ifstack:
                            if ifstack[-1].enable:
                                if ifpassthru:
                                    enable = True
                                    raise OutputDirective(Action.IgnoreAndPassThrough)
                                if enable:
                                    enable = False
                                elif not iftrigger:
                                    enable = True
                                    iftrigger = True
                        else:
                            self.on_error(dirtokens[0].source,dirtokens[0].lineno,"Misplaced #else")

                    elif name == 'endif':
                        at_front_of_file = False
                        if ifstack:
                            oldifstackentry = ifstack.pop()
                            enable = oldifstackentry.enable
                            iftrigger = oldifstackentry.iftrigger
                            ifpassthru = oldifstackentry.ifpassthru
                            if self.debugout is not None:
                                print("%d:%d:%d %s:%d      (%s:%d %s)" % (enable, iftrigger, ifpassthru, dirtokens[0].source, dirtokens[0].lineno,
                                    oldifstackentry.startlinetoks[0].source, oldifstackentry.startlinetoks[0].lineno, "".join([n.value for n in oldifstackentry.startlinetoks])), file = self.debugout)
                            skip_auto_pragma_once_possible_check = True
                            if oldifstackentry.rewritten:
                                raise OutputDirective(Action.IgnoreAndPassThrough)
                        else:
                            self.on_error(dirtokens[0].source,dirtokens[0].lineno,"Misplaced #endif")
                    elif name == 'pragma' and args[0].value == 'once':
                        if enable:
                            self.include_once[self.source] = None
                    elif enable:
                        # Unknown preprocessor directive
                        output_unexpanded_line = (self.on_directive_unknown(dirtokens[0], args, ifpassthru, precedingtoks) is None)

                except OutputDirective as e:
                    if e.action == Action.IgnoreAndPassThrough:
                        output_unexpanded_line = True
                    elif e.action == Action.IgnoreAndRemove:
                        pass
                    else:
                        assert False

            # If there is ever any non-whitespace output outside an include guard, auto pragma once is not possible
            if not skip_auto_pragma_once_possible_check and auto_pragma_once_possible and not ifstack and not all_whitespace:
                auto_pragma_once_possible = False
                if self.debugout is not None:
                    print("%d:%d:%d %s:%d Determined that #include \"%s\" is not entirely wrapped in an include guard macro, disabling auto-applying #pragma once" % (enable, iftrigger, ifpassthru, x[0].source, x[0].lineno, self.source), file = self.debugout)
                
            if output_and_expand_line or output_unexpanded_line:
                if not all_whitespace:
                    at_front_of_file = False

                # Normal text
                if enable:
                    if output_and_expand_line:
                        chunk.extend(x)
                    elif output_unexpanded_line:
                        for tok in self.expand_macros(chunk):
                            yield tok
                        chunk = []
                        for tok in x:
                            yield tok
                else:
                    # Need to extend with the same number of blank lines
                    i = 0
                    while i < len(x):
                        if x[i].type not in self.t_WS:
                            del x[i]
                        else:
                            i += 1
                    chunk.extend(x)

        for tok in self.expand_macros(chunk):
            yield tok
        chunk = []
        for i in ifstack:
            self.on_error(i.startlinetoks[0].source, i.startlinetoks[0].lineno, "Unterminated " + "".join([n.value for n in i.startlinetoks]))
        if auto_pragma_once_possible and include_guard and include_guard[1] == 1:
            if self.debugout is not None:
                print("%d:%d:%d %s:%d Determined that #include \"%s\" is entirely wrapped in an include guard macro called %s, auto-applying #pragma once" % (enable, iftrigger, ifpassthru, self.source, 0, self.source, include_guard[0]), file = self.debugout)
            self.include_once[self.source] = include_guard[0]
        elif self.auto_pragma_once_enabled and self.source not in self.include_once:
            if self.debugout is not None:
                print("%d:%d:%d %s:%d Did not auto apply #pragma once to this file due to auto_pragma_once_possible=%d, include_guard=%s" % (enable, iftrigger, ifpassthru, self.source, 0, auto_pragma_once_possible, repr(include_guard)), file = self.debugout)
        my_include_time_end = clock()
        self.include_times[my_include_times_idx].elapsed = my_include_time_end - my_include_time_begin
        self.include_depth -= 1

    # ----------------------------------------------------------------------
    # include()
    #
    # Implementation of file-inclusion
    # ----------------------------------------------------------------------

    def include(self,tokens,original_line):
        """Implementation of file-inclusion"""
        # Try to extract the filename and then process an include file
        if not tokens:
            return
        if tokens:
            if tokens[0].value != '<' and tokens[0].type != self.t_STRING:
                tokens = self.tokenstrip(self.expand_macros(tokens))

            is_system_include = False
            if tokens[0].value == '<':
                is_system_include = True
                # Include <...>
                i = 1
                while i < len(tokens):
                    if tokens[i].value == '>':
                        break
                    i += 1
                else:
                    self.on_error(tokens[0].source,tokens[0].lineno,"Malformed #include <...>")
                    return
                filename = "".join([x.value for x in tokens[1:i]])
                # Search only formally specified paths
                path = self.path
            elif tokens[0].type == self.t_STRING:
                filename = tokens[0].value[1:-1]
                # Search from each nested include file, as well as formally specified paths
                path = self.temp_path + self.path
            else:
                p = self.on_include_not_found(True,False,self.temp_path[0] if self.temp_path else '',tokens[0].value)
                assert p is None
                return
        if not path:
            path = ['']
        while True:
            #print path
            for p in path:
                iname = os.path.join(p,filename)
                fulliname = os.path.abspath(iname)
                if fulliname in self.include_once:
                    if self.debugout is not None:
                        print("x:x:x x:x #include \"%s\" skipped as already seen" % (fulliname), file = self.debugout)
                    if self.passthru_includes is not None and self.passthru_includes.match(''.join([x.value for x in tokens])):
                        for tok in original_line:
                            yield tok
                    return
                try:
                    ih = self.on_file_open(is_system_include,fulliname)
                    data = ih.read()
                    ih.close()
                    dname = os.path.dirname(fulliname)
                    if dname:
                        self.temp_path.insert(0,dname)
                    if self.passthru_includes is not None and self.passthru_includes.match(''.join([x.value for x in tokens])):
                        for tok in original_line:
                            yield tok
                        for tok in self.parsegen(data,filename,fulliname):
                            pass
                    else:
                        for tok in self.parsegen(data,filename,fulliname):
                            yield tok
                    if dname:
                        del self.temp_path[0]
                    return
                except IOError:
                    pass
            else:
                p = self.on_include_not_found(False,is_system_include,self.temp_path[0] if self.temp_path else '',filename)
                assert p is not None
                path.append(p)

    # ----------------------------------------------------------------------
    # define()
    #
    # Define a new macro
    # ----------------------------------------------------------------------

    def define(self,tokens):
        """Define a new macro"""
        if isinstance(tokens,STRING_TYPES):
            tokens = self.tokenize(tokens)
        else:
            tokens = [copy.copy(tok) for tok in tokens]
        def add_macro(self, name, macro):
            macro.source = name.source
            macro.lineno = name.lineno
            self.macros[name.value] = macro

        linetok = tokens
        try:
            name = linetok[0]
            if len(linetok) > 1:
                mtype = linetok[1]
            else:
                mtype = None
            if not mtype:
                m = Macro(name.value,[])
                add_macro(self, name, m)
            elif mtype.type in self.t_WS:
                # A normal macro
                m = Macro(name.value,self.tokenstrip(linetok[2:]))
                add_macro(self, name, m)
            elif mtype.value == '(':
                # A macro with arguments
                tokcount, args, positions = self.collect_args(linetok[1:])
                variadic = False
                for a in args:
                    if variadic:
                        self.on_error(name.source,name.lineno,"No more arguments may follow a variadic argument")
                        break
                    astr = "".join([str(_i.value) for _i in a])
                    if astr == "...":
                        variadic = True
                        a[0].type = self.t_ID
                        a[0].value = '__VA_ARGS__'
                        variadic = True
                        del a[1:]
                        continue
                    elif astr[-3:] == "..." and a[0].type == self.t_ID:
                        variadic = True
                        del a[1:]
                        # If, for some reason, "." is part of the identifier, strip off the name for the purposes
                        # of macro expansion
                        if a[0].value[-3:] == '...':
                            a[0].value = a[0].value[:-3]
                        continue
                    # Empty arguments are permitted
                    if len(a) == 0 and len(args) == 1:
                        continue
                    if len(a) > 1 or a[0].type != self.t_ID:
                        self.on_error(a[0].source,a[0].lineno,"Invalid macro argument")
                        break
                else:
                    mvalue = self.tokenstrip(linetok[1+tokcount:])
                    i = 0
                    while i < len(mvalue):
                        if i+1 < len(mvalue):
                            if mvalue[i].type in self.t_WS and mvalue[i+1].value == '##':
                                del mvalue[i]
                                continue
                            elif mvalue[i].value == '##' and mvalue[i+1].type in self.t_WS:
                                del mvalue[i+1]
                        i += 1
                    m = Macro(name.value,mvalue,[x[0].value for x in args] if args != [[]] else [],variadic)
                    self.macro_prescan(m)
                    add_macro(self, name, m)
            else:
                self.on_error(name.source,name.lineno,"Bad macro definition")
        #except LookupError:
        #    print("Bad macro definition")
        except:
            raise

    # ----------------------------------------------------------------------
    # undef()
    #
    # Undefine a macro
    # ----------------------------------------------------------------------

    def undef(self,tokens):
        """Undefine a macro"""
        if isinstance(tokens,STRING_TYPES):
            tokens = self.tokenize(tokens)
        id = tokens[0].value
        try:
            del self.macros[id]
        except LookupError:
            pass

    # ----------------------------------------------------------------------
    # parse()
    #
    # Parse input text.
    # ----------------------------------------------------------------------
    def parse(self,input,source=None,ignore={}):
        """Parse input text."""
        if isinstance(input, FILE_TYPES):
            if source is None:
                source = input.name
            input = input.read()
        self.ignore = ignore
        self.parser = self.parsegen(input,source,os.path.abspath(source) if source else None)
        if source is not None:
            dname = os.path.dirname(source)
            self.temp_path.insert(0,dname)
        
    # ----------------------------------------------------------------------
    # token()
    #
    # Method to return individual tokens
    # ----------------------------------------------------------------------
    def token(self):
        """Method to return individual tokens"""
        try:
            while True:
                tok = next(self.parser)
                if tok.type not in self.ignore:
                    return tok
        except StopIteration:
            self.parser = None
            return None
            
    def write(self, oh=sys.stdout):
        """Calls token() repeatedly, expanding tokens to their text and writing to the file like stream oh"""
        lastlineno = 0
        lastsource = None
        done = False
        blanklines = 0
        while not done:
            emitlinedirective = False
            toks = []
            all_ws = True
            # Accumulate a line
            while not done:
                tok = self.token()
                if not tok:
                    done = True
                    break
                toks.append(tok)
                if tok.value and tok.value[0] == '\n':
                    break
                if tok.type not in self.t_WS:
                    all_ws = False
            if not toks:
                break
            if all_ws:
                # Remove preceding whitespace so it becomes just a LF
                if len(toks) > 1:
                    tok = toks[-1]
                    toks = [ tok ]
                blanklines += toks[0].value.count('\n')
                continue
            # Filter out line continuations, collapsing before and after if needs be
            for n in xrange(len(toks)-1, -1, -1):
                if toks[n].type in self.t_LINECONT:
                    if n > 0 and n < len(toks) - 2 and toks[n-1].type in self.t_WS and toks[n+1].type in self.t_WS:
                        if toks[n-1].type not in self.t_LINECONT:
                            toks[n-1].value = toks[n-1].value[0]
                            del toks[n:n+2]
                    else:
                        del toks[n]
            # The line in toks is not all whitespace
            emitlinedirective = (blanklines > 6) and self.line_directive is not None
            if hasattr(toks[0], 'source'):
                if lastsource is None:
                    if toks[0].source is not None:
                        emitlinedirective = True
                    lastsource = toks[0].source
                elif lastsource != toks[0].source:
                    emitlinedirective = True
                    lastsource = toks[0].source
            # Replace consecutive whitespace in output with a single space except at any indent
            first_ws = None
            #print(toks)
            for n in xrange(len(toks)-1, -1, -1):
                tok = toks[n]
                if first_ws is None:
                    if tok.type in self.t_SPACE or len(tok.value) == 0:
                        first_ws = n
                else:
                    if tok.type not in self.t_SPACE and len(tok.value) > 0:
                        m = n + 1
                        while m != first_ws:
                            del toks[m]
                            first_ws -= 1
                        first_ws = None
                        if self.compress > 0:
                            # Collapse a token of many whitespace into single
                            if toks[m].value and toks[m].value[0] == ' ':
                                toks[m].value = ' '
            if not self.compress > 1 and not emitlinedirective:
                newlinesneeded = toks[0].lineno - lastlineno - 1
                if newlinesneeded > 6 and self.line_directive is not None:
                    emitlinedirective = True
                else:
                    while newlinesneeded > 0:
                        oh.write('\n')
                        newlinesneeded -= 1
            lastlineno = toks[0].lineno
            # Account for those newlines in a multiline comment
            if emitlinedirective and self.line_directive is not None:
                oh.write(self.line_directive + ' ' + str(lastlineno) + ('' if lastsource is None else (' "' + lastsource + '"' )) + '\n')
            for tok in toks:
                if tok.type == self.t_COMMENT1:
                    lastlineno += tok.value.count('\n')
            blanklines = 0
            #print toks[0].lineno, 
            for tok in toks:
                #print tok.value,
                oh.write(tok.value)
            #print ''

if __name__ == "__main__":
    import doctest
    doctest.testmod()

