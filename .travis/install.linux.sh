CMAKE=cmake-3.5.0-Linux-x86_64

sudo apt-get update
sudo apt-get install ragel
wget --no-check-certificate https://cmake.org/files/v3.5/${CMAKE}.tar.gz
tar -xzf ${CMAKE}.tar.gz
./${CMAKE}/bin/cmake -H. -Bbuild -DCMAKE_BUILD_TYPE=Release
cd build && make && sudo make install && cd ..
