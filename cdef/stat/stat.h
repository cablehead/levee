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
