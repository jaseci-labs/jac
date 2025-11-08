class Sample:
    def __init__(self):
        self.my_list = [1, 2, 3]
        self.my_dict = {"name": "John", "age": 30}


def main():
    sample_instance = Sample()
    first, second = sample_instance.my_list[2], sample_instance.my_dict["name"]

    print(first, second)


main()
