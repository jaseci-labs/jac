/* Header-free extract of CPython Python/pyfpe.c (PyFPE_dummy). */

int PyFPE_counter;

double
PyFPE_dummy(void *dummy)
{
    return 1.0;
}
