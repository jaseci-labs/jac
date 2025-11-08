from __future__ import annotations
from jaclang.runtimelib.builtin import *
from jaclang import JacMachineInterface as _
from byllm import Model, MTIR
llm = Model(model_name='mockllm', outputs=['R8@jL3pQ'])

@_.sem('Generates and returns password that:\n- contain at least 8 characters\n- contain at least one uppercase letter\n- contain at least one lowercase letter\n- contain at least one digit\n- contain at least one special character\n', {})
def generate_password() -> str:
    return _.call_llm(model=llm(), mtir=MTIR.factory(caller=generate_password, args={}, call_params=llm.call_params))
password = generate_password()
print('Generated password:', password)