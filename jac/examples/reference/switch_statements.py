from __future__ import annotations


def switch_case(Num: int) -> None:
    __executed = False
    while not __executed:
        if Num == 2 or __executed:
            pass
            __executed = True
        if Num == 3 or __executed:
            pass
            __executed = True
        if Num == 10 or __executed:
            print("Matched case for value: 2, 3, 10")
            __executed = True
        if Num == 15 or __executed:
            pass
            __executed = True
        if Num == 20 or __executed:
            print("Matched case for value: 15, 20")
            break
            __executed = True
        if Num == 25 or __executed:
            pass
            __executed = True
        if Num is None or __executed:
            print("Matched case for value: 25 or None")
            __executed = True
        print("No match found for value: " + str(Num))
        __executed = True


switch_case(3)
switch_case(15)
switch_case(25)
