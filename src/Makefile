CFLAGS := -Wall -Werror -g
coro.so: coro.o
	$(CC) -shared -lluajit-5.1 -fPIC $< -o $@

clean:
	rm -f coro.so coro.o

.PHONY: clean
