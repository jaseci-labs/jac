"""\nSimple division by zero example - trivial case for baseline testing.\nThe assert failure is immediately obvious from the code.\n"""

import numpy as np;
import time;


"""Calculate empirical risk with division by zero check."""
def calculate_empirical_risk(X: Any, y: Any, theta: Any) {
    n = X.shape[0];
    sum_risk = 0;
    for i in range(n) {
        val = (y[i] - np.dot(theta, X[i]));
        val **= 2;
        val /= 2;
        sum_risk += val;
    }
    assert (n != 0) , f"'Cannot calculate risk with empty dataset. n = '{n}" ;
    sum_risk /= n;
    return sum_risk;
}


"""Generate polynomial features."""
def generate_polynomial_features(X: Any, M: Any) {
    n = X.shape[0];
    Phi = np.zeros((n, (M + 1)));
    for i in range(n) {
        for j in range((M + 1)) {
            Phi[i][j] = (X[i] ** j);
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


with entry {
    if (__name__ == '__main__') {
        train_data = [[0.6755294828444033, 0.6054908010772743],
        [0.033827894115051604, 0.901713727909418],
        [-0.0513840229887791, 0.924490729474708],
        [-0.072651497611752, 0.836797477307684],
        [0.1423462723132326, 0.1122895856168532]];
        print('=== Simple Division by Zero Example ===');
        X_train = np.array([]);
        y_train = np.array([ <>entry[1] for <>entry in train_data ]);
        try {
            bigX = generate_polynomial_features(X_train, 1);
            theta = closed_form_optimization(bigX, y_train);
            risk = calculate_empirical_risk(bigX, y_train, theta);
            print('Success - no assert failure');
        } except AssertionError as e {
            print(f"'ASSERT FAILED: '{e}");
            print('Runtime state:');
            print(f"'  X_train.shape = '{X_train.shape}");
            print(f"'  y_train.shape = '{y_train.shape}");
            print(f"'  X_train = '{X_train}");
        }

    }
}
