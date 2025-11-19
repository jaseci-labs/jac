from __future__ import annotations

try:
    x = 5 / 0
except Exception:
    print("caught exception")
try:
    x = 5 / 0
except Exception as e:
    print(f"error: {e}")
try:
    x = int("not a number")
except ValueError as ve:
    print(f"ValueError: {ve}")
except TypeError as te:
    print(f"TypeError: {te}")
except Exception as e:
    print(f"other: {e}")
try:
    result = 10 / 2
except ZeroDivisionError:
    print("division by zero")
else:
    print(f"success: {result}")
try:
    x = 5 / 1
except Exception:
    print("error")
finally:
    print("cleanup")
try:
    data = [1, 2, 3]
    print(data[1])
except IndexError as ie:
    print(f"index error: {ie}")
else:
    print("access successful")
finally:
    print("done")
try:
    print("operation")
finally:
    print("always runs")
try:
    try:
        x = 5 / 0
    except ValueError:
        print("inner ValueError")
except Exception as e:
    print(f"outer caught: {e}")
