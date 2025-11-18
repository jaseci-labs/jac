def total(values):
    return sum(values)


result = total((x * x) for x in range(5))
print(result)
