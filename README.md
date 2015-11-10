# Levee

Levee is a tool to succinctly and quickly create high performance network
appliances.

## Getting setup

First, you will need a few dependencies:

On Mac:

```bash
brew install ragel
```

On Debian / Ubuntu:

```bash
apt-get install ragel
```

Next, install Levee:

```bash
git clone git@github.com:imgix/levee.git
cd levee
cmake -H. -Bbuild -DCMAKE_BUILD_TYPE=Release
cd build
make
make install
```

By default Levee will be installed to `/usr/local`. You can also set a custom
install directory:

```bash
make DESTDIR=/tmp/foo install
```

Make sure the installed location is in your `PATH`:

```bash
export PATH=$PATH:/usr/local/bin
```

And we should be all set to go:

```
imgix:~ andy$ levee
Usage: levee <command> ...

Available commands are:
        run
        build
        bundle
        test
        version
```

