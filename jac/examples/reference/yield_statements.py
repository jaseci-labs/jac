def myFunc() -> None:
    yield "Hello"
    yield 91
    yield "Good Bye"
    yield


x = myFunc()

for z in x:
    print(z)
