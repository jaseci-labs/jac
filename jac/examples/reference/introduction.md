Welcome to the official reference guide for the Jac programming language. This document is designed to serve as a comprehensive reference manual as well as a formal specification of the language. The mission of this guide is to be a resource for developers seeking to answer the question, "How do I code X in Jac?"

This document is organized around the formal grammar for the language code examples and corresponding grammar snippets being directly generated from the actual grammar and test cases maintained in the official repository. We expect the descriptions may occasionally lag behind the rapid evolution of Jac in the early days. If you notice something, make a pull request and join our contributor community.

#### Whitespace

Jac uses curly braces to delimit code blocks rather than relying on indentation.
As a result, varying indentation has no effect on execution order.  Developers are
free to format code as they see fit while still retaining Python-style readability:

```jac
if condition {
  do_something();
      do_other();  # Different indentation but same block
}
```
Consistent formatting is still recommended, but the compiler treats whitespace as
insignificant when determining program structure.

#### Comments

Single-line comments begin with `#` and extend to the end of the line.  Jac also
supports multiline comments delimited by `#*` and `*#`:

```jac
# This is a line comment
#*
This entire block is ignored by the compiler.
*#
```
