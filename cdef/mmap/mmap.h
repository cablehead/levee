void *mmap(void *addr, size_t length, int prot, int flags, int fd, ssize_t offset);
int munmap(void *addr, size_t length);
int msync(void *addr, size_t length, int flags);
int mprotect(void *addr, size_t len, int prot);
int madvise(void *addr, size_t len, int advice);
