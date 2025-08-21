


def foo(type= 90):
    """This is a function with a docstring."""
    return type

print(foo(type=89))

def bar(node= 12, *args,**kwargs):
    """This is another function with a docstring."""
    return node, args, kwargs

print(str(bar(node=13, a=1, b=2)))


functions = [

        dict(   
            name="replace_lines",
            args=[
                dict(name="text", type="str", default=None),
                dict(name="old", type="str", default=None),
                dict(name="new", type="str", default=None),
            ],
            returns=dict(type="str", default=None),
        ),
]

print(f"Functions: {functions}")

dict = 90
print(f"Dict: {dict}")
