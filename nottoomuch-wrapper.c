#if 0 /* -*- mode: c; c-file-style: "stroustrup"; tab-width: 8; -*-
 #
 # Enter: sh nottoomuch-wrapper.c [/path/to/]notmuch
 #        in order to compile this program.
 #  Tip: enter /bin/echo as notmuch command when testing code changes...
 set -eu
 case ${1-} in '') echo "Usage: sh $0 [/path/to/]notmuch" >&2; exit 1; esac
 notmuch=$1; shift; trg=`basename "$0" .c`; rm -f "$trg"
 WARN="-Wall -Wno-long-long -Wstrict-prototypes -pedantic"
 WARN="$WARN -Wcast-align -Wpointer-arith " # -Wfloat-equal #-Werror
 WARN="$WARN -W -Wwrite-strings -Wcast-qual -Wshadow" # -Wconversion
 case ${1-} in '') set x -O2; shift; esac
 #case ${1-} in '') set x -ggdb; shift; esac
 set -x
 exec ${CC:-gcc} --std=c99 $WARN "$@" -o "$trg" "$0" -DNOTMUCH="\"$notmuch\""
 exit $?
 */
#endif
/*
 * $ nottoomuch-wrapper.c $
 *
 * Created: Tue 13 Mar 2012 12:34:26 EET too
 * Last modified: Thu 17 May 2012 15:11:09 EEST too
 */

#include <unistd.h>
#include <stdio.h>
#include <stdlib.h>
#include <stdint.h>
#include <string.h>
#include <ctype.h>
#include <time.h>

#include <sys/types.h>
#include <sys/stat.h>
#include <fcntl.h>
#include <sys/uio.h>

#define null ((void *)0)

#define WriteCS(f, s) write((f), (s), sizeof (s) - 1);

time_t gt;

static const char * get_time(const char * str, long * timep)
{
    unsigned int mult;
    char * endptr;
    long t;

    long val = strtol(str, &endptr, 10);

    /* no digits at all */
    if (endptr == str)
	return null;
    /* what to do with negative value... nothing */
    if (val < 0)
	return null;

    switch (*endptr) {
    case 'h': mult = 60;	 endptr++; break;
    case 'd': mult = 1440;	 endptr++; break;
    case 'w': mult = 7 * 1440;	 endptr++; break;
    case 'm': mult = 30 * 1440;  endptr++; break;
    case 'y': mult = 365 * 1440; endptr++; break;
    case '.':
    case ' ':
    case '\0':
	if (val < 1000) {
	    mult = 1;
	    break;
	}
	*timep = val;
	return endptr;
    default:
	return null;
    }

    t = (gt - (mult * val * 60));
    if (t < 0)
	t = 0;
    *timep = t;

    return endptr;
}

char spcstr[2] = " ";
char nlstr[2] = "\n";

int main(int argc, char * argv[])
{
    char buf[16384];
    char * p = buf;
    int i, tl = 0;
    int fd = 0; /* avoid compiler warning */

    if (argc < 3) {
	execvp(NOTMUCH, argv);
	/* not reached */
	return 1;
    }

    gt = time(null);

    if (strcmp(argv[1], "tag") == 0 || strcmp(argv[1], "search") == 0 ||
	strcmp(argv[1], "show") == 0 || strcmp(argv[1], "reply") == 0) {
	char * home = getenv("HOME");
	if (home) {
	    sprintf(buf, "%s/nottoomuch-wrapper.log", home);
	    fd = open(p, O_WRONLY|O_CREAT|O_APPEND, 0644);
	    if (fd >= 0) {
		struct tm * tm = localtime(&gt);
		tl = strftime(buf, 1024, "%Y-%m-%d (%a) %H:%M:%S:", tm);
		p += tl;
	    }
	}
    }

    /* XXX ugly hack, gained by trial & errror */
    for (i = 2; i < argc && argv[i]; i++) {
	const char * arg = argv[i];
	char * q;
	int prefixlen = 0;
	char * s = p;

	while ( (q = strstr(arg, "..")) != null) {
	    /* split into prefix(len), ltd, rtd, postdata */
	    long st = 0, tt = 0;

	    if (q - arg > 0) {
		char * r = q - 1;
		while (r != arg) {
		    if (isspace(*r)) {
			prefixlen = r - arg + 1;
			break;
		    }
		    r--;
		}
		if (r != arg && ! isspace(*r)) {
		    s = p;
		    break; /* XXX no conversions on 'error's */
		}
		if (isspace(*r))
		    r++;

		if (*r != '.') {
		    const char * ep = get_time(r, &st);
		    if (ep != q) {
			s = p;
			break; /* XXX no conversions on 'error's */
		    }
		}
	    }
	    /* right end of .. */
	    q += 2;
	    const char *ep;
	    if (*q == '\0' || isspace(*q))
		ep = q;
	    else {
		ep = get_time(q, &tt);
		if (ep == null || (*ep != '\0' && ! isspace(*ep))) {
		    s = p;
		    break; /* XXX no conversions on 'error's */
		}
	    }

	    /* if (buf + 200 - s - prefixlen - 100 < 0) { */
	    if (buf + sizeof buf - s - prefixlen - 100 < 0) {
		s = p;
		break; /* XXX data does not fit */
	    }

	    if (prefixlen) {
		memcpy(s, arg, prefixlen);
		s += prefixlen;
	    }
	    prefixlen = 1;
	    arg = ep;
	    if (st) {
		int l = snprintf(s, 20, "%ld", st);
		s += l;
	    }
	    *s++ = '.'; *s++ = '.';
	    if (tt) {
		int l = snprintf(s, 20, "%ld", tt);
		s += l;
	    }
	}
	if (s != p) {
	    if (*arg) {
		int l = strlen(arg);
		memcpy(s, arg, l);
		s += l;
	    }
	    *s++ = '\0';
#if 0
	    printf("Mangled '%s' to '%s'\n", argv[i], p);
#endif
	    argv[i] = p;
	    p = s;
	}
    }
    if (tl > 0) {
	struct iovec iov[256];
	iov[0].iov_base = buf;
	iov[0].iov_len = tl;
	for (i = 1; i < 255; i += 2) {
	    char * s = argv[i/2 + 1];
	    if (!s)
		break;
	    iov[i].iov_base = spcstr; /* " "; */
	    iov[i].iov_len = 1;
	    iov[i+1].iov_base = s;
	    iov[i+1].iov_len = strlen(s);
	}
	iov[i].iov_base = nlstr; /* "\n"; */
	iov[i++].iov_len = 1;
	writev(fd, iov, i);
	close(fd);
    }
    execvp(NOTMUCH, argv);
    return 1;
}
