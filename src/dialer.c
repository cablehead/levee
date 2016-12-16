#include <assert.h>
#include <pthread.h>
#include <unistd.h>
#include <signal.h>
#include <stdio.h>
#include <netdb.h>
#include <string.h>
#include <errno.h>

#include <sys/types.h>
#include <sys/socket.h>

#include <siphon/error.h>

#include "dialer.h"


struct LeveeDialerState levee_dialer_state;


struct LeveeDialerResponse {
	int err;
	struct addrinfo *info;
};


void *
levee_dialer_loop () {
	sigset_t set;
	sigfillset (&set);
	pthread_sigmask (SIG_SETMASK, &set, NULL);

	int rc;

	struct LeveeDialerRequest req;
	struct LeveeDialerResponse res;

	char node[256];
	char service[32];

	struct addrinfo hints;

	while (1) {
		memset (&hints, 0, sizeof (hints));
		memset (&res, 0, sizeof (res));

		rc = read (levee_dialer_state.io[0], &req, sizeof (req));
		assert (rc == sizeof (req));
		assert (req.node_len < sizeof (node));
		assert (req.service_len < sizeof (service));

		rc = read (levee_dialer_state.io[0], node, req.node_len);
		assert (rc == req.node_len);
		node[req.node_len] = 0;

		rc = read (levee_dialer_state.io[0], service, req.service_len);
		assert (rc == req.service_len);
		service[req.service_len] = 0;

		hints.ai_family = req.family;
		hints.ai_socktype = req.socktype;

		rc = getaddrinfo (node, service, &hints, &res.info);
		if (rc != 0) {
			res.err = SP_EAI_CODE(rc);
		}

		rc = write (req.no, &res, sizeof (res));
		assert (rc == sizeof (res));
	}
}


int
levee_dialer_boot (void) {
	pthread_t thr;
	pthread_attr_t attr;
	int rc;

	rc = pipe (levee_dialer_state.io);
	if (rc != 0) return -errno;

	rc = pthread_attr_init (&attr);
	if (rc != 0) return -errno;
	rc = pthread_attr_setdetachstate (&attr, PTHREAD_CREATE_DETACHED);
	if (rc != 0) return -errno;
	rc = pthread_create (&thr, &attr, &levee_dialer_loop, NULL);
	if (rc != 0) return -errno;

	return 0;
}


pthread_once_t levee_dialer_once = PTHREAD_ONCE_INIT;


void
levee_dialer_run_once (void) {
	levee_dialer_state.rc = levee_dialer_boot ();
}


struct LeveeDialerState
levee_dialer_init (void) {
	pthread_once (&levee_dialer_once, levee_dialer_run_once);
	return levee_dialer_state;
}
