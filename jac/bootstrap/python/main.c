/* The interpreter executable's entry point; the runtime lives in libpython. */
int Py_BytesMain(int argc, char **argv);

int
main(int argc, char **argv)
{
    return Py_BytesMain(argc, argv);
}
