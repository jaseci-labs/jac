typedef unsigned int mode_t;

unsigned long
mask_mode(long omode)
{
    mode_t mode;
    mode = (mode_t)omode;
    return (unsigned long)(mode & 07777);
}
