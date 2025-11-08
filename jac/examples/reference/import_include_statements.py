import os
import datetime as dt
from math import sqrt as square_root, log

for i in range(int(square_root(dt.datetime.now().year))):
    print(os.getcwd(), square_root(i), int(log(i + 1)))
