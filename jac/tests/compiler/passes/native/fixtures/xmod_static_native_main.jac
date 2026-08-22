"""The control's caller: the same static call, one Python base lighter.

This one must keep executing natively and answer what the Python lane
answers, so the refusal above is read as a diagnosis of the Python-side
crossing rather than of class-qualified calls in general.
"""
import from xmod_static_native_merge { Merger }
import from xmod_static_types { Item }


def run_merge -> int {
    return Merger.merge(Item(value=3), Item(value=4));
}
