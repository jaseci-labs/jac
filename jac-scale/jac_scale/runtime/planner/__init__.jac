"""Realization planning: the composition root.

One place reads the deployment dials and decides which adapter every port uses.
Keeping that decision here - and nowhere else - is what lets the rest of the
runtime depend only on ports: change a dial, the planner swaps adapters, no other
code branches on topology or environment.
"""
