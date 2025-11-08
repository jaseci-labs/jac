from abc import ABC, abstractmethod


class Calculator(ABC):
    @staticmethod
    def multiply(a: float, b: float) -> float:
        return a * b

    @abstractmethod
    def substract(self, x: float, y: float) -> float:
        pass

    def add(self, number: float, *a: float) -> str:
        return str(number * sum(a))


class Substractor(Calculator):
    def substract(self, x: float, y: float) -> float:
        return x - y


class Divider:
    def divide(self, x: float, y: float):
        return x / y


sub = Substractor()
div = Divider()
print(div.divide(55, 11))
print(Calculator.multiply(9, -2))
print(sub.add(5, 20, 34, 56))
print(sub.substract(9, -2))
