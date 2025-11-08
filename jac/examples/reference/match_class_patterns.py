from jaclang import JacMachineInterface as _


class Point(_.Obj):
    def __init__(self, x: float, y: float):
        self.x = x
        self.y = y


data = Point(x=9, y=0)

match data:
    case Point(x=int(a), y=0):
        print(f"Point with x={a} and y=0")
    case _:
        print("Not on the x-axis")
