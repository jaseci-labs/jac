"""\nNumerical convergence failure in binary search optimization.\nThe assert failure occurs when the iterative algorithm doesn't converge\ndue to precision/parameter interactions.\n"""

"""\n    Optimize braking force for aircraft landing using binary search.\n    Solves the physics simulation to find optimal braking coefficient.\n    """
def optimize_braking_force() {
    v0 = 300.0;
    c_d = 0.001;
    runwayLength = 100.0;
    tolerance = 1e-06;
    timeStep = 1e-05;
    max_rounds = 10;
    bmin = 0.0;
    bmax = ((v0 * v0) / (2.0 * runwayLength));
    round_count = 0;

    while ((bmax - bmin) > tolerance) {
        round_count += 1;
        bmid = ((bmin + bmax) / 2.0);
        # print(f"'Round '{round_count}': Testing bmid = '{bmid}");
        a_old = 0.0;
        v_old = v0;
        x_old = 0.0;
        simulation_steps = 0;
        while ((v_old > 0) and (x_old < runwayLength) ) {
            a_old = (-bmid - ((c_d * v_old) * v_old));
            v_new = (v_old + (a_old * timeStep));
            x_new = (x_old + (v_old * timeStep));
            v_old = v_new;
            x_old = x_new;
            simulation_steps += 1;
        }
        assert (round_count < max_rounds) , f"'Binary search failed to converge within '{max_rounds}' iterations." ;
        if (x_old > runwayLength) {
            bmin = bmid;
            # print(f"'  Overshot -> increase braking (bmin = '{bmin}')'");
        } elif (x_old < runwayLength) {
            bmax = bmid;
            # print(f"'  Undershot -> decrease braking (bmax = '{bmax}')'");
        } else {
            break;
        }
    }
    # print(f"'Optimization completed in '{round_count}' rounds'");
    # print(f"'Optimal braking coefficient: '{((bmin + bmax) / 2.0)}");
    return ((bmin + bmax) / 2.0);
}


with entry {
    if (__name__ == '__main__') {
        print('=== Numerical Convergence Example ===');
        optimal_b = optimize_braking_force();
        print(f"'Success! Optimal braking force: '{optimal_b}");
    }
}
