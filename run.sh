#!/bin/bash
MAPPING=JACPIM TEST_NAME=BS OVERHEAD_ONLY=0 jac run jac/jaclang/tests/jacpim/bs.jac
MAPPING=RANDOM TEST_NAME=BS OVERHEAD_ONLY=0 jac run jac/jaclang/tests/jacpim/bs.jac
MAPPING=JACPIM TEST_NAME=BS OVERHEAD_ONLY=1 jac run jac/jaclang/tests/jacpim/bs.jac
MAPPING=RANDOM TEST_NAME=BS OVERHEAD_ONLY=1 jac run jac/jaclang/tests/jacpim/bs.jac