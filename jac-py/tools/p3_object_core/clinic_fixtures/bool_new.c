/* Boolean type tp_new — Argument Clinic excerpt for clinic2jac spike (P3.1d).
 * Semantics match reference/cpython/Objects/boolobject.c bool_new().
 */

#include "Python.h"

/*[clinic input]
class bool "PyObject *" "&PyBool_Type"
@classmethod
bool.__new__ as bool_new
    object: object(c_default="NULL") = False
    /

bool(object=False, /)

Returns True when the argument is true, False otherwise.

The builtins True and False are the only two instances of the class bool.
The class bool is a subclass of the class int, and cannot be subclassed.
[clinic start generated code]*/
