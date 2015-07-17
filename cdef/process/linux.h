static const int PR_SET_PDEATHSIG = 1;

int prctl(int option, unsigned long arg2, unsigned long arg3,
          unsigned long arg4, unsigned long arg5);
