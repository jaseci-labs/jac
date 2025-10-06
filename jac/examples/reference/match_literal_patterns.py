from __future__ import annotations
from jaclang.runtimelib.builtin import *
num = 89
match num:
    case 89:
        print('Matched integer 89')
    case 0:
        print('Matched zero')
    case 100:
        print('Matched 100')
pi = 3.14
match pi:
    case 3.14:
        print('Matched float 3.14')
    case 2.71:
        print('Matched e')
text = 'hello'
match text:
    case 'hello':
        print("Matched string 'hello'")
    case 'world':
        print("Matched string 'world'")
flag = True
match flag:
    case True:
        print('Matched boolean True')
    case False:
        print('Matched boolean False')
val = None
match val:
    case None:
        print('Matched None')
