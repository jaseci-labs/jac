#!/bin/bash
MAPPING=JACPIMSTEP TEST_NAME=CONNECTED_COMP OVERHEAD_ONLY=0 jac run jac/jaclang/tests/jacpim/connected_component.jac
MAPPING=RANDOM TEST_NAME=CONNECTED_COMP OVERHEAD_ONLY=0 jac run jac/jaclang/tests/jacpim/connected_component.jac
MAPPING=JACPIMSTEP TEST_NAME=CONNECTED_COMP OVERHEAD_ONLY=1 jac run jac/jaclang/tests/jacpim/connected_component.jac
MAPPING=RANDOM TEST_NAME=CONNECTED_COMP OVERHEAD_ONLY=1 jac run jac/jaclang/tests/jacpim/connected_component.jac

# MAPPING=JACPIM TEST_NAME=PAGERANK OVERHEAD_ONLY=0 jac run jac/jaclang/tests/jacpim/pagerank.jac
# MAPPING=RANDOM TEST_NAME=PAGERANK OVERHEAD_ONLY=0 jac run jac/jaclang/tests/jacpim/pagerank.jac
# MAPPING=JACPIM TEST_NAME=PAGERANK OVERHEAD_ONLY=1 jac run jac/jaclang/tests/jacpim/pagerank.jac
# MAPPING=RANDOM TEST_NAME=PAGERANK OVERHEAD_ONLY=1 jac run jac/jaclang/tests/jacpim/pagerank.jac

MAPPING=JACPIMSTEP TEST_NAME=LITTLEX OVERHEAD_ONLY=0 jac run jac/jaclang/tests/jacpim/littlex2.jac
MAPPING=RANDOM TEST_NAME=LITTLEX OVERHEAD_ONLY=0 jac run jac/jaclang/tests/jacpim/littlex2.jac
MAPPING=JACPIMSTEP TEST_NAME=LITTLEX OVERHEAD_ONLY=1 jac run jac/jaclang/tests/jacpim/littlex2.jac
MAPPING=RANDOM TEST_NAME=LITTLEX OVERHEAD_ONLY=1 jac run jac/jaclang/tests/jacpim/littlex2.jac

MAPPING=JACPIMSTEP TEST_NAME=BS OVERHEAD_ONLY=0 jac run jac/jaclang/tests/jacpim/bs.jac
MAPPING=RANDOM TEST_NAME=BS OVERHEAD_ONLY=0 jac run jac/jaclang/tests/jacpim/bs.jac
MAPPING=JACPIMSTEP TEST_NAME=BS OVERHEAD_ONLY=1 jac run jac/jaclang/tests/jacpim/bs.jac
MAPPING=RANDOM TEST_NAME=BS OVERHEAD_ONLY=1 jac run jac/jaclang/tests/jacpim/bs.jac


# MAPPING=JACPIM TEST_NAME=BFS OVERHEAD_ONLY=0 jac run jac/jaclang/tests/jacpim/bfs.jac
# MAPPING=RANDOM TEST_NAME=BFS OVERHEAD_ONLY=0 jac run jac/jaclang/tests/jacpim/bfs.jac
# MAPPING=JACPIM TEST_NAME=BFS OVERHEAD_ONLY=1 jac run jac/jaclang/tests/jacpim/bfs.jac
# MAPPING=RANDOM TEST_NAME=BFS OVERHEAD_ONLY=1 jac run jac/jaclang/tests/jacpim/bfs.jac