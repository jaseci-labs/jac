class Meta(type):
    pass


class Base:
    pass


class Foo(Base, metaclass=Meta):
    x = 1
