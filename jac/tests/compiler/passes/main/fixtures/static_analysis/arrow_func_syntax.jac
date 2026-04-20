"""Fixture: file containing JS arrow function syntax.

Used to verify that the synthesised Name node (value '=>') created by the
parse_atom ERROR guard does NOT trigger a W2001 'may be undefined' warning
when the static-analysis pass runs with type_check=True.
"""
glob f = x => x + 1;
