brew install cmake
brew install ragel

LIBRESSL=libressl-2.5.4
wget https://ftp.openbsd.org/pub/OpenBSD/LibreSSL/${LIBRESSL}.tar.gz
tar -xzf ${LIBRESSL}.tar.gz
cd ${LIBRESSL}
./configure --prefix=/usr
make
sudo make install
cd ..

cmake -H. -Bbuild -DCMAKE_BUILD_TYPE=Release
cd build && make && sudo make install && cd ..

