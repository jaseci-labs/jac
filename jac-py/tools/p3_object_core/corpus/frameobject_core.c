/* P3.2d frameobject core extract — frame flag / lasti helpers.
 * Curated from reference/cpython Objects/frameobject.c.
 */

#include "Python.h"

#include <stddef.h>

#define FRAME_OWNED_BY_THREAD 0
#define FRAME_OWNED_BY_GENERATOR 1
#define FRAME_OWNED_BY_FRAME_OBJECT 2
#define FRAME_OWNED_BY_INTERPRETER 3

typedef struct {
    PyObject ob_base;
    int owner;
    int f_lineno;
    int stacktop;
} PyFrameObject;

int
frame_owned_by_generator(int owner)
{
    return owner == FRAME_OWNED_BY_GENERATOR;
}

int
frame_owned_by_thread(int owner)
{
    return owner == FRAME_OWNED_BY_THREAD;
}

int
frame_lineno_valid(int lineno)
{
    return lineno >= 0;
}

int
frame_stack_empty(int stacktop)
{
    return stacktop <= 0;
}
