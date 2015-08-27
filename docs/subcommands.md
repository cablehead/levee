# Guide


## Getting setup

First, you will need a few dependencies:

- **ragel**: `brew install ragel`

Next, install Levee:

```bash
git clone git@github.com:zebrafishlabs/levee.git
cd levee
cmake -H. -Bbuild/release -DCMAKE_BUILD_TYPE=Release
cd build/release
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

```bash
imgix:~ andy$ levee
Usage: levee <command> ...

Available commands are:
        run
        build
        test
        bundle
```

## The `run` command

```bash
imgix:~ andy$ levee run -h
Usage: levee run (<path> | -e <script>) [arg...]
```

### Running code snippets

The `run` command let's you run LuaJIT / Levee scripts and projects in an adhoc
way. We'll look at creating a Levee project in a short bit. First `run` has a
`-e` option which will run a string snippet:

```bash
imgix:~ andy$ levee run -e "print('oh hai')"
oh hai
```

Slightly more interesting:

```bash
imgix:~ andy$ levee run -e "
local h = require('levee').Hub()

h:spawn(function()
	while true do
			print('tick')
			h:sleep(1000)
	end
end)

h:sleep(500)

while true do
	print('tock')
	h:sleep(1000)
end
"
tick
tock
tick
tock
tick
...
```

### Running scripts

Of course you can run Lua scripts as well. Let's create a simple date network
service. Put the following code in a file called `dtsrv.lua`

```lua

local levee = require('levee')
local h = levee.Hub()

local serve = h.tcp:listen(4000)

for conn in serve do
    h:spawn(function()
        conn:write(tostring(levee.time.localdate()).."\n")
        conn:close()
    end)
end
```

To run:

```bash
imgix:~ andy$ levee run dtsrv.lua
```

Then in another window:

```bash
imgix:~ andy$ nc localhost 4000
Thu, 27 Aug 2015 18:14:37 GMT
```

## Levee projects

Levee projects are usually structured with the following layout:

```bash
imgix:~ andy$ find dtsrv
dtsrv
dtsrv/dtsrv
dtsrv/dtsrv/foo.lua
dtsrv/dtsrv/main.lua
dtsrv/test
dtsrv/test/test_foo.lua
```

There's the containing folder for the project. Then a folder for the project's
Lua source.  Usually this is the same name as the project folder.  This folder
should have a `main.lua` script which acts as your project entry point
on execution.  Projects can also have a test folder to hold the project's
tests.

To continue this guide, create the above layout. Move `dtsrv.lua` from the
previous example to the project's `dtsrv/main.lua`.

### Running projects

It's possible to run this project just by specifying the project's main Lua
folder:

```bash
imgix:dtsrv andy$ levee run ./dtsrv
```

Again, in another window:

```bash
imgix:~ andy$ nc localhost 4000
Thu, 27 Aug 2015 18:53:57 GMT
```

## The `test` command

Levee has a built in test running to facilitate quickly adding tests for your
project.

```bash
imgix:~ andy$ levee test -h
Usage: levee test [-v] [-x] [-k <match>] <path>
```

Test suites are a folder of Lua scripts prefixed with the name `test_`.  Each
test script should return a `table` of test names that map to functions. Test
names are also prefixed `test_`. Each test function will be run and can simply
assert desired functionality.

Edit `dtsrv/foo.lua`:

```lua
return {
    add = function(a, b)
        return a + b
    end,
}
```

And add this to `test/test_foo.lua`:

```lua
return {
    test_add = function()
        local foo = require("dtsrv.foo")
        assert.equal(foo.add(2, 3), 5)
    end,
}
```

To run:

```bash
imgix:dtsrv andy$ levee test -v ./test/
./test/test_foo.lua
    test_add                                  PASS

PASS=1
```

## The `build` command

This is where things get really interesting. Levee's build command will bundle
your Levee project and compile it into a standalone executable.

```bash
imgix:~ andy$ levee build -h
Usage: levee build [-o <exe] [-n <name>] <module> [module...]

Options:
  -o <exe>, --out <exe>      # file to out to [default: ./a.out]
  -n <name>, --name <name>   # project name [default: name of first module
                             # listed]
```

This part is optional. It can be handy to have a place to drop adhoc binaries
so you can run them.

```bash
mkdir -p ~/bin
```

Let's build our `dtsrv` project:

```bash
imgix:dtsrv andy$ levee build ./dtsrv -o ~/bin/dtsrv
imgix:dtsrv andy$ ls -lh ~/bin/dtsrv
-rwxr-xr-x  1 andy  staff   934K Aug 27 12:03 /Users/andy/bin/dtsrv
```

934K, sweet!

Finally let's run our new binary:

```bash
~/bin/dtsrv
```

And in that other window:

```bash
imgix:~ andy$ nc localhost 4000
Thu, 27 Aug 2015 18:53:57 GMT
```
