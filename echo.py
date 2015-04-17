import vanilla

h = vanilla.Hub()

serve = h.tcp.listen(8000)


def echo(conn):
    print 'connected'
    for s in conn.recver:
        print s
        conn.send(s)
    print 'disconnected'


while True:
    conn = serve.recv()
    h.spawn(echo, conn)
