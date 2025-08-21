obj Car {
    has make: str,
        model: str,
        year: int;
    static has wheels: int = 4;

    def display_car_info {
        print(f"Car Info: {self.year} {self.make} {self.model}");
    }

    static def get_wheels -> int {
        return Car.wheels;
    }
}

with entry {
    car = Car("Toyota", "Camry", 2020);
    car.display_car_info();
    print("Number of wheels:", Car.get_wheels());
}
