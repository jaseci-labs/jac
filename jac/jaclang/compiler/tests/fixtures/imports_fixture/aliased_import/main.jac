import module_d as md;
import from module_d { long_function_name as lfn }

with entry {
    print(f"Import as - md.LONG_MODULE_VALUE: {md.LONG_MODULE_VALUE}");
    print(f"From import as - lfn(): {lfn()}");
}
