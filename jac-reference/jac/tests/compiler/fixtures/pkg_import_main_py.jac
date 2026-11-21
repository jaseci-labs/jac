import from pkg_import_lib_py { tool_func, glob_var_lib }
import from pkg_import_lib_py.sub { help_func }

with entry {
    print('Main Execution:\n');
    print('Calling from tools.jac...');
    print('Tool says:', tool_func());
    print('\nCalling from helper.jac...');
    print('Helper says:', help_func());
    print('\nGlobal variable from lib:', glob_var_lib);
}
