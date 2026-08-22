"""A module-scope static call into the Python-side merge module.

A module-scope call has no owning callable to absorb the violation, so the
refusal stays module-fatal -- the same landing #8206's partition gives the
module-scope free-function crossing.
"""
import from xmod_static_pybase_merge { Merger }
import from xmod_static_types { Item }


with entry {
    print(Merger.merge(Item(value=3), Item(value=4)));
}
