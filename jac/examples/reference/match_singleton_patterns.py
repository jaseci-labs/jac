from __future__ import annotations
from jaclang.runtimelib.builtin import *
data = True
match data:
    case True:
        print('Matched the singleton True')
    case False:
        print('Matched the singleton False')
    case None:
        print('Matched the singleton None')
flag = False
match flag:
    case True:
        print('True')
    case False:
        print('Matched the singleton False')
    case None:
        print('None')
val = None
match val:
    case True:
        print('True')
    case False:
        print('False')
    case None:
        print('Matched the singleton None')
