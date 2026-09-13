import fnmatch;
import os;
import from jaclang.runtime.runtime { JacRuntimeInterface }

def run_test(
    filepath: str,
    func_name: (str | None) = None,
    filter: (str | None) = None,
    xit: bool = False,
    maxfail: (int | None) = None,
    directory: (str | None) = None,
    verbose: bool = False
) -> int {
    import from jaclang.testing.test { JacTestCheck }
    import from jaclang.testing.cl_test_runner {
        is_cl_test_file,
        is_cl_test_file_for_discovery,
        run_cl_test_file,
        register_results_into_jactestcheck
    }
    import from jaclang.jac0core.ext_registry { base_stem, is_annex }
    test_file = False;
    ret_count = 0;
    if filepath {
        if is_cl_test_file(filepath) {
            JacTestCheck.reset();
            results = run_cl_test_file(filepath, test_name=func_name);
            register_results_into_jactestcheck(os.path.abspath(filepath), results);
            JacTestCheck.run_test(
                xit, maxfail, verbose, os.path.abspath(filepath), func_name
            );
            ret_count = JacTestCheck.failcount;
        } elif filepath.endswith('.jac') {
            (base, mod_name) = os.path.split(filepath);
            base = base or './';
            mod_name = base_stem(mod_name);
            JacTestCheck.reset();
            JacRuntimeInterface.jac_import(target=mod_name, base_path=base);
            JacTestCheck.run_test(
                xit, maxfail, verbose, os.path.abspath(filepath), func_name
            );
            ret_count = JacTestCheck.failcount;
        } else {
            JacRuntimeInterface.get_console().error('Not a .jac file.');
        }
    } else {
        directory = directory or os.getcwd();
    }
    if (filter or directory) {
        current_dir = directory or os.getcwd();
        for (root_dir, dirs, files) in os.walk(current_dir, topdown=True) {
            dirs[:] = [
                d
                for d in dirs
                if not (d.startswith('.') or d == '__pycache__')
            ];
            files = [
                file
                for file in files
                if fnmatch.fnmatch(file, filter)
            ]
                if filter
                else files;
            files = [
                file
                for file in files
                if not is_annex(file)
            ];
            for file in files {
                if is_cl_test_file_for_discovery(os.path.join(root_dir, file)) {
                    test_file = True;
                    cl_path = os.path.join(root_dir, file);
                    JacRuntimeInterface.get_console().info(
                        f"\n\n\t\t* Inside {root_dir}/{file} *"
                    );
                    JacTestCheck.reset();
                    register_results_into_jactestcheck(
                        os.path.abspath(cl_path),
                        run_cl_test_file(cl_path, test_name=func_name)
                    );
                    JacTestCheck.run_test(
                        xit, maxfail, verbose, os.path.abspath(file), func_name
                    );
                } elif file.endswith('.jac') {
                    test_file = True;
                    JacRuntimeInterface.get_console().info(
                        f"\n\n\t\t* Inside {root_dir}/{file} *"
                    );
                    JacTestCheck.reset();
                    mod_target = base_stem(file);
                    JacRuntimeInterface.jac_import(
                        target=mod_target, base_path=root_dir
                    );
                    JacTestCheck.run_test(
                        xit, maxfail, verbose, os.path.abspath(file), func_name
                    );
                }
                if (JacTestCheck.breaker and (xit or maxfail)) {
                    break;
                }
            }
            if (JacTestCheck.breaker and (xit or maxfail)) {
                break;
            }
        }
        JacTestCheck.breaker = False;
        ret_count += JacTestCheck.failcount;
        JacTestCheck.failcount = 0;
        if not test_file {
            JacRuntimeInterface.get_console().warning('No test files found.');
        }
    }
    return ret_count;
}
