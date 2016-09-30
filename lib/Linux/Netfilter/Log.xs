#include <errno.h>
#include <stdint.h>
#include <string.h>
#include <sys/socket.h>
#include <sys/types.h>
#include <libnetfilter_log/libnetfilter_log.h>

#include "EXTERN.h"
#include "perl.h"
#include "XSUB.h"

#include "ppport.h"

MODULE = Linux::Netfilter::Log	PACKAGE = Linux::Netfilter::Log

struct nflog_handle* open(const char *class)
	CODE:
		RETVAL = nflog_open();
		if(RETVAL == NULL)
		{
			croak("nflog_open: %s", strerror(errno));
		}

	OUTPUT:
		RETVAL

void DESTROY(struct nflog_handle *self)
	CODE:
		if(nflog_close(self) == -1)
		{
			warn("nflog_close: %s", strerror(errno));
		}

void bind_pf(struct nflog_handle *self, uint16_t pf)
	CODE:
		if(nflog_bind_pf(self, pf) < 0)
		{
			croak("nflog_bind_pf: %s", strerror(errno));
		}

void unbind_pf(struct nflog_handle *self, uint16_t pf)
	CODE:
		if(nflog_unbind_pf(self, pf) < 0)
		{
			croak("nflog_unbind_pf: %s", strerror(errno));
		}

int fileno(struct nflog_handle *self)
	CODE:
		RETVAL = nflog_fd(self);

	OUTPUT:
		RETVAL

int handle_packet(struct nflog_handle *self)
	CODE:
		/* TODO: Don't assume 64k buffer?
		 *
		 * Use of SAVEFREEPV() will implicitly Safefree() the buffer
		 * when the XSUB returns.
		*/
		void *buf;
		Newxz(buf, 65536, char);
		SAVEFREEPV(buf);

		ssize_t len = recv(nflog_fd(self), buf, 65536, 0);
		if(len < 0)
		{
			int err = errno;

			if(err == ENOBUFS)
			{
				/* TODO: Return some special value to indicate
				 * ENOBUFS to the caller.
				*/
				warn("recv returned ENOBUFS - the buffer filled up!");
				XSRETURN(0);
			}

			croak("recv: %s", strerror(errno));
		}

		RETVAL = nflog_handle_packet(self, buf, len);

		if(RETVAL < 0)
		{
			/* Most error conditions within nflog_handle_packet()
			 * don't actually initialise errno and seem to pop up
			 * with annoying regularity... ugh.
			*/
			//warn("nflog_handle_packet returned %d", RETVAL);
		}

	OUTPUT:
		RETVAL
