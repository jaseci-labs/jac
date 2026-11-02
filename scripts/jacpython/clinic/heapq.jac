"""The Argument Clinic signatures of _heapq.

scripts/jacpython/gen_clinic.jac generates
jaclang/runtime/python/bindings/clinic/heapq.jac from them. Taken from
CPython 3.14.6 Modules/_heapqmodule.c.
"""
import from clinic_schema { Clinic, Function, Parameter }

glob CLINIC: Clinic = Clinic(
         module="_heapq",
         version="3.14.6",
         sources=["Modules/_heapqmodule.c"],
         functions=[
             Function(
                 name="heappush",
                 full_name="_heapq.heappush",
                 c_basename="_heapq_heappush",
                 docstring="heappush($module, heap, item, /)\n"
                 "--\n"
                 "\n"
                 "Push item onto heap, maintaining the heap invariant.",
                 params=[
                     Parameter(
                         name="module",
                         kind="POSITIONAL_ONLY",
                         converter="self",
                         type=""
                     ),
                     Parameter(
                         name="heap",
                         kind="POSITIONAL_ONLY",
                         format_unit="O!",
                         subclass_of="&PyList_Type"
                     ),
                     Parameter(name="item", kind="POSITIONAL_ONLY", format_unit="O")
                 ],
                 flags="METH_FASTCALL",
                 parser="PARSE_POSITIONAL",
                 min_pos=2,
                 max_pos=2,
                 pos_only=2
             ),
             Function(
                 name="heappop",
                 full_name="_heapq.heappop",
                 c_basename="_heapq_heappop",
                 docstring="heappop($module, heap, /)\n"
                 "--\n"
                 "\n"
                 "Pop the smallest item off the heap, maintaining the heap invariant.",
                 params=[
                     Parameter(
                         name="module",
                         kind="POSITIONAL_ONLY",
                         converter="self",
                         type=""
                     ),
                     Parameter(
                         name="heap",
                         kind="POSITIONAL_ONLY",
                         format_unit="O!",
                         subclass_of="&PyList_Type"
                     )
                 ],
                 flags="METH_O",
                 parser="PARSE_GIVEN",
                 min_pos=1,
                 max_pos=1,
                 pos_only=1
             ),
             Function(
                 name="heapreplace",
                 full_name="_heapq.heapreplace",
                 c_basename="_heapq_heapreplace",
                 docstring="heapreplace($module, heap, item, /)\n"
                 "--\n"
                 "\n"
                 "Pop and return the current smallest value, and add the new item.\n"
                 "\n"
                 "This is more efficient than heappop() followed by heappush(), and can be\n"
                 "more appropriate when using a fixed-size heap.  Note that the value\n"
                 "returned may be larger than item!  That constrains reasonable uses of\n"
                 "this routine unless written as part of a conditional replacement:\n"
                 "\n"
                 "    if item > heap[0]:\n"
                 "        item = heapreplace(heap, item)",
                 params=[
                     Parameter(
                         name="module",
                         kind="POSITIONAL_ONLY",
                         converter="self",
                         type=""
                     ),
                     Parameter(
                         name="heap",
                         kind="POSITIONAL_ONLY",
                         format_unit="O!",
                         subclass_of="&PyList_Type"
                     ),
                     Parameter(name="item", kind="POSITIONAL_ONLY", format_unit="O")
                 ],
                 flags="METH_FASTCALL",
                 parser="PARSE_POSITIONAL",
                 min_pos=2,
                 max_pos=2,
                 pos_only=2
             ),
             Function(
                 name="heappushpop",
                 full_name="_heapq.heappushpop",
                 c_basename="_heapq_heappushpop",
                 docstring="heappushpop($module, heap, item, /)\n"
                 "--\n"
                 "\n"
                 "Push item on the heap, then pop and return the smallest item from the heap.\n"
                 "\n"
                 "The combined action runs more efficiently than heappush() followed by\n"
                 "a separate call to heappop().",
                 params=[
                     Parameter(
                         name="module",
                         kind="POSITIONAL_ONLY",
                         converter="self",
                         type=""
                     ),
                     Parameter(
                         name="heap",
                         kind="POSITIONAL_ONLY",
                         format_unit="O!",
                         subclass_of="&PyList_Type"
                     ),
                     Parameter(name="item", kind="POSITIONAL_ONLY", format_unit="O")
                 ],
                 flags="METH_FASTCALL",
                 parser="PARSE_POSITIONAL",
                 min_pos=2,
                 max_pos=2,
                 pos_only=2
             ),
             Function(
                 name="heapify",
                 full_name="_heapq.heapify",
                 c_basename="_heapq_heapify",
                 docstring="heapify($module, heap, /)\n"
                 "--\n"
                 "\n"
                 "Transform list into a heap, in-place, in O(len(heap)) time.",
                 params=[
                     Parameter(
                         name="module",
                         kind="POSITIONAL_ONLY",
                         converter="self",
                         type=""
                     ),
                     Parameter(
                         name="heap",
                         kind="POSITIONAL_ONLY",
                         format_unit="O!",
                         subclass_of="&PyList_Type"
                     )
                 ],
                 flags="METH_O",
                 parser="PARSE_GIVEN",
                 min_pos=1,
                 max_pos=1,
                 pos_only=1
             ),
             Function(
                 name="heappush_max",
                 full_name="_heapq.heappush_max",
                 c_basename="_heapq_heappush_max",
                 docstring="heappush_max($module, heap, item, /)\n"
                 "--\n"
                 "\n"
                 "Push item onto max heap, maintaining the heap invariant.",
                 params=[
                     Parameter(
                         name="module",
                         kind="POSITIONAL_ONLY",
                         converter="self",
                         type=""
                     ),
                     Parameter(
                         name="heap",
                         kind="POSITIONAL_ONLY",
                         format_unit="O!",
                         subclass_of="&PyList_Type"
                     ),
                     Parameter(name="item", kind="POSITIONAL_ONLY", format_unit="O")
                 ],
                 flags="METH_FASTCALL",
                 parser="PARSE_POSITIONAL",
                 min_pos=2,
                 max_pos=2,
                 pos_only=2
             ),
             Function(
                 name="heappop_max",
                 full_name="_heapq.heappop_max",
                 c_basename="_heapq_heappop_max",
                 docstring="heappop_max($module, heap, /)\n"
                 "--\n"
                 "\n"
                 "Maxheap variant of heappop.",
                 params=[
                     Parameter(
                         name="module",
                         kind="POSITIONAL_ONLY",
                         converter="self",
                         type=""
                     ),
                     Parameter(
                         name="heap",
                         kind="POSITIONAL_ONLY",
                         format_unit="O!",
                         subclass_of="&PyList_Type"
                     )
                 ],
                 flags="METH_O",
                 parser="PARSE_GIVEN",
                 min_pos=1,
                 max_pos=1,
                 pos_only=1
             ),
             Function(
                 name="heapreplace_max",
                 full_name="_heapq.heapreplace_max",
                 c_basename="_heapq_heapreplace_max",
                 docstring="heapreplace_max($module, heap, item, /)\n"
                 "--\n"
                 "\n"
                 "Maxheap variant of heapreplace.",
                 params=[
                     Parameter(
                         name="module",
                         kind="POSITIONAL_ONLY",
                         converter="self",
                         type=""
                     ),
                     Parameter(
                         name="heap",
                         kind="POSITIONAL_ONLY",
                         format_unit="O!",
                         subclass_of="&PyList_Type"
                     ),
                     Parameter(name="item", kind="POSITIONAL_ONLY", format_unit="O")
                 ],
                 flags="METH_FASTCALL",
                 parser="PARSE_POSITIONAL",
                 min_pos=2,
                 max_pos=2,
                 pos_only=2
             ),
             Function(
                 name="heapify_max",
                 full_name="_heapq.heapify_max",
                 c_basename="_heapq_heapify_max",
                 docstring="heapify_max($module, heap, /)\n"
                 "--\n"
                 "\n"
                 "Maxheap variant of heapify.",
                 params=[
                     Parameter(
                         name="module",
                         kind="POSITIONAL_ONLY",
                         converter="self",
                         type=""
                     ),
                     Parameter(
                         name="heap",
                         kind="POSITIONAL_ONLY",
                         format_unit="O!",
                         subclass_of="&PyList_Type"
                     )
                 ],
                 flags="METH_O",
                 parser="PARSE_GIVEN",
                 min_pos=1,
                 max_pos=1,
                 pos_only=1
             ),
             Function(
                 name="heappushpop_max",
                 full_name="_heapq.heappushpop_max",
                 c_basename="_heapq_heappushpop_max",
                 docstring="heappushpop_max($module, heap, item, /)\n"
                 "--\n"
                 "\n"
                 "Maxheap variant of heappushpop.\n"
                 "\n"
                 "The combined action runs more efficiently than heappush_max()\n"
                 "followed by a separate call to heappop_max().",
                 params=[
                     Parameter(
                         name="module",
                         kind="POSITIONAL_ONLY",
                         converter="self",
                         type=""
                     ),
                     Parameter(
                         name="heap",
                         kind="POSITIONAL_ONLY",
                         format_unit="O!",
                         subclass_of="&PyList_Type"
                     ),
                     Parameter(name="item", kind="POSITIONAL_ONLY", format_unit="O")
                 ],
                 flags="METH_FASTCALL",
                 parser="PARSE_POSITIONAL",
                 min_pos=2,
                 max_pos=2,
                 pos_only=2
             )
         ],
         docs={
             "module_doc": "Heap queue algorithm (a.k.a. priority queue).\n"
             "\n"
             "Heaps are arrays for which a[k] <= a[2*k+1] and a[k] <= a[2*k+2] for\n"
             "all k, counting elements from 0.  For the sake of comparison,\n"
             "non-existing elements are considered to be infinite.  The interesting\n"
             "property of a heap is that a[0] is always its smallest element.\n"
             "\n"
             "Usage:\n"
             "\n"
             "heap = []            # creates an empty heap\n"
             "heappush(heap, item) # pushes a new item on the heap\n"
             "item = heappop(heap) # pops the smallest item from the heap\n"
             "item = heap[0]       # smallest item on the heap without popping it\n"
             "heapify(x)           # transforms list into a heap, in-place, in linear time\n"
             "item = heapreplace(heap, item) # pops and returns smallest item, and adds\n"
             "                               # new item; the heap size is unchanged\n"
             "\n"
             "Our API differs from textbook heap algorithms as follows:\n"
             "\n"
             "- We use 0-based indexing.  This makes the relationship between the\n"
             "  index for a node and the indexes for its children slightly less\n"
             "  obvious, but is more suitable since Python uses 0-based indexing.\n"
             "\n"
             "- Our heappop() method returns the smallest item, not the largest.\n"
             "\n"
             "These two make it possible to view the heap as a regular Python list\n"
             "without surprises: heap[0] is the smallest item, and heap.sort()\n"
             "maintains the heap invariant!\n",
             "__about__": "Heap queues\n"
             "\n"
             "[explanation by François Pinard]\n"
             "\n"
             "Heaps are arrays for which a[k] <= a[2*k+1] and a[k] <= a[2*k+2] for\n"
             "all k, counting elements from 0.  For the sake of comparison,\n"
             "non-existing elements are considered to be infinite.  The interesting\n"
             "property of a heap is that a[0] is always its smallest element.\n"
             "\n"
             "The strange invariant above is meant to be an efficient memory\n"
             "representation for a tournament.  The numbers below are 'k', not a[k]:\n"
             "\n"
             "                                   0\n"
             "\n"
             "                  1                                 2\n"
             "\n"
             "          3               4                5               6\n"
             "\n"
             "      7       8       9       10      11      12      13      14\n"
             "\n"
             "    15 16   17 18   19 20   21 22   23 24   25 26   27 28   29 30\n"
             "\n"
             "\n"
             "In the tree above, each cell 'k' is topping '2*k+1' and '2*k+2'.  In\n"
             "a usual binary tournament we see in sports, each cell is the winner\n"
             "over the two cells it tops, and we can trace the winner down the tree\n"
             "to see all opponents s/he had.  However, in many computer applications\n"
             "of such tournaments, we do not need to trace the history of a winner.\n"
             "To be more memory efficient, when a winner is promoted, we try to\n"
             "replace it by something else at a lower level, and the rule becomes\n"
             "that a cell and the two cells it tops contain three different items,\n"
             "but the top cell \"wins\" over the two topped cells.\n"
             "\n"
             "If this heap invariant is protected at all time, index 0 is clearly\n"
             "the overall winner.  The simplest algorithmic way to remove it and\n"
             "find the \"next\" winner is to move some loser (let's say cell 30 in the\n"
             "diagram above) into the 0 position, and then percolate this new 0 down\n"
             "the tree, exchanging values, until the invariant is re-established.\n"
             "This is clearly logarithmic on the total number of items in the tree.\n"
             "By iterating over all items, you get an O(n ln n) sort.\n"
             "\n"
             "A nice feature of this sort is that you can efficiently insert new\n"
             "items while the sort is going on, provided that the inserted items are\n"
             "not \"better\" than the last 0'th element you extracted.  This is\n"
             "especially useful in simulation contexts, where the tree holds all\n"
             "incoming events, and the \"win\" condition means the smallest scheduled\n"
             "time.  When an event schedule other events for execution, they are\n"
             "scheduled into the future, so they can easily go into the heap.  So, a\n"
             "heap is a good structure for implementing schedulers (this is what I\n"
             "used for my MIDI sequencer :-).\n"
             "\n"
             "Various structures for implementing schedulers have been extensively\n"
             "studied, and heaps are good for this, as they are reasonably speedy,\n"
             "the speed is almost constant, and the worst case is not much different\n"
             "than the average case.  However, there are other representations which\n"
             "are more efficient overall, yet the worst cases might be terrible.\n"
             "\n"
             "Heaps are also very useful in big disk sorts.  You most probably all\n"
             "know that a big sort implies producing \"runs\" (which are pre-sorted\n"
             "sequences, which size is usually related to the amount of CPU memory),\n"
             "followed by a merging passes for these runs, which merging is often\n"
             "very cleverly organised[1].  It is very important that the initial\n"
             "sort produces the longest runs possible.  Tournaments are a good way\n"
             "to that.  If, using all the memory available to hold a tournament, you\n"
             "replace and percolate items that happen to fit the current run, you'll\n"
             "produce runs which are twice the size of the memory for random input,\n"
             "and much better for input fuzzily ordered.\n"
             "\n"
             "Moreover, if you output the 0'th item on disk and get an input which\n"
             "may not fit in the current tournament (because the value \"wins\" over\n"
             "the last output value), it cannot fit in the heap, so the size of the\n"
             "heap decreases.  The freed memory could be cleverly reused immediately\n"
             "for progressively building a second heap, which grows at exactly the\n"
             "same rate the first heap is melting.  When the first heap completely\n"
             "vanishes, you switch heaps and start a new run.  Clever and quite\n"
             "effective!\n"
             "\n"
             "In a word, heaps are useful memory structures to know.  I use them in\n"
             "a few applications, and I think it is good to keep a 'heap' module\n"
             "around. :-)\n"
             "\n"
             "--------------------\n"
             "[1] The disk balancing algorithms which are current, nowadays, are\n"
             "more annoying than clever, and this is a consequence of the seeking\n"
             "capabilities of the disks.  On devices which cannot seek, like big\n"
             "tape drives, the story was quite different, and one had to be very\n"
             "clever to ensure (far in advance) that each tape movement will be the\n"
             "most effective possible (that is, will best participate at\n"
             "\"progressing\" the merge).  Some tapes were even able to read\n"
             "backwards, and this was also used to avoid the rewinding time.\n"
             "Believe me, real good tape sorts were quite spectacular to watch!\n"
             "From all times, sorting has always been a Great Art! :-)\n"
         }
     );
