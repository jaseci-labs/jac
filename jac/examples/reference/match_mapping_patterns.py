from __future__ import annotations
from jaclang.runtimelib.builtin import *
data = {'key1': 1, 'key2': 2, 'key3': 3}
match data:
    case {'key1': 1, 'key2': 2, **rest}:
        print(f'Matched mapping with key1 and key2. Rest: {rest}')
user = {'id': 1, 'name': 'Bob', 'email': 'bob@test.com', 'active': True}
match user:
    case {'id': 1, 'name': 'Bob', **extra}:
        print(f'Matched user. Extra: {extra}')
status = {'code': 200, 'message': 'OK'}
match status:
    case {'code': 200, 'message': 'OK'}:
        print('Success status')
    case _:
        print('Other status')
config = {'host': 'localhost', 'port': 8080, 'debug': True}
match config:
    case {'host': 'localhost', 'port': 8080, **rest}:
        print(f'Localhost config. Rest: {rest}')
