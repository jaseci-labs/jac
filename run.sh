#!/bin/bash
# MAPPING=JACPIM TEST_NAME=PAGERANK OVERHEAD_ONLY=0 jac run jac/jaclang/tests/jacpim/pagerank.jac
# MAPPING=RANDOM TEST_NAME=PAGERANK OVERHEAD_ONLY=0 jac run jac/jaclang/tests/jacpim/pagerank.jac
# MAPPING=JACPIM TEST_NAME=PAGERANK OVERHEAD_ONLY=1 jac run jac/jaclang/tests/jacpim/pagerank.jac
# MAPPING=RANDOM TEST_NAME=PAGERANK OVERHEAD_ONLY=1 jac run jac/jaclang/tests/jacpim/pagerank.jac

MAPPING=JACPIM TEST_NAME=LITTLEX OVERHEAD_ONLY=0 jac run jac/jaclang/tests/jacpim/littlex2.jac
MAPPING=RANDOM TEST_NAME=LITTLEX OVERHEAD_ONLY=0 jac run jac/jaclang/tests/jacpim/littlex2.jac
MAPPING=JACPIM TEST_NAME=LITTLEX OVERHEAD_ONLY=1 jac run jac/jaclang/tests/jacpim/littlex2.jac
MAPPING=RANDOM TEST_NAME=LITTLEX OVERHEAD_ONLY=1 jac run jac/jaclang/tests/jacpim/littlex2.jac