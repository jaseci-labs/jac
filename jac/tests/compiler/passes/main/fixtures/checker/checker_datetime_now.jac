import from datetime { datetime }

with entry {
    # cls of the now method should be skipped for parameter
    # check because it's a classmethod (from python source code).
    x = datetime.now();  # <-- Ok
}
