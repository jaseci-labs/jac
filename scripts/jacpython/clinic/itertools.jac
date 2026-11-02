"""The Argument Clinic signatures of itertools.

scripts/jacpython/gen_clinic.jac generates
jaclang/runtime/python/bindings/clinic/itertools.jac from them. Taken from
CPython 3.14.6 Modules/itertoolsmodule.c.
"""
import from clinic_schema { Clinic, Function, Parameter }

glob CLINIC: Clinic = Clinic(
         module="itertools",
         version="3.14.6",
         sources=["Modules/itertoolsmodule.c"],
         classes={
             "groupby": "groupbyobject *",
             "_grouper": "_grouperobject *",
             "teedataobject": "teedataobject *",
             "_tee": "teeobject *",
             "batched": "batchedobject *",
             "cycle": "cycleobject *",
             "dropwhile": "dropwhileobject *",
             "takewhile": "takewhileobject *",
             "starmap": "starmapobject *",
             "chain": "chainobject *",
             "combinations": "combinationsobject *",
             "combinations_with_replacement": "cwr_object *",
             "permutations": "permutationsobject *",
             "accumulate": "accumulateobject *",
             "compress": "compressobject *",
             "filterfalse": "filterfalseobject *",
             "count": "countobject *",
             "pairwise": "pairwiseobject *"
         },
         functions=[
             Function(
                 name="tee",
                 full_name="itertools.tee",
                 c_basename="itertools_tee",
                 docstring="tee($module, iterable, n=2, /)\n"
                 "--\n"
                 "\n"
                 "Returns a tuple of n independent iterators.",
                 params=[
                     Parameter(
                         name="module",
                         kind="POSITIONAL_ONLY",
                         converter="self",
                         type=""
                     ),
                     Parameter(
                         name="iterable", kind="POSITIONAL_ONLY", format_unit="O"
                     ),
                     Parameter(
                         name="n",
                         kind="POSITIONAL_ONLY",
                         converter="Py_ssize_t",
                         type="Py_ssize_t",
                         format_unit="n",
                         default_kind="value",
                         py_default=2,
                         c_default="2"
                     )
                 ],
                 flags="METH_FASTCALL",
                 parser="PARSE_POSITIONAL",
                 min_pos=1,
                 max_pos=2,
                 pos_only=2
             ),
             Function(
                 name="__new__",
                 full_name="itertools.groupby.__new__",
                 c_basename="itertools_groupby",
                 kind="METHOD_NEW",
                 cls="groupby",
                 docstring="groupby(iterable, key=None)\n"
                 "--\n"
                 "\n"
                 "make an iterator that returns consecutive keys and groups from the iterable\n"
                 "\n"
                 "  iterable\n"
                 "    Elements to divide into groups according to the key function.\n"
                 "  key\n"
                 "    A function for computing the group category for each element.\n"
                 "    If the key function is not specified or is None, the element itself\n"
                 "    is used for grouping.",
                 params=[
                     Parameter(
                         name="type", kind="POSITIONAL_ONLY", converter="self", type=""
                     ),
                     Parameter(name="iterable", format_unit="O"),
                     Parameter(
                         name="key",
                         format_unit="O",
                         default_kind="value",
                         c_default="Py_None"
                     )
                 ],
                 flags="METH_VARARGS|METH_KEYWORDS",
                 parser="PARSE_KEYWORDS",
                 min_pos=1,
                 max_pos=2
             ),
             Function(
                 name="__new__",
                 full_name="itertools._grouper.__new__",
                 c_basename="itertools__grouper",
                 kind="METHOD_NEW",
                 cls="_grouper",
                 params=[
                     Parameter(
                         name="type", kind="POSITIONAL_ONLY", converter="self", type=""
                     ),
                     Parameter(
                         name="parent",
                         kind="POSITIONAL_ONLY",
                         format_unit="O!",
                         subclass_of="clinic_state_by_cls()->groupby_type"
                     ),
                     Parameter(name="tgtkey", kind="POSITIONAL_ONLY", format_unit="O")
                 ],
                 flags="METH_VARARGS",
                 parser="PARSE_POSITIONAL",
                 min_pos=2,
                 max_pos=2,
                 pos_only=2,
                 self_type_check=True
             ),
             Function(
                 name="__new__",
                 full_name="itertools.teedataobject.__new__",
                 c_basename="itertools_teedataobject",
                 kind="METHOD_NEW",
                 cls="teedataobject",
                 docstring="teedataobject(iterable, values, next, /)\n"
                 "--\n"
                 "\n"
                 "Data container common to multiple tee objects.",
                 params=[
                     Parameter(
                         name="type", kind="POSITIONAL_ONLY", converter="self", type=""
                     ),
                     Parameter(
                         name="iterable", kind="POSITIONAL_ONLY", format_unit="O"
                     ),
                     Parameter(
                         name="values",
                         kind="POSITIONAL_ONLY",
                         format_unit="O!",
                         subclass_of="&PyList_Type"
                     ),
                     Parameter(name="next", kind="POSITIONAL_ONLY", format_unit="O")
                 ],
                 flags="METH_VARARGS",
                 parser="PARSE_POSITIONAL",
                 min_pos=3,
                 max_pos=3,
                 pos_only=3,
                 self_type_check=True
             ),
             Function(
                 name="__new__",
                 full_name="itertools._tee.__new__",
                 c_basename="itertools__tee",
                 kind="METHOD_NEW",
                 cls="_tee",
                 docstring="_tee(iterable, /)\n"
                 "--\n"
                 "\n"
                 "Iterator wrapped to make it copyable.",
                 params=[
                     Parameter(
                         name="type", kind="POSITIONAL_ONLY", converter="self", type=""
                     ),
                     Parameter(name="iterable", kind="POSITIONAL_ONLY", format_unit="O")
                 ],
                 flags="METH_VARARGS",
                 parser="PARSE_POSITIONAL",
                 min_pos=1,
                 max_pos=1,
                 pos_only=1,
                 self_type_check=True
             ),
             Function(
                 name="__new__",
                 full_name="itertools.batched.__new__",
                 c_basename="batched_new",
                 kind="METHOD_NEW",
                 cls="batched",
                 docstring="batched(iterable, n, *, strict=False)\n"
                 "--\n"
                 "\n"
                 "Batch data into tuples of length n. The last batch may be shorter than n.\n"
                 "\n"
                 "Loops over the input iterable and accumulates data into tuples\n"
                 "up to size n.  The input is consumed lazily, just enough to\n"
                 "fill a batch.  The result is yielded as soon as a batch is full\n"
                 "or when the input iterable is exhausted.\n"
                 "\n"
                 "    >>> for batch in batched('ABCDEFG', 3):\n"
                 "    ...     print(batch)\n"
                 "    ...\n"
                 "    ('A', 'B', 'C')\n"
                 "    ('D', 'E', 'F')\n"
                 "    ('G',)\n"
                 "\n"
                 "If \"strict\" is True, raises a ValueError if the final batch is shorter\n"
                 "than n.",
                 params=[
                     Parameter(
                         name="type", kind="POSITIONAL_ONLY", converter="self", type=""
                     ),
                     Parameter(name="iterable", format_unit="O"),
                     Parameter(
                         name="n",
                         converter="Py_ssize_t",
                         type="Py_ssize_t",
                         format_unit="n"
                     ),
                     Parameter(
                         name="strict",
                         kind="KEYWORD_ONLY",
                         converter="bool",
                         type="int",
                         format_unit="p",
                         default_kind="value",
                         py_default=False,
                         c_default="0"
                     )
                 ],
                 flags="METH_VARARGS|METH_KEYWORDS",
                 parser="PARSE_KEYWORDS",
                 min_pos=2,
                 max_pos=2
             ),
             Function(
                 name="__new__",
                 full_name="itertools.cycle.__new__",
                 c_basename="itertools_cycle",
                 kind="METHOD_NEW",
                 cls="cycle",
                 docstring="cycle(iterable, /)\n"
                 "--\n"
                 "\n"
                 "Return elements from the iterable until it is exhausted. Then repeat the sequence indefinitely.",
                 params=[
                     Parameter(
                         name="type", kind="POSITIONAL_ONLY", converter="self", type=""
                     ),
                     Parameter(name="iterable", kind="POSITIONAL_ONLY", format_unit="O")
                 ],
                 flags="METH_VARARGS",
                 parser="PARSE_POSITIONAL",
                 min_pos=1,
                 max_pos=1,
                 pos_only=1,
                 self_type_check=True
             ),
             Function(
                 name="__new__",
                 full_name="itertools.dropwhile.__new__",
                 c_basename="itertools_dropwhile",
                 kind="METHOD_NEW",
                 cls="dropwhile",
                 docstring="dropwhile(predicate, iterable, /)\n"
                 "--\n"
                 "\n"
                 "Drop items from the iterable while predicate(item) is true.\n"
                 "\n"
                 "Afterwards, return every element until the iterable is exhausted.",
                 params=[
                     Parameter(
                         name="type", kind="POSITIONAL_ONLY", converter="self", type=""
                     ),
                     Parameter(
                         name="predicate", kind="POSITIONAL_ONLY", format_unit="O"
                     ),
                     Parameter(name="iterable", kind="POSITIONAL_ONLY", format_unit="O")
                 ],
                 flags="METH_VARARGS",
                 parser="PARSE_POSITIONAL",
                 min_pos=2,
                 max_pos=2,
                 pos_only=2,
                 self_type_check=True
             ),
             Function(
                 name="__new__",
                 full_name="itertools.takewhile.__new__",
                 c_basename="itertools_takewhile",
                 kind="METHOD_NEW",
                 cls="takewhile",
                 docstring="takewhile(predicate, iterable, /)\n"
                 "--\n"
                 "\n"
                 "Return successive entries from an iterable as long as the predicate evaluates to true for each entry.",
                 params=[
                     Parameter(
                         name="type", kind="POSITIONAL_ONLY", converter="self", type=""
                     ),
                     Parameter(
                         name="predicate", kind="POSITIONAL_ONLY", format_unit="O"
                     ),
                     Parameter(name="iterable", kind="POSITIONAL_ONLY", format_unit="O")
                 ],
                 flags="METH_VARARGS",
                 parser="PARSE_POSITIONAL",
                 min_pos=2,
                 max_pos=2,
                 pos_only=2,
                 self_type_check=True
             ),
             Function(
                 name="__new__",
                 full_name="itertools.starmap.__new__",
                 c_basename="itertools_starmap",
                 kind="METHOD_NEW",
                 cls="starmap",
                 docstring="starmap(function, iterable, /)\n"
                 "--\n"
                 "\n"
                 "Return an iterator whose values are returned from the function evaluated with an argument tuple taken from the given sequence.",
                 params=[
                     Parameter(
                         name="type", kind="POSITIONAL_ONLY", converter="self", type=""
                     ),
                     Parameter(
                         name="function", kind="POSITIONAL_ONLY", format_unit="O"
                     ),
                     Parameter(name="iterable", kind="POSITIONAL_ONLY", format_unit="O")
                 ],
                 flags="METH_VARARGS",
                 parser="PARSE_POSITIONAL",
                 min_pos=2,
                 max_pos=2,
                 pos_only=2,
                 self_type_check=True
             ),
             Function(
                 name="from_iterable",
                 full_name="itertools.chain.from_iterable",
                 c_basename="itertools_chain_from_iterable",
                 kind="CLASS_METHOD",
                 cls="chain",
                 docstring="from_iterable($type, iterable, /)\n"
                 "--\n"
                 "\n"
                 "Alternative chain() constructor taking a single iterable argument that evaluates lazily.",
                 params=[
                     Parameter(
                         name="type", kind="POSITIONAL_ONLY", converter="self", type=""
                     ),
                     Parameter(name="iterable", kind="POSITIONAL_ONLY", format_unit="O")
                 ],
                 flags="METH_O|METH_CLASS",
                 parser="PARSE_GIVEN",
                 min_pos=1,
                 max_pos=1,
                 pos_only=1
             ),
             Function(
                 name="__new__",
                 full_name="itertools.combinations.__new__",
                 c_basename="itertools_combinations",
                 kind="METHOD_NEW",
                 cls="combinations",
                 docstring="combinations(iterable, r)\n"
                 "--\n"
                 "\n"
                 "Return successive r-length combinations of elements in the iterable.\n"
                 "\n"
                 "combinations(range(4), 3) --> (0,1,2), (0,1,3), (0,2,3), (1,2,3)",
                 params=[
                     Parameter(
                         name="type", kind="POSITIONAL_ONLY", converter="self", type=""
                     ),
                     Parameter(name="iterable", format_unit="O"),
                     Parameter(
                         name="r",
                         converter="Py_ssize_t",
                         type="Py_ssize_t",
                         format_unit="n"
                     )
                 ],
                 flags="METH_VARARGS|METH_KEYWORDS",
                 parser="PARSE_KEYWORDS",
                 min_pos=2,
                 max_pos=2
             ),
             Function(
                 name="__new__",
                 full_name="itertools.combinations_with_replacement.__new__",
                 c_basename="itertools_combinations_with_replacement",
                 kind="METHOD_NEW",
                 cls="combinations_with_replacement",
                 docstring="combinations_with_replacement(iterable, r)\n"
                 "--\n"
                 "\n"
                 "Return successive r-length combinations of elements in the iterable allowing individual elements to have successive repeats.\n"
                 "\n"
                 "combinations_with_replacement('ABC', 2) --> ('A','A'), ('A','B'), ('A','C'), ('B','B'), ('B','C'), ('C','C')",
                 params=[
                     Parameter(
                         name="type", kind="POSITIONAL_ONLY", converter="self", type=""
                     ),
                     Parameter(name="iterable", format_unit="O"),
                     Parameter(
                         name="r",
                         converter="Py_ssize_t",
                         type="Py_ssize_t",
                         format_unit="n"
                     )
                 ],
                 flags="METH_VARARGS|METH_KEYWORDS",
                 parser="PARSE_KEYWORDS",
                 min_pos=2,
                 max_pos=2
             ),
             Function(
                 name="__new__",
                 full_name="itertools.permutations.__new__",
                 c_basename="itertools_permutations",
                 kind="METHOD_NEW",
                 cls="permutations",
                 docstring="permutations(iterable, r=None)\n"
                 "--\n"
                 "\n"
                 "Return successive r-length permutations of elements in the iterable.\n"
                 "\n"
                 "permutations(range(3), 2) --> (0,1), (0,2), (1,0), (1,2), (2,0), (2,1)",
                 params=[
                     Parameter(
                         name="type", kind="POSITIONAL_ONLY", converter="self", type=""
                     ),
                     Parameter(name="iterable", format_unit="O"),
                     Parameter(
                         name="r",
                         format_unit="O",
                         default_kind="value",
                         c_default="Py_None"
                     )
                 ],
                 flags="METH_VARARGS|METH_KEYWORDS",
                 parser="PARSE_KEYWORDS",
                 min_pos=1,
                 max_pos=2
             ),
             Function(
                 name="__new__",
                 full_name="itertools.accumulate.__new__",
                 c_basename="itertools_accumulate",
                 kind="METHOD_NEW",
                 cls="accumulate",
                 docstring="accumulate(iterable, func=None, *, initial=None)\n"
                 "--\n"
                 "\n"
                 "Return series of accumulated sums (or other binary function results).",
                 params=[
                     Parameter(
                         name="type", kind="POSITIONAL_ONLY", converter="self", type=""
                     ),
                     Parameter(name="iterable", format_unit="O"),
                     Parameter(
                         name="func",
                         format_unit="O",
                         default_kind="value",
                         c_default="Py_None"
                     ),
                     Parameter(
                         name="initial",
                         kind="KEYWORD_ONLY",
                         format_unit="O",
                         default_kind="value",
                         c_default="Py_None"
                     )
                 ],
                 flags="METH_VARARGS|METH_KEYWORDS",
                 parser="PARSE_KEYWORDS",
                 min_pos=1,
                 max_pos=2
             ),
             Function(
                 name="__new__",
                 full_name="itertools.compress.__new__",
                 c_basename="itertools_compress",
                 kind="METHOD_NEW",
                 cls="compress",
                 docstring="compress(data, selectors)\n"
                 "--\n"
                 "\n"
                 "Return data elements corresponding to true selector elements.\n"
                 "\n"
                 "Forms a shorter iterator from selected data elements using the selectors\n"
                 "to choose the data elements.",
                 params=[
                     Parameter(
                         name="type", kind="POSITIONAL_ONLY", converter="self", type=""
                     ),
                     Parameter(name="data", format_unit="O"),
                     Parameter(name="selectors", format_unit="O")
                 ],
                 flags="METH_VARARGS|METH_KEYWORDS",
                 parser="PARSE_KEYWORDS",
                 min_pos=2,
                 max_pos=2
             ),
             Function(
                 name="__new__",
                 full_name="itertools.filterfalse.__new__",
                 c_basename="itertools_filterfalse",
                 kind="METHOD_NEW",
                 cls="filterfalse",
                 docstring="filterfalse(function, iterable, /)\n"
                 "--\n"
                 "\n"
                 "Return those items of iterable for which function(item) is false.\n"
                 "\n"
                 "If function is None, return the items that are false.",
                 params=[
                     Parameter(
                         name="type", kind="POSITIONAL_ONLY", converter="self", type=""
                     ),
                     Parameter(
                         name="function", kind="POSITIONAL_ONLY", format_unit="O"
                     ),
                     Parameter(name="iterable", kind="POSITIONAL_ONLY", format_unit="O")
                 ],
                 flags="METH_VARARGS",
                 parser="PARSE_POSITIONAL",
                 min_pos=2,
                 max_pos=2,
                 pos_only=2,
                 self_type_check=True
             ),
             Function(
                 name="__new__",
                 full_name="itertools.count.__new__",
                 c_basename="itertools_count",
                 kind="METHOD_NEW",
                 cls="count",
                 docstring="count(start=0, step=1)\n"
                 "--\n"
                 "\n"
                 "Return a count object whose .__next__() method returns consecutive values.\n"
                 "\n"
                 "Equivalent to:\n"
                 "    def count(firstval=0, step=1):\n"
                 "        x = firstval\n"
                 "        while 1:\n"
                 "            yield x\n"
                 "            x += step",
                 params=[
                     Parameter(
                         name="type", kind="POSITIONAL_ONLY", converter="self", type=""
                     ),
                     Parameter(
                         name="start",
                         format_unit="O",
                         default_kind="value",
                         py_default=0,
                         c_default="NULL"
                     ),
                     Parameter(
                         name="step",
                         format_unit="O",
                         default_kind="value",
                         py_default=1,
                         c_default="NULL"
                     )
                 ],
                 flags="METH_VARARGS|METH_KEYWORDS",
                 parser="PARSE_KEYWORDS",
                 max_pos=2
             ),
             Function(
                 name="__new__",
                 full_name="itertools.pairwise.__new__",
                 c_basename="pairwise_new",
                 kind="METHOD_NEW",
                 cls="pairwise",
                 docstring="pairwise(iterable, /)\n"
                 "--\n"
                 "\n"
                 "Return an iterator of overlapping pairs taken from the input iterator.\n"
                 "\n"
                 "    s -> (s0,s1), (s1,s2), (s2, s3), ...",
                 params=[
                     Parameter(
                         name="type", kind="POSITIONAL_ONLY", converter="self", type=""
                     ),
                     Parameter(name="iterable", kind="POSITIONAL_ONLY", format_unit="O")
                 ],
                 flags="METH_VARARGS",
                 parser="PARSE_POSITIONAL",
                 min_pos=1,
                 max_pos=1,
                 pos_only=1,
                 self_type_check=True
             )
         ],
         docs={
             "teecopy_doc": "Returns an independent iterator.",
             "islice_doc": "islice(iterable, stop) --> islice object\n"
             "islice(iterable, start, stop[, step]) --> islice object\n"
             "\n"
             "Return an iterator whose next() method returns selected values from an\n"
             "iterable.  If start is specified, will skip all preceding elements;\n"
             "otherwise, start defaults to zero.  Step defaults to one.  If\n"
             "specified as another value, step determines how many values are\n"
             "skipped between successive calls.  Works like a slice() on a list\n"
             "but returns an iterator.",
             "chain_doc": "chain(*iterables)\n"
             "--\n"
             "\n"
             "Return a chain object whose .__next__() method returns elements from the\n"
             "first iterable until it is exhausted, then elements from the next\n"
             "iterable, until all of the iterables are exhausted.",
             "chain_class_getitem_doc": "chain is generic over the type of its contents.\n"
             "This is the union of the types of the input iterable contents.",
             "sizeof_doc": "Returns size in memory, in bytes.",
             "product_doc": "product(*iterables, repeat=1)\n"
             "--\n"
             "\n"
             "Cartesian product of input iterables.  Equivalent to nested for-loops.\n"
             "\n"
             "For example, product(A, B) returns the same as:  ((x,y) for x in A for y in B).\n"
             "The leftmost iterators are in the outermost for-loop, so the output tuples\n"
             "cycle in a manner similar to an odometer (with the rightmost element changing\n"
             "on every iteration).\n"
             "\n"
             "To compute the product of an iterable with itself, specify the number\n"
             "of repetitions with the optional repeat keyword argument. For example,\n"
             "product(A, repeat=4) means the same as product(A, A, A, A).\n"
             "\n"
             "product('ab', range(3)) --> ('a',0) ('a',1) ('a',2) ('b',0) ('b',1) ('b',2)\n"
             "product((0,1), (0,1), (0,1)) --> (0,0,0) (0,0,1) (0,1,0) (0,1,1) (1,0,0) ...",
             "length_hint_doc": "Private method returning an estimate of len(list(it)).",
             "repeat_doc": "repeat(object [,times]) -> create an iterator which returns the object\n"
             "for the specified number of times.  If not specified, returns the object\n"
             "endlessly.",
             "zip_longest_doc": "zip_longest(*iterables, fillvalue=None)\n"
             "--\n"
             "\n"
             "Return a zip_longest object whose .__next__() method returns a tuple where\n"
             "the i-th element comes from the i-th iterable argument.  The .__next__()\n"
             "method continues until the longest iterable in the argument sequence\n"
             "is exhausted and then it raises StopIteration.  When the shorter iterables\n"
             "are exhausted, the fillvalue is substituted in their place.  The fillvalue\n"
             "defaults to None or can be specified by a keyword argument.\n",
             "module_doc": "Functional tools for creating and using iterators.\n"
             "\n"
             "Infinite iterators:\n"
             "count(start=0, step=1) --> start, start+step, start+2*step, ...\n"
             "cycle(p) --> p0, p1, ... plast, p0, p1, ...\n"
             "repeat(elem [,n]) --> elem, elem, elem, ... endlessly or up to n times\n"
             "\n"
             "Iterators terminating on the shortest input sequence:\n"
             "accumulate(p[, func]) --> p0, p0+p1, p0+p1+p2\n"
             "batched(p, n) --> [p0, p1, ..., p_n-1], [p_n, p_n+1, ..., p_2n-1], ...\n"
             "chain(p, q, ...) --> p0, p1, ... plast, q0, q1, ...\n"
             "chain.from_iterable([p, q, ...]) --> p0, p1, ... plast, q0, q1, ...\n"
             "compress(data, selectors) --> (d[0] if s[0]), (d[1] if s[1]), ...\n"
             "dropwhile(predicate, seq) --> seq[n], seq[n+1], starting when predicate fails\n"
             "groupby(iterable[, keyfunc]) --> sub-iterators grouped by value of keyfunc(v)\n"
             "filterfalse(predicate, seq) --> elements of seq where predicate(elem) is False\n"
             "islice(seq, [start,] stop [, step]) --> elements from\n"
             "       seq[start:stop:step]\n"
             "pairwise(s) --> (s[0],s[1]), (s[1],s[2]), (s[2], s[3]), ...\n"
             "starmap(fun, seq) --> fun(*seq[0]), fun(*seq[1]), ...\n"
             "tee(it, n=2) --> (it1, it2 , ... itn) splits one iterator into n\n"
             "takewhile(predicate, seq) --> seq[0], seq[1], until predicate fails\n"
             "zip_longest(p, q, ...) --> (p[0], q[0]), (p[1], q[1]), ...\n"
             "\n"
             "Combinatoric generators:\n"
             "product(p, q, ... [repeat=1]) --> cartesian product\n"
             "permutations(p[, r])\n"
             "combinations(p, r)\n"
             "combinations_with_replacement(p, r)\n"
         }
     );
