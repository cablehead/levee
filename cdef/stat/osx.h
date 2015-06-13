typedef int dev_t;
typedef unsigned short int mode_t;
typedef unsigned short int nlink_t;
typedef unsigned long long int ino_t;
typedef unsigned int uid_t;
typedef unsigned int gid_t;
typedef long long int off_t;
typedef long long int blkcnt_t;
typedef int blksize_t;

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

struct stat { /* when _DARWIN_FEATURE_64_BIT_INODE is defined */
	 dev_t           st_dev;           /* ID of device containing file */
	 mode_t          st_mode;          /* Mode of file (see below) */
	 nlink_t         st_nlink;         /* Number of hard links */
	 ino_t           st_ino;           /* File serial number */
	 uid_t           st_uid;           /* User ID of the file */
	 gid_t           st_gid;           /* Group ID of the file */
	 dev_t           st_rdev;          /* Device ID */
	 struct timespec st_atimespec;     /* time of last access */
	 struct timespec st_mtimespec;     /* time of last data modification */
	 struct timespec st_ctimespec;     /* time of last status change */
	 struct timespec st_birthtimespec; /* time of file creation(birth) */
	 off_t           st_size;          /* file size, in bytes */
	 blkcnt_t        st_blocks;        /* blocks allocated for file */
	 blksize_t       st_blksize;       /* optimal blocksize for I/O */
	 uint32_t        st_flags;         /* user defined flags for file */
	 uint32_t        st_gen;           /* file generation number */
	 int32_t         st_lspare;        /* RESERVED: DO NOT USE! */
	 int64_t         st_qspare[2];     /* RESERVED: DO NOT USE! */
};
