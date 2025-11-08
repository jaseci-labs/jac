from __future__ import annotations
from jaclang.runtimelib.builtin import *
from jaclang import JacMachineInterface as _


def print_base_classes(cls: type) -> type:
    print(f"Base classes of {cls.__name__}: {[c.__name__ for c in cls.__bases__]}")
    return cls


class Animal:
    pass


class Domesticated(_.Obj):
    pass


@print_base_classes
class Pet(Animal, Domesticated, _.Node):
    pass


class Person(Animal, _.Walker):
    pass


class Feeder(Person, _.Walker):
    pass


@print_base_classes
class Zoologist(Feeder, _.Walker):
    pass


class MyWalker(_.Walker):
    __jac_async__ = True
    pass