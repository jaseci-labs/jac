"""Semstrings: Semantic string definitions for LLM-guided functions."""
from __future__ import annotations
from jaclang.runtimelib.builtin import *
import byllm
from jaclang import JacMachineInterface as _jl
from byllm import Model
llm = Model(model_name='mockllm', outputs=['SecureP@ss1'])

@_jl.sem('\nPassword is at least 8 characters, has one uppercase letter, \none lowercase letter, one digit, and one special character.\n', {})
def generate_password() -> str:
    return _jl.call_llm(model=llm(), mtir=byllm.MTIR.factory(caller=generate_password, args={}, call_params=llm().call_params))
pwd = generate_password()
print(f'Generated: {pwd}')
