include os;
import datetime as dt;
import from math { sqrt as square_root, log }

with entry {
    for i in range(int(square_root(dt.datetime.now().year))) {
        print(
            getcwd(),
            square_root(i),
            int(log(i + 1))
        );
    }
}
