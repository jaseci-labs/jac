"""\nArray bounds mismatch example.\nThe assert failure occurs due to inconsistent array sizing.\n"""

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
        [0.1376010145959681, 0.2519302178829483]];
        val_data = [[0.0758615810892394, 0.9131455311697625],
        [0.32412388912616896, 0.9817790261143028],
        [0.5815351563241093, 0.5836868580111579],
        [-0.0888426458342539, 0.25302051984997653],
        [-0.0913273424895036, 0.8254519331384003]];
        print('=== Array Bounds Check Example ===');
        X_train = np.array([ <>entry[0] for <>entry in train_data ]);
        y_train = np.array([ <>entry[1] for <>entry in train_data ]);
        X_validation = np.array([ <>entry[0] for <>entry in val_data ]);
        y_validation = np.array([ <>entry[1] for <>entry in val_data ]);
        errors_train = np.zeros(11);
        errors_validation = np.zeros(11);
        for i in range(11) {
            X_tr = generate_polynomial_features(X_train, i);
            X_test = generate_polynomial_features(X_validation, i);
            theta = closed_form_optimization(X_tr, y_train);
            errors_train[i] = calculate_RMS_Error(X_tr, y_train, theta);
            errors_validation[i] = calculate_RMS_Error(X_test, y_validation, theta);
        }
        print('Part 1 completed successfully');
        errors_train = np.zeros(10);
        errors_validation = np.zeros(10);
        L = np.append([0], (10.0 ** np.arange(-8, 1)));
        X_tr = generate_polynomial_features(X_train, 10);
        X_test = generate_polynomial_features(X_validation, 10);
        for i in range(11) {
            assert (i < len(L)) , f"'Index '{i}' out of bounds for array L of length '{len(L)}" ;
            theta = closed_form_optimization(X_tr, y_train, L[i]);
            errors_train[i] = calculate_RMS_Error(X_tr, y_train, theta);
            errors_validation[i] = calculate_RMS_Error(X_test, y_validation, theta);
        }
        print('Part 2 completed successfully');
    }
}
