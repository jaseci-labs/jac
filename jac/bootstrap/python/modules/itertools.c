/* Iterator layouts, argument conversion and GC visitation for native Jac. */
#include <Python.h>
#include <stddef.h>
#include <stdint.h>
#define H(p) ((uint64_t)(uintptr_t)(p))
#define O(h) ((PyObject *)(uintptr_t)(h))
#define KW(fn) (PyCFunction)(void (*)(void))(fn)
enum { ACCUMULATE, BATCHED, CHAIN, COMPRESS, COUNT, CYCLE, DROPWHILE,
    FILTERFALSE, ISLICE, PAIRWISE, REPEAT, STARMAP, TAKEWHILE, ZIP_LONGEST,
    PRODUCT, COMBINATIONS, CWR, PERMUTATIONS, GROUPBY, GROUPER, TEE, TEE_DATA, TYPE_COUNT };
typedef struct { PyObject *types[TYPE_COUNT]; } Module;
typedef struct { PyObject_HEAD void *native; PyObject *weakrefs; int kind; } Iterator;
static PyModuleDef definition;
extern void jac_release(void *);
extern void *jacpy_pipeline_new(void);
extern void jacpy_pipeline_clear(void *);
extern uint64_t jacpy_pipeline_field(void *,int64_t), jacpy_pipeline_next(void *), jacpy_pipeline_repr(void *,uint64_t);
extern int64_t jacpy_pipeline_length(void *), jacpy_pipeline_init(void *,int64_t,uint64_t,uint64_t,uint64_t,uint64_t,int64_t,int64_t,int64_t,int64_t);
extern void *jacpy_combinatorial_new(void);
extern void jacpy_combinatorial_clear(void *);
extern uint64_t jacpy_combinatorial_field(void *,int64_t),jacpy_combinatorial_next(void *);
extern int64_t jacpy_combinatorial_memory(void *),jacpy_combinatorial_init(void *,int64_t,uint64_t,int64_t);
extern void *jacpy_group_new(void);
extern void jacpy_group_clear(void *),jacpy_group_activate(void *,uint64_t);
extern int64_t jacpy_group_init(void *,uint64_t,uint64_t);
extern uint64_t jacpy_group_field(void *,int64_t),jacpy_group_next(void *,uint64_t),jacpy_grouper_next(void *,uint64_t,uint64_t);
typedef struct { PyObject_HEAD PyObject *parent,*target; } Grouper;
static Module *module_for(PyTypeObject *type) {
    PyObject *m=PyType_GetModuleByDef(type,&definition); return m ? PyModule_GetState(m) : NULL;
}
static int kind_for(PyTypeObject *type) {
    Module *m=module_for(type); if(!m) return -1;
    for(int i=0;i<TYPE_COUNT;i++) if(m->types[i] && PyType_IsSubtype(type,(PyTypeObject *)m->types[i])) return i;
    PyErr_SetString(PyExc_SystemError,"unknown native iterator type"); return -1;
}
static int iterator_clear(PyObject *op) { Iterator *self=(Iterator *)op; if(self->native) { if(self->kind==GROUPBY) jacpy_group_clear(self->native); else if(self->kind>=PRODUCT) jacpy_combinatorial_clear(self->native); else jacpy_pipeline_clear(self->native); } return 0; }
static int iterator_traverse(PyObject *op,visitproc visit,void *arg) {
    Iterator *self=(Iterator *)op; Py_VISIT(Py_TYPE(op));
    if(self->native) { if(self->kind==GROUPBY) { for(int i=0;i<5;i++) Py_VISIT(O(jacpy_group_field(self->native,i))); } else if(self->kind>=PRODUCT) { for(int i=0;i<2;i++) Py_VISIT(O(jacpy_combinatorial_field(self->native,i))); } else { for(int i=0;i<7;i++) Py_VISIT(O(jacpy_pipeline_field(self->native,i))); } } return 0;
}
static void iterator_dealloc(PyObject *op) {
    Iterator *self=(Iterator *)op; PyTypeObject *type=Py_TYPE(op); PyObject_GC_UnTrack(op);
    if(self->weakrefs) PyObject_ClearWeakRefs(op);
    iterator_clear(op); if(self->native) jac_release(self->native); type->tp_free(op); Py_DECREF(type);
}
static PyObject *iterator_next(PyObject *op) { Iterator *self=(Iterator *)op; return O(self->kind==GROUPBY ? jacpy_group_next(self->native,H(op)) : self->kind>=PRODUCT ? jacpy_combinatorial_next(self->native) : jacpy_pipeline_next(self->native)); }
static PyObject *iterator_repr(PyObject *op) { return O(jacpy_pipeline_repr(((Iterator *)op)->native,H(op))); }
static PyObject *repeat_length(PyObject *op,PyObject *unused) {
    int64_t length=jacpy_pipeline_length(((Iterator *)op)->native);
    if(length<0) { PyErr_SetString(PyExc_TypeError,"len() of unsized object"); return NULL; } return PyLong_FromLongLong(length);
}
static PyObject *pipeline_create(PyTypeObject *type,int kind,PyObject *source,PyObject *second,PyObject *function,PyObject *initial,Py_ssize_t first,Py_ssize_t stop,Py_ssize_t step,int flag) {
    Iterator *self=(Iterator *)type->tp_alloc(type,0); if(!self) return NULL;
    self->kind=kind; self->native=jacpy_pipeline_new();
    if(jacpy_pipeline_init(self->native,kind,H(source),H(second),H(function),H(initial),first,stop,step,flag)<0) { Py_DECREF(self); return NULL; }
    return (PyObject *)self;
}
static int no_keywords(PyTypeObject *type,int kind,PyObject *kw) {
    if(!kw || !PyDict_GET_SIZE(kw)) return 1;
    Module *m=module_for(type); if(!m) return 0;
    PyTypeObject *base=(PyTypeObject *)m->types[kind];
    if(type!=base && type->tp_init!=base->tp_init) return 1;
    PyErr_Format(PyExc_TypeError,"%s() takes no keyword arguments",type->tp_name); return 0;
}
static PyObject *iterator_new(PyTypeObject *type,PyObject *args,PyObject *kw) {
    int kind=kind_for(type); if(kind<0) return NULL;
    PyObject *source=NULL,*second=NULL,*function=NULL,*initial=NULL,*owned_first=NULL,*owned_second=NULL;
    Py_ssize_t first=0,stop=-1,step=1; int flag=0;
    if(kind==GROUPBY) {
        static char *names[]={"iterable","key",NULL}; function=Py_None;
        if(!PyArg_ParseTupleAndKeywords(args,kw,"O|O:groupby",names,&source,&function)) return NULL;
        Iterator *self=(Iterator *)type->tp_alloc(type,0); if(!self) return NULL;
        self->kind=kind; self->native=jacpy_group_new();
        if(jacpy_group_init(self->native,H(source),H(function))<0) { Py_DECREF(self); return NULL; } return (PyObject *)self;
    } else if(kind>=PRODUCT) {
        if(kind==PRODUCT) {
            source=args; step=1;
            if(kw && PyDict_GET_SIZE(kw)) {
                PyObject *repeat=PyDict_GetItemString(kw,"repeat");
                if(!repeat || PyDict_GET_SIZE(kw)!=1) { PyErr_SetString(PyExc_TypeError,"product() takes at most 1 keyword argument"); return NULL; }
                step=PyLong_AsSsize_t(repeat); if(step==-1 && PyErr_Occurred()) return NULL;
            }
            if(step<0) { PyErr_SetString(PyExc_ValueError,"repeat argument cannot be negative"); return NULL; }
        } else {
            static char *names[]={"iterable","r",NULL}; PyObject *r=Py_None;
            if(kind==PERMUTATIONS) {
                if(!PyArg_ParseTupleAndKeywords(args,kw,"O|O:permutations",names,&source,&r)) return NULL;
                if(r==Py_None) step=-1;
                else { step=PyLong_AsSsize_t(r); if(step==-1 && PyErr_Occurred()) return NULL; }
                if(r!=Py_None && step<0) { PyErr_SetString(PyExc_ValueError,"r must be non-negative"); return NULL; }
            } else {
                if(!PyArg_ParseTupleAndKeywords(args,kw,"On",names,&source,&step)) return NULL;
                if(step<0) { PyErr_SetString(PyExc_ValueError,"r must be non-negative"); return NULL; }
            }
        }
        Iterator *self=(Iterator *)type->tp_alloc(type,0); if(!self) return NULL;
        self->kind=kind; self->native=jacpy_combinatorial_new();
        if(jacpy_combinatorial_init(self->native,kind,H(source),step)<0) { Py_DECREF(self); return NULL; } return (PyObject *)self;
    } else if(kind==ACCUMULATE) {
        static char *names[]={"iterable","func","initial",NULL}; function=initial=Py_None;
        if(!PyArg_ParseTupleAndKeywords(args,kw,"O|O$O:accumulate",names,&source,&function,&initial)) return NULL;
    } else if(kind==BATCHED) {
        static char *names[]={"iterable","n","strict",NULL};
        if(!PyArg_ParseTupleAndKeywords(args,kw,"On|$p:batched",names,&source,&step,&flag)) return NULL;
        if(step<1) { PyErr_SetString(PyExc_ValueError,"n must be at least one"); return NULL; }
    } else if(kind==COUNT) {
        static char *names[]={"start","step",NULL};
        if(!PyArg_ParseTupleAndKeywords(args,kw,"|OO:count",names,&source,&second)) return NULL;
        if((source && !PyNumber_Check(source)) || (second && !PyNumber_Check(second))) { PyErr_SetString(PyExc_TypeError,"a number is required"); return NULL; }
        if(!source) { source=owned_first=PyLong_FromLong(0); if(!source) return NULL; }
        if(!second) { second=owned_second=PyLong_FromLong(1); if(!second) { Py_XDECREF(owned_first); return NULL; } }
    } else if(kind==REPEAT) {
        static char *names[]={"object","times",NULL};
        if(!PyArg_ParseTupleAndKeywords(args,kw,"O|n:repeat",names,&source,&stop)) return NULL;
        if((PyTuple_GET_SIZE(args)>1 || (kw && PyDict_GetItemString(kw,"times"))) && stop<0) stop=0;
    } else if(kind==CHAIN) {
        if(!no_keywords(type,kind,kw)) return NULL; source=args;
    } else if(kind==ZIP_LONGEST) {
        source=args; function=Py_None;
        if(kw && PyDict_GET_SIZE(kw)) {
            function=PyDict_GetItemString(kw,"fillvalue");
            if(!function || PyDict_GET_SIZE(kw)!=1) { PyErr_SetString(PyExc_TypeError,"zip_longest() got an unexpected keyword argument"); return NULL; }
        }
    } else if(kind==ISLICE) {
        if(!no_keywords(type,kind,kw)) return NULL;
        PyObject *a=NULL,*b=NULL,*c=NULL;
        if(!PyArg_UnpackTuple(args,"islice",2,4,&source,&a,&b,&c)) return NULL;
        if(!b) { b=a; a=Py_None; }
        if(a!=Py_None) first=PyNumber_AsSsize_t(a,PyExc_OverflowError);
        if(first==-1 && PyErr_Occurred()) PyErr_Clear();
        if(b!=Py_None) {
            stop=PyNumber_AsSsize_t(b,PyExc_OverflowError);
            if(stop==-1) { PyErr_Clear(); PyErr_SetString(PyExc_ValueError,"Stop argument for islice() must be None or an integer: 0 <= x <= sys.maxsize."); return NULL; }
        }
        if(first<0 || stop<-1) { PyErr_SetString(PyExc_ValueError,"Indices for islice() must be None or an integer: 0 <= x <= sys.maxsize."); return NULL; }
        if(c && c!=Py_None) step=PyNumber_AsSsize_t(c,PyExc_OverflowError);
        if(step<1) { PyErr_Clear(); PyErr_SetString(PyExc_ValueError,"Step for islice() must be a positive integer or None."); return NULL; }
    } else if(kind==COMPRESS) {
        static char *names[]={"data","selectors",NULL};
        if(!PyArg_ParseTupleAndKeywords(args,kw,"OO:compress",names,&source,&second)) return NULL;
    } else if(kind==CYCLE || kind==PAIRWISE) {
        if(!no_keywords(type,kind,kw) || !PyArg_UnpackTuple(args,type->tp_name,1,1,&source)) return NULL;
    } else {
        if(!no_keywords(type,kind,kw) || !PyArg_UnpackTuple(args,type->tp_name,2,2,&function,&source)) return NULL;
    }
    PyObject *result=pipeline_create(type,kind,source,second,function,initial,first,stop,step,flag);
    Py_XDECREF(owned_first); Py_XDECREF(owned_second); return result;
}
static PyObject *chain_from(PyObject *cls,PyObject *source) { return pipeline_create((PyTypeObject *)cls,CHAIN,source,NULL,NULL,NULL,0,-1,1,0); }
static PyMethodDef chain_methods[]={
    {"from_iterable",chain_from,METH_O|METH_CLASS,"from_iterable($type, iterable, /)\n--\n\nAlternative chain constructor taking a single iterable argument."},
    {"__class_getitem__",Py_GenericAlias,METH_O|METH_CLASS,"See PEP 585"},{NULL}};
static PyMethodDef repeat_methods[]={{"__length_hint__",repeat_length,METH_NOARGS,"Private method returning an estimate of len(list(it))."},{NULL}};
static PyObject *combinatorial_sizeof(PyObject *op,PyObject *unused) { return PyLong_FromSsize_t(Py_TYPE(op)->tp_basicsize+jacpy_combinatorial_memory(((Iterator *)op)->native)); }
static PyMethodDef combinatorial_methods[]={{"__sizeof__",combinatorial_sizeof,METH_NOARGS,"Returns size in memory, in bytes."},{NULL}};
static int grouper_clear(PyObject *op) { Grouper *self=(Grouper *)op; Py_CLEAR(self->parent); Py_CLEAR(self->target); return 0; }
static int grouper_traverse(PyObject *op,visitproc visit,void *arg) { Grouper *self=(Grouper *)op; Py_VISIT(Py_TYPE(op)); Py_VISIT(self->parent); Py_VISIT(self->target); return 0; }
static void grouper_dealloc(PyObject *op) { PyTypeObject *type=Py_TYPE(op); PyObject_GC_UnTrack(op); grouper_clear(op); type->tp_free(op); Py_DECREF(type); }
uint64_t jacpy_grouper_create(uint64_t parent,uint64_t target) {
    Module *m=module_for(Py_TYPE(O(parent))); if(!m) return 0;
    PyTypeObject *type=(PyTypeObject *)m->types[GROUPER];
    Grouper *self=(Grouper *)type->tp_alloc(type,0); if(!self) return 0;
    self->parent=Py_NewRef(O(parent)); self->target=Py_NewRef(O(target));
    jacpy_group_activate(((Iterator *)self->parent)->native,H(self)); return H(self);
}
static PyObject *grouper_new(PyTypeObject *type,PyObject *args,PyObject *kw) {
    PyObject *parent,*target; Module *m=module_for(type); if(!m) return NULL;
    if(!no_keywords(type,GROUPER,kw) || !PyArg_ParseTuple(args,"O!O:_grouper",m->types[GROUPBY],&parent,&target)) return NULL;
    return O(jacpy_grouper_create(H(parent),H(target)));
}
static PyObject *grouper_next(PyObject *op) { Grouper *self=(Grouper *)op; return O(jacpy_grouper_next(((Iterator *)self->parent)->native,H(op),H(self->target))); }
static PyType_Slot grouper_slots[]={
    {Py_tp_new,grouper_new},{Py_tp_dealloc,grouper_dealloc},{Py_tp_traverse,grouper_traverse},{Py_tp_clear,grouper_clear},
    {Py_tp_iter,PyObject_SelfIter},{Py_tp_iternext,grouper_next},{0}};
static PyType_Spec grouper_spec={"itertools._grouper",sizeof(Grouper),0,Py_TPFLAGS_DEFAULT|Py_TPFLAGS_HAVE_GC|Py_TPFLAGS_IMMUTABLETYPE,grouper_slots};
extern void jac_retain(void *);
extern void *jacpy_tee_block_new(void);
extern int64_t jacpy_tee_block_init(void *,uint64_t,uint64_t,uint64_t),jacpy_tee_block_count(void *);
extern uint64_t jacpy_tee_block_field(void *,int64_t),jacpy_tee_cursor_field(void *),jacpy_tee_next(void *);
extern void jacpy_tee_block_clear(void *),jacpy_tee_cursor_clear(void *);
extern uint64_t jacpy_tee_construct(uint64_t,uint64_t,uint64_t),jacpy_tee_split(uint64_t,uint64_t,uint64_t,int64_t);
static int tee_clear(PyObject *op) { Iterator *self=(Iterator *)op; if(self->native) jacpy_tee_cursor_clear(self->native); return 0; }
static int data_clear(PyObject *op) { Iterator *self=(Iterator *)op; if(self->native) jacpy_tee_block_clear(self->native); return 0; }
static int tee_traverse(PyObject *op,visitproc visit,void *arg) { Iterator *self=(Iterator *)op; Py_VISIT(Py_TYPE(op)); if(self->native) Py_VISIT(O(jacpy_tee_cursor_field(self->native))); return 0; }
static int data_traverse(PyObject *op,visitproc visit,void *arg) {
    Iterator *self=(Iterator *)op; Py_VISIT(Py_TYPE(op));
    if(self->native) for(int64_t i=0,n=jacpy_tee_block_count(self->native);i<n;i++) Py_VISIT(O(jacpy_tee_block_field(self->native,i))); return 0;
}
static void tee_dealloc(PyObject *op) {
    Iterator *self=(Iterator *)op; PyTypeObject *type=Py_TYPE(op); PyObject_GC_UnTrack(op);
    if(self->weakrefs) PyObject_ClearWeakRefs(op);
    tee_clear(op); if(self->native) jac_release(self->native); type->tp_free(op); Py_DECREF(type);
}
static void data_dealloc(PyObject *op) {
    Iterator *self=(Iterator *)op; PyTypeObject *type=Py_TYPE(op); PyObject_GC_UnTrack(op);
    Py_TRASHCAN_BEGIN(op,data_dealloc)
    data_clear(op); if(self->native) jac_release(self->native); type->tp_free(op); Py_DECREF(type);
    Py_TRASHCAN_END
}
uint64_t jacpy_tee_block_wrap(uint64_t type_handle,void *state) {
    PyTypeObject *type=(PyTypeObject *)O(type_handle); Iterator *self=(Iterator *)type->tp_alloc(type,0); if(!self) return 0;
    jac_retain(state); self->native=state; self->kind=TEE_DATA; return H(self);
}
uint64_t jacpy_tee_cursor_wrap(uint64_t type_handle,void *state) {
    PyTypeObject *type=(PyTypeObject *)O(type_handle); Iterator *self=(Iterator *)type->tp_alloc(type,0); if(!self) return 0;
    jac_retain(state); self->native=state; self->kind=TEE; return H(self);
}
void *jacpy_tee_block_state(uint64_t handle) { void *state=((Iterator *)O(handle))->native; jac_retain(state); return state; }
void *jacpy_tee_cursor_state(uint64_t handle) { void *state=((Iterator *)O(handle))->native; jac_retain(state); return state; }
static PyObject *tee_new(PyTypeObject *type,PyObject *args,PyObject *kw) {
    PyObject *iterable; Module *m=module_for(type); if(!m) return NULL;
    if(!no_keywords(type,TEE,kw) || !PyArg_UnpackTuple(args,"_tee",1,1,&iterable)) return NULL;
    return O(jacpy_tee_construct(H(type),H(m->types[TEE_DATA]),H(iterable)));
}
static PyObject *data_new(PyTypeObject *type,PyObject *args,PyObject *kw) {
    PyObject *iterable,*values,*next; Module *m=module_for(type); if(!m) return NULL;
    if(!no_keywords(type,TEE_DATA,kw) || !PyArg_ParseTuple(args,"OO!O:_tee_dataobject",&iterable,&PyList_Type,&values,&next)) return NULL;
    if(next!=Py_None && (PyList_GET_SIZE(values)!=57 || Py_TYPE(next)!=(PyTypeObject *)m->types[TEE_DATA])) { PyErr_SetString(PyExc_ValueError,"Invalid arguments"); return NULL; }
    Iterator *self=(Iterator *)type->tp_alloc(type,0); if(!self) return NULL;
    self->kind=TEE_DATA; self->native=jacpy_tee_block_new();
    if(jacpy_tee_block_init(self->native,H(iterable),H(values),next==Py_None ? 0 : H(next))<0) { Py_DECREF(self); return NULL; } return (PyObject *)self;
}
static PyObject *tee_next(PyObject *op) { return O(jacpy_tee_next(((Iterator *)op)->native)); }
static PyObject *tee_copy(PyObject *op,PyObject *unused) { Module *m=module_for(Py_TYPE(op)); if(!m) return NULL; return O(jacpy_tee_construct(H(Py_TYPE(op)),H(m->types[TEE_DATA]),H(op))); }
static PyObject *tee_method(PyObject *op,PyObject *args) {
    PyObject *iterable; Py_ssize_t count=2;
    if(!PyArg_ParseTuple(args,"O|n:tee",&iterable,&count)) return NULL;
    if(count<0) { PyErr_SetString(PyExc_ValueError,"n must be >= 0"); return NULL; }
    Module *m=PyModule_GetState(op); return O(jacpy_tee_split(H(m->types[TEE]),H(m->types[TEE_DATA]),H(iterable),count));
}
static PyMemberDef tee_members[]={{"__weaklistoffset__",Py_T_PYSSIZET,offsetof(Iterator,weakrefs),Py_READONLY},{NULL}};
static PyMethodDef tee_methods[]={{"__copy__",tee_copy,METH_NOARGS,"Returns an independent iterator."},{NULL}};
static PyType_Slot tee_slots[]={
    {Py_tp_new,tee_new},{Py_tp_dealloc,tee_dealloc},{Py_tp_traverse,tee_traverse},{Py_tp_clear,tee_clear},
    {Py_tp_iter,PyObject_SelfIter},{Py_tp_iternext,tee_next},{Py_tp_methods,tee_methods},{Py_tp_members,tee_members},{0}};
static PyType_Slot data_slots[]={
    {Py_tp_new,data_new},{Py_tp_dealloc,data_dealloc},{Py_tp_traverse,data_traverse},{Py_tp_clear,data_clear},{0}};
static PyType_Spec tee_spec={"itertools._tee",sizeof(Iterator),0,Py_TPFLAGS_DEFAULT|Py_TPFLAGS_HAVE_GC|Py_TPFLAGS_IMMUTABLETYPE,tee_slots};
static PyType_Spec data_spec={"itertools._tee_dataobject",sizeof(Iterator),0,Py_TPFLAGS_DEFAULT|Py_TPFLAGS_HAVE_GC|Py_TPFLAGS_IMMUTABLETYPE,data_slots};
static PyMethodDef module_methods[]={{"tee",tee_method,METH_VARARGS,"tee($module, iterable, n=2, /)\n--\n\nReturn n independent iterators."},{NULL}};
static const char *names[]={"accumulate","batched","chain","compress","count","cycle","dropwhile","filterfalse","islice","pairwise","repeat","starmap","takewhile","zip_longest","product","combinations","combinations_with_replacement","permutations","groupby"};
static const char *docs[]={
    "accumulate(iterable, func=None, *, initial=None)\n--\n\nReturn series of accumulated sums.",
    "batched(iterable, n, *, strict=False)\n--\n\nBatch data into tuples of length n.",
    "chain(*iterables)\n--\n\nReturn elements from successive iterables.",
    "compress(data, selectors)\n--\n\nReturn data whose corresponding selector is true.",
    "count(start=0, step=1)\n--\n\nReturn evenly spaced values starting with start.",
    "cycle(iterable, /)\n--\n\nReturn elements from the iterable, repeating indefinitely.",
    "dropwhile(predicate, iterable, /)\n--\n\nDrop elements while the predicate is true.",
    "filterfalse(function, iterable, /)\n--\n\nReturn items for which the predicate is false.",
    "islice(iterable, stop)\n--\n\nReturn selected elements from an iterable.",
    "pairwise(iterable, /)\n--\n\nReturn overlapping pairs from the input iterator.",
    "repeat(object, times=None)\n--\n\nReturn object repeatedly.",
    "starmap(function, iterable, /)\n--\n\nCall a function with arguments from each iterable element.",
    "takewhile(predicate, iterable, /)\n--\n\nReturn elements while the predicate is true.",
    "zip_longest(*iterables, fillvalue=None)\n--\n\nZip iterables, filling missing values.",
    "product(*iterables, repeat=1)\n--\n\nCartesian product of input iterables.",
    "combinations(iterable, r)\n--\n\nReturn length r subsequences of elements.",
    "combinations_with_replacement(iterable, r)\n--\n\nReturn length r subsequences, allowing repeated elements.",
    "permutations(iterable, r=None)\n--\n\nReturn successive length r permutations.",
    "groupby(iterable, key=None)\n--\n\nReturn consecutive keys and groups from the iterable."};
static int module_traverse(PyObject *op,visitproc visit,void *arg) { Module *m=PyModule_GetState(op); for(int i=0;i<TYPE_COUNT;i++) Py_VISIT(m->types[i]); return 0; }
static int module_clear(PyObject *op) { Module *m=PyModule_GetState(op); for(int i=0;i<TYPE_COUNT;i++) Py_CLEAR(m->types[i]); return 0; }
static int module_exec(PyObject *op) {
    Module *m=PyModule_GetState(op);
    m->types[TEE]=PyType_FromModuleAndSpec(op,&tee_spec,NULL); if(!m->types[TEE]) return -1;
    m->types[TEE_DATA]=PyType_FromModuleAndSpec(op,&data_spec,NULL); if(!m->types[TEE_DATA]) return -1;
    if(PyModule_AddObjectRef(op,"_tee",m->types[TEE])<0 || PyModule_AddObjectRef(op,"_tee_dataobject",m->types[TEE_DATA])<0) return -1;
    m->types[GROUPER]=PyType_FromModuleAndSpec(op,&grouper_spec,NULL); if(!m->types[GROUPER]) return -1;
    if(PyModule_AddObjectRef(op,"_grouper",m->types[GROUPER])<0) return -1;
    for(int i=0;i<19;i++) {
        char name[80]; PyOS_snprintf(name,sizeof(name),"itertools.%s",names[i]);
        PyType_Slot slots[]={
            {Py_tp_new,iterator_new},{Py_tp_dealloc,iterator_dealloc},{Py_tp_traverse,iterator_traverse},
            {Py_tp_clear,iterator_clear},{Py_tp_iter,PyObject_SelfIter},{Py_tp_iternext,iterator_next},
            {Py_tp_doc,(void *)docs[i]},{0},{0},{0}};
        int slot=7;
        if(i==COUNT || i==REPEAT) slots[slot++]=(PyType_Slot){Py_tp_repr,iterator_repr};
        if(i>=PRODUCT && i<=PERMUTATIONS) slots[slot++]=(PyType_Slot){Py_tp_methods,combinatorial_methods};
        if(i==CHAIN) slots[slot++]=(PyType_Slot){Py_tp_methods,chain_methods};
        if(i==REPEAT) slots[slot++]=(PyType_Slot){Py_tp_methods,repeat_methods};
        PyType_Spec spec={name,sizeof(Iterator),0,Py_TPFLAGS_DEFAULT|Py_TPFLAGS_HAVE_GC|Py_TPFLAGS_BASETYPE|Py_TPFLAGS_IMMUTABLETYPE,slots};
        m->types[i]=PyType_FromModuleAndSpec(op,&spec,NULL); if(!m->types[i]) return -1;
        if(PyModule_AddObjectRef(op,names[i],m->types[i])<0) return -1;
    }
    return 0;
}
static PyModuleDef_Slot module_slots[]={{Py_mod_exec,module_exec},{Py_mod_multiple_interpreters,Py_MOD_PER_INTERPRETER_GIL_SUPPORTED},{0}};
static PyModuleDef definition={PyModuleDef_HEAD_INIT,"itertools","Native Jac iterator policies.",sizeof(Module),module_methods,module_slots,module_traverse,module_clear,NULL};
PyMODINIT_FUNC PyInit_itertools(void) { return PyModuleDef_Init(&definition); }
