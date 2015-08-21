enum {
     S_IFMT   = 0170000,  /* type of file */
     S_IFIFO  = 0010000,  /* named pipe (fifo) */
     S_IFCHR  = 0020000,  /* character special */
     S_IFDIR  = 0040000,  /* directory */
     S_IFBLK  = 0060000,  /* block special */
     S_IFREG  = 0100000,  /* regular */
     S_IFLNK  = 0120000,  /* symbolic link */
     S_IFSOCK = 0140000,  /* socket */
     S_IFWHT  = 0160000,  /* whiteout */
};

enum {
     S_ISUID = 0004000,  /* set user id on execution */
     S_ISGID = 0002000,  /* set group id on execution */
     S_ISVTX = 0001000,  /* save swapped text even after use */
     S_IRUSR = 0000400,  /* read permission, owner */
     S_IWUSR = 0000200,  /* write permission, owner */
     S_IXUSR = 0000100,  /* execute/search permission, owner */
};


struct levee_stat {
	// unsigned long long  st_dev;       /* Device.  */
	// unsigned long long  st_ino;       /* File serial number.  */
	unsigned int        st_mode;      /* File mode.  */
	// unsigned int        st_nlink;     /* Link count.  */
	// unsigned int        st_uid;       /* User ID of the file's owner.  */
	// unsigned int        st_gid;       /* Group ID of the file's group. */
	// unsigned long long  st_rdev;      /* Device number, if device.  */
	long long           st_size;      /* Size of file, in bytes.  */
	// int                 st_blksize;   /* Optimal block size for I/O.  */
	// long long           st_blocks;    /* Number 512-byte blocks allocated. */
	// struct timespec     st_atime;     /* Time of last access.  */
	// struct timespec     st_mtime;     /* Time of last modification.  */
	// struct timespec     st_ctime;     /* Time of last status change.  */
};

int levee_fstat(int fd, struct levee_stat *buf);
int levee_stat(const char *path, struct levee_stat *buf);
