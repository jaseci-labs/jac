/* mimalloc, compiled as its own object.
 *
 * Objects/obmalloc.c used to include mimalloc's sources into its own
 * translation unit. obmalloc is native Jac now (object_model/obmalloc.jac),
 * so mimalloc builds here, and the five hooks CPython's mimalloc
 * modifications call back into obmalloc are the Jac module's exported
 * definitions instead of obmalloc.c's statics.
 */
#include "Python.h"
#include "pycore_mimalloc.h"

void _PyMem_mi_page_clear_qsbr(mi_page_t *page);
bool _PyMem_mi_page_is_safe_to_free(mi_page_t *page);
bool _PyMem_mi_page_maybe_free(mi_page_t *page, mi_page_queue_t *pq, bool force);
void _PyMem_mi_page_reclaimed(mi_page_t *page);
void _PyMem_mi_heap_collect_qsbr(mi_heap_t *heap);

#include "mimalloc/static.c"
