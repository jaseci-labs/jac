from __future__ import annotations
from jaclang.runtimelib.builtin import *
from jaclang import JacMachineInterface as _
import random

if _.TYPE_CHECKING:
    import random


class TestObj(_.Obj):
    x: int = random.randint(0, 15)
    y: int = random.randint(0, 15)
    z: int = random.randint(0, 15)


random.seed(42)
apple = []
i = 0
while i < 100:
    apple.append(TestObj())
    i += 1
print(_.filter(apple, lambda i: i.x >= 0 and i.x <= 15) == apple)


class MyObj(_.Obj):
    apple: int = 0
    banana: int = 0


x = MyObj()
y = MyObj()
mvar = _.assign([x, y], (("apple", "banana"), (5, 7)))
print(mvar)
