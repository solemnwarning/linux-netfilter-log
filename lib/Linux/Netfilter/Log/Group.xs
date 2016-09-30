#include <arpa/inet.h>
#include <errno.h>
#include <stdint.h>
#include <string.h>
#include <sys/types.h>
#include <libnetfilter_log/libnetfilter_log.h>

#include "EXTERN.h"
#include "perl.h"
#include "XSUB.h"

#include "ppport.h"

struct perl_nflog_group
{
	SV                    *handle;
	struct nflog_g_handle *g_handle;

	CV *callback;
};

static void _packet_copy_dev(HV *packet, const char *key, struct nflog_data *nfad, uint32_t (*func)(struct nflog_data*))
{
	u_int32_t dev = func(nfad);
	if(dev > 0)
	{
		hv_store(packet, key, strlen(key), newSVuv(dev), 0);
	}
}

static void _packet_copy_u32_buf(HV *packet, const char *key, struct nflog_data *nfad, int (*func)(struct nflog_data*, u_int32_t *buf))
{
	u_int32_t buf;
	if(func(nfad, &buf) == 0)
	{
		hv_store(packet, key, strlen(key), newSVuv(buf), 0);
	}
}

/* Build a Linux::Netfilter::Log::Packet object to pass to the callback.
 *
 * We copy all the data out of nfad rather than wrapping it so the object can
 * remain valid beyond the life of the callback.
*/
static SV *_make_packet_obj(struct nflog_data *nfad)
{
	HV *packet    = newHV();
	SV *packet_sv = sv_bless(newRV_noinc((SV*)(packet)), gv_stashpv("Linux::Netfilter::Log::Packet", 0));

	{
		struct nfulnl_msg_packet_hdr *hdr = nflog_get_msg_packet_hdr(nfad);
		if(hdr != NULL)
		{
			hv_store(packet, "hw_protocol", strlen("hw_protocol"), newSVuv(ntohs(hdr->hw_protocol)), 0);
			hv_store(packet, "hook",        strlen("hook"),        newSVuv(hdr->hook),               0);
		}
	}

	hv_store(packet, "hwtype", strlen("hwtype"), newSVuv(nflog_get_hwtype(nfad)), 0);

	{
		u_int16_t len = nflog_get_msg_packet_hwhdrlen(nfad);
		char *header  = nflog_get_msg_packet_hwhdr(nfad);

		if(len > 0 && header != NULL)
		{
			hv_store(packet, "hwhdr", strlen("hwhdr"), newSVpvn(header, len), 0);
		}
	}

	hv_store(packet, "mark", strlen("mark"), newSVuv(nflog_get_nfmark(nfad)), 0);

	{
		struct timeval tv;
		if(nflog_get_timestamp(nfad, &tv) == 0)
		{
			hv_store(packet, "timestamp.sec",  strlen("timestamp.sec"),  newSViv(tv.tv_sec),  0);
			hv_store(packet, "timestamp.usec", strlen("timestamp.usec"), newSViv(tv.tv_usec), 0);
		}
	}

	_packet_copy_dev(packet, "indev",      nfad, &nflog_get_indev);
	_packet_copy_dev(packet, "physindev",  nfad, &nflog_get_physindev);
	_packet_copy_dev(packet, "outdev",     nfad, &nflog_get_outdev);
	_packet_copy_dev(packet, "physoutdev", nfad, &nflog_get_physoutdev);

	{
		struct nfulnl_msg_packet_hw *hw = nflog_get_packet_hw(nfad);
		if(hw != NULL)
		{
			hv_store(packet, "hw", strlen("hw"), newSVpvn(hw->hw_addr, sizeof(hw->hw_addr)), 0);
		}
	}

	{
		char *payload;
		int payload_len = nflog_get_payload(nfad, &payload);

		if(payload_len > 0 && payload != NULL)
		{
			hv_store(packet, "payload", strlen("payload"), newSVpvn(payload, payload_len), 0);
		}
	}

	{
		char *prefix = nflog_get_prefix(nfad);
		if(prefix != NULL)
		{
			hv_store(packet, "prefix", strlen("prefix"), newSVpv(prefix, 0), 0);
		}
	}

	_packet_copy_u32_buf(packet, "uid", nfad, &nflog_get_uid);
	_packet_copy_u32_buf(packet, "gid", nfad, &nflog_get_gid);

	_packet_copy_u32_buf(packet, "seq",        nfad, &nflog_get_seq);
	_packet_copy_u32_buf(packet, "seq_global", nfad, &nflog_get_seq_global);

	return packet_sv;
}

static int _callback_proxy(struct nflog_g_handle *gh, struct nfgenmsg *nfmsg, struct nflog_data *nfad, void *data)
{
	SV *callback_func = (SV*)(data);

	dSP;

	ENTER;
	SAVETMPS;

	SV *packet_sv = sv_2mortal(_make_packet_obj(nfad));

	PUSHMARK(SP);
	XPUSHs(packet_sv);
	PUTBACK;

	int ret_count = call_sv(callback_func, G_SCALAR);

	SPAGAIN;

	SV *ret_sv;
	int ret;

	if(!(ret_count == 1          /* Perl sub returned 1 SV */
		&& (ret_sv = POPs)   /* Pop it off the stack */
		&& SvIOK(ret_sv)     /* Can be coerced to an integer */
		&& (ret = SvIV(ret_sv)) >= 0))
	{
		warn("Callback didn't return an integer >= 0, this is undefined behaviour!");
		ret = 1; /* "some user defined error" as far as nflog is concerned. */
	}

	PUTBACK;
	FREETMPS;
	LEAVE;

	return ret;
}

MODULE = Linux::Netfilter::Log::Group	PACKAGE = Linux::Netfilter::Log::Group

struct perl_nflog_group* bind_group(const char *class, SV *log, uint16_t group)
	CODE:
		if(!(sv_isobject(log)
			&& sv_derived_from(log, "Linux::Netfilter::Log")
			&& SvTYPE(SvRV(log)) == SVt_PVMG))
		{
			croak("Linux::Netfilter::Log::Group->bind_group() -- log is not a Linux::Netfilter::Log");
		}

		struct nflog_handle *log_h = (struct nflog_handle*)(SvIV((SV*)SvRV(log)));

		Newxz(RETVAL, 1, struct perl_nflog_group*);

		RETVAL->g_handle = nflog_bind_group(log_h, group);
		if(RETVAL->g_handle == NULL)
		{
			int err = errno;
			Safefree(RETVAL);

			croak("nflog_bind_group: %s", strerror(err));
		}

		/* Keep a reference to the Linux::Netfilter::Log object so it
		 * can't be destroyed before us.
		*/
		SvREFCNT_inc(log);
		RETVAL->handle = log;

	OUTPUT:
		RETVAL

void DESTROY(struct perl_nflog_group *self)
	CODE:
		if(nflog_unbind_group(self->g_handle) == -1)
		{
			warn("nflog_unbind_group: %s", strerror(errno));
		}

		if(self->callback != NULL)
		{
			SvREFCNT_dec(self->callback);
		}

		SvREFCNT_dec(self->handle);

		Safefree(self);

void callback_register(struct perl_nflog_group *self, CV *cb)
	CODE:
		if(nflog_callback_register(self->g_handle, &_callback_proxy, (void*)(cb)) == -1)
		{
			croak("nflog_callback_register: %s", strerror(errno));
		}

		if(self->callback != NULL)
		{
			SvREFCNT_dec(self->callback);
		}

		SvREFCNT_inc(cb);
		self->callback = cb;

void set_mode(struct perl_nflog_group *self, uint8_t mode, uint32_t range)
	CODE:
		if(nflog_set_mode(self->g_handle, mode, range) == -1)
		{
			croak("nflog_set_mode: %s", strerror(errno));
		}

void set_nlbufsiz(struct perl_nflog_group *self, uint32_t nlbufsiz)
	CODE:
		if(nflog_set_nlbufsiz(self->g_handle, nlbufsiz) == -1)
		{
			croak("nflog_set_nlbufsiz: %s", strerror(errno));
		}

void set_qthresh(struct perl_nflog_group *self, uint32_t qthresh)
	CODE:
		if(nflog_set_qthresh(self->g_handle, qthresh) == -1)
		{
			croak("nflog_set_qthresh: %s", strerror(errno));
		}

void set_timeout(struct perl_nflog_group *self, uint32_t timeout)
	CODE:
		if(nflog_set_timeout(self->g_handle, timeout) == -1)
		{
			croak("nflog_set_timeout: %s", strerror(errno));
		}
