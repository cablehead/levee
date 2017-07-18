# Levee [![Build Status](https://travis-ci.org/imgix/levee.png?branch=master)](https://travis-ci.org/imgix/levee)

Levee is a tool to succinctly and quickly create high performance network
appliances.

## An overview

* http://cablehead.github.io/Talks.Levee.A-Whirlwind-Tour/

## Installing


First, you will need a few dependencies:

```bash
apt-get install ragel  # ubuntu, or
brew install ragel     # macos
```

Next, install Levee:

```bash
git clone https://github.com/imgix/levee.git
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


