class Car:
    wheels: int = 4

    def __init__(self, make: str, model: str, year: int):
        self.make = make
        self.model = model
        self.year = year

    def display_car_info(self):
        print(f"Car Info: {self.year} {self.make} {self.model}")

    @staticmethod
    def get_wheels():
        return Car.wheels


car1 = Car("Toyota", "Camry", 2020)
car1.display_car_info()
print("Number of wheels:", Car.get_wheels())
