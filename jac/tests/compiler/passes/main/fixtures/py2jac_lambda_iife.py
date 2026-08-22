"""Fixture for immediately-invoked lambda expressions."""

def iife():
    return (lambda x: x + 1)(10)

def tap(f, x):
    return f(x)

def nested_lambda_call():
    assert tap(lambda x: x + 1, (lambda x: x + 1)(10)) == 11
