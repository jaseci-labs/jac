"""
A Docstring
Is required at the head of every
module
"""

# This is a single line comment

#* This is
A Multiline
Comment *#
glob ver = "0.0.1";  # global variable

import defs.utils;  # import a module
import os;  # import a python module
import defs.mod_defs;  # includes a file

obj mytype {}  # define a new type


node mynode(this, that) {}  # define a new node


edge parent {}  # define a new edge


"""
Doc strings can only appear before
a declaration of an element,
and should target users, Use comments otherwise
"""
walker travelor {  # define a new walker
    def say_hello;
}

#* Declarations and definitions
can be separate in Jac *#
impl travelor.say_hello{
    "Hello" |> print;  # |> is a pipe forward operator
}

def myablty -> int { }  # define a data spacial freestyle ability


def myfunc -> None { }  # define a function


# module level freestyle code
"""A test of my functionality"""
test "mytest" {
# test code here
}
