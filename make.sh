set -xeo pipefail

function finish {
	cd ~/git/levee

}

trap finish EXIT

cd build
make clean
make
make install
