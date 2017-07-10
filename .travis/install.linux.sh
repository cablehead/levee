sudo apt-get update
sudo apt-get install ragel

CMAKE=cmake-3.5.0-Linux-x86_64
wget --no-check-certificate https://cmake.org/files/v3.5/${CMAKE}.tar.gz
tar -xzf ${CMAKE}.tar.gz

LIBRESSL=libressl-2.5.4
wget https://ftp.openbsd.org/pub/OpenBSD/LibreSSL/${LIBRESSL}.tar.gz
tar -xzf ${LIBRESSL}.tar.gz
cd ${LIBRESSL}
./configure --prefix=../tls
make
make install
cd ..

./${CMAKE}/bin/cmake -H. -Bbuild -DCMAKE_BUILD_TYPE=Release
cd build && make && sudo make install && cd ..
