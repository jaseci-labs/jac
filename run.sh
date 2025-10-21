#!/bin/bash
MAPPING=ROUND TEST_NAME=BS OVERHEAD_ONLY=0 jac run jac/jaclang/tests/jacpim/bs.jac
MAPPING=RANDOM TEST_NAME=BS OVERHEAD_ONLY=0 jac run jac/jaclang/tests/jacpim/bs.jac
MAPPING=ROUND TEST_NAME=BS OVERHEAD_ONLY=1 jac run jac/jaclang/tests/jacpim/bs.jac
MAPPING=RANDOM TEST_NAME=BS OVERHEAD_ONLY=1 jac run jac/jaclang/tests/jacpim/bs.jac