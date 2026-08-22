/* P3.2d genobject core extract — generator state helpers.
 * Curated from reference/cpython Objects/genobject.c.
 */

#include "Python.h"

#include <stddef.h>

#define FRAME_CREATED 0
#define FRAME_SUSPENDED 1
#define FRAME_EXECUTING 2
#define FRAME_COMPLETED 3

typedef struct {
    PyObject ob_base;
    int gi_frame_state;
    PyObject *gi_code;
    PyObject *gi_name;
} PyGenObject;

#define _PyGen_CAST(op) ((PyGenObject *)(op))

int
gen_is_created(int state)
{
    return state == FRAME_CREATED;
}

int
gen_is_suspended(int state)
{
    return state == FRAME_SUSPENDED;
}

int
gen_is_executing(int state)
{
    return state == FRAME_EXECUTING;
}

int
gen_is_completed(int state)
{
    return state == FRAME_COMPLETED;
}

int
gen_gi_running(int state)
{
    return state == FRAME_EXECUTING;
}
