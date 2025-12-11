import from pkg_import_lib { tool_func }
import from pkg_import_lib.sub { help_func }

with entry {
    print('Main Execution:\n');
    print('Calling from tools.jac...');
    print('Tool says:', tool_func());
    print('\nCalling from helper.jac...');
    print('Helper says:', help_func());
}
