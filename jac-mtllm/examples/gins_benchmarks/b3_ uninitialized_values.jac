"""\nUninitialized values example due to off-by-one error.\nThe assert failure occurs when checking for zero values that shouldn't exist,\nbut the root cause is a subtle loop boundary bug.\n"""

import numpy as np;
import time;


"""Calculate empirical risk."""
def calculate_empirical_risk(X: Any, y: Any, theta: Any) {
    n = X.shape[0];
    sum_risk = 0;
    for i in range(n) {
        val = (y[i] - np.dot(theta, X[i]));
        val **= 2;
        val /= 2;
        sum_risk += val;
    }
    sum_risk /= n;
    return sum_risk;
}


"""Calculate RMS error."""
def calculate_RMS_Error(X: Any, y: Any, theta: Any) {
    n = X.shape[0];
    E_rms = 0;
    for i in range(n) {
        E_rms += ((np.dot(theta, X[i]) - y[i]) ** 2);
    }
    E_rms /= n;
    E_rms = np.sqrt(E_rms);
    return E_rms;
}


"""Generate polynomial features with a subtle off-by-one bug."""
def generate_polynomial_features(X: Any, M: Any) {
    n = X.shape[0];
    Phi = np.zeros((n, (M + 1)));
    for i in range(0, (n - 1)) {
        for j in range(0, (M + 1)) {
            Phi[i][j] = (X[i] ** j);
        }
    }
    for i in range(n) {
        for j in range((M + 1)) {
            if (j > 0) {
                assert (Phi[i][j] != 0.0) , f"Polynomial feature Phi['{i}']['{j}'] is zero." ;
            }
        }
    }
    return Phi;
}


"""Closed form linear regression solution."""
def closed_form_optimization(X: Any, y: Any, reg_param: Any = 0) {
    n = X.shape[0];
    d = X.shape[1];
    theta = np.zeros(d);
    X_T = X.transpose();
    inv = np.matmul(X_T, X);
    inv += (reg_param * np.identity(d));
    inv = np.linalg.inv(inv);
    temp = np.matmul(X_T, y);
    theta = np.matmul(inv, temp);
    return theta;
}


with entry {
    if (__name__ == '__main__') {
        train_data = [[0.6755294828444033, 0.6054908010772743],
        [0.033827894115051604, 0.901713727909418],
        [-0.0513840229887791, 0.924490729474708],
        [-0.072651497611752, 0.836797477307684],
        [0.1423462723132326, 0.1122895856168532],
        [0.2801281690878424, 0.7404775817588839],
        [0.6520401465484031, 0.41580094200540807],
        [0.836398699520691, 0.5965109454480806],
        [0.5194478071553773, 0.703871465558813],
        [0.1376010145959681, 0.2519302178829483],
        [0.3423136677254472, 0.2853564020665839],
        [0.33078259516683234, 0.7578059336011658],
        [0.0519201109658643, 0.8069236094590105],
        [0.042514140974268894, 0.8801676397749953],
        [0.0178649580375613, 0.7910048939943627],
        [0.3785882155791389, 0.1067443064210857],
        [-0.0539132582155979, 0.14573373513289511],
        [0.243761707490169, 0.762960699487701],
        [0.1327927056707958, 0.2936982161996094],
        [0.0865229852553948, 0.2776060139421467]];
        print('=== Uninitialized Values Example ===');
        X_train = np.array([ <>entry[0] for <>entry in train_data ]);
        y_train = np.array([ <>entry[1] for <>entry in train_data ]);
        print(f"'X_train shape: '{X_train.shape}");
        print(f"'Number of data points: '{len(train_data)}");
        bigX = generate_polynomial_features(X_train, 1);
        print('Polynomial features generated successfully');

    }
}
