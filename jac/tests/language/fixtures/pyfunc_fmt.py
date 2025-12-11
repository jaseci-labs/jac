import contextlib

if __name__ == "__main__":

    def foo() -> str:
        print("One")
        return "foo"

    foo()

condition = True

if condition:
    print("Two")

    def bar():
        return

    main_mod = None
    bar()


def baz() -> str:
    print("Three")
    return "baz"


print(baz())


with contextlib.suppress(FileNotFoundError):
    a = 90


condition = 10


while condition:
    print("Processing...")

    while condition:
        print("Four")
        condition -= 10
        break

if condition:

    def foo():
        return

    foo()
    print("Exiting the loop.")

if condition:
    print("still +")

    def foo():
        return


print("The End.")
