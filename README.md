# levee

Network tool.

## Compile

### Debug build

```bash
cmake -H. -Bbuild/debug -DCMAKE_BUILD_TYPE=Debug
# or cmake -H. -Bbuild/debug -DCMAKE_BUILD_TYPE=Debug -G Ninja
cmake --build build/debug
./build/debug/levee examples/chunked.lua
```

### Release build

```bash
cmake -H. -Bbuild/release -DCMAKE_BUILD_TYPE=Release
# or cmake -H. -Bbuild/release -DCMAKE_BUILD_TYPE=Release -G Ninja
cmake --build build/release
./build/release/levee examples/chunked.lua
```
