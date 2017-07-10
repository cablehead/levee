export LD_LIBRARY_PATH=./tls/lib
levee test -vv tests/
CODE=$?
exit $CODE
