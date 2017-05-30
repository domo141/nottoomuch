#if 0 /* -*- mode: c; c-file-style: "stroustrup"; tab-width: 8; -*-
 set -eu; trg=`exec basename "$0" .c`; rm -f "$trg"
 WARN="-Wall -Wstrict-prototypes -Winit-self -Wformat=2" # -pedantic
 WARN="$WARN -Wcast-align -Wpointer-arith " # -Wfloat-equal #-Werror
 WARN="$WARN -Wextra -Wwrite-strings -Wcast-qual -Wshadow" # -Wconversion
 WARN="$WARN -Wmissing-include-dirs -Wundef -Wbad-function-cast -Wlogical-op"
 WARN="$WARN -Waggregate-return -Wold-style-definition"
 WARN="$WARN -Wmissing-prototypes -Wmissing-declarations -Wredundant-decls"
 WARN="$WARN -Wnested-externs -Winline -Wvla -Woverlength-strings -Wpadded"
#FLAGS=`{ pkg-config --cflags --libs fuse || kill $$;} | sed 's/-I/-isystem '/g`
 FLAGS=`pkg-config --cflags --libs fuse | sed 's/-I/-isystem '/g`
#FLAGS=`pkg-config --cflags --libs fuse`
 case ${1-} in '') set x -O2; shift; esac
 #case ${1-} in '') set x -ggdb; shift; esac
#set -x; exec ${CC:-gcc} -std=c99 $WARN $FLAGS "$@" -o "$trg" "$0"
 set -x; exec ${CC:-gcc} -std=c99 $WARN "$@" -o "$trg" "$0" $FLAGS
 exit $?
 # Note: $FLAGS last to avoid  "undefined reference to `fuse_main_real'"
 */
#endif
/*
 * $  mboxviewfs.c  1.1  2017-01-22  $
 *
 * Author: Tomi Ollila -- too ät iki piste fi
 *
 *      Copyright (c) 2014 Tomi Ollila
 *          All rights reserved
 *
 * Created: Sun Oct 5 10:45:49 2014 +0300 too
 * Last modified: Sun 22 Jan 2017 22:11:28 +0200 too
 */

/* LICENSE: 2-clause BSD license ("Simplified BSD License"):

  Redistribution and use in source and binary forms, with or without
  modification, are permitted provided that the following conditions
  are met:

  1. Redistributions of source code must retain the above copyright
     notice, this list of conditions and the following disclaimer.

  2. Redistributions in binary form must reproduce the above copyright
     notice, this list of conditions and the following disclaimer in the
     documentation and/or other materials provided with the distribution.

  THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
  AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO,
  THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR
  PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR
  CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL,
  EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO,
  PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR
  PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF
  LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING
  NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
  SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
*/

// dir/file search routines got too hairy in the course of evolution... ;) //
// i.e. that part to be restructured in case there is much more to be done //

//#define _XOPEN_SOURCE // for strptime
#define _XOPEN_SOURCE 600 // ... for strptime and timerspec when -std=c99

#include <unistd.h>
#include <stdio.h>
#include <string.h>
#include <strings.h> // for strncasecmp
#include <stdlib.h>
#include <stdarg.h>
#include <stdint.h>
#include <ctype.h>
#include <errno.h>
#include <fcntl.h>
#include <time.h>

#include <sys/types.h>
#include <sys/stat.h>

#include <pthread.h>

#define FUSE_USE_VERSION 26
#include <fuse.h>

#define null ((void*)0)
enum { false = 0, true = 1 };

#if (__GNUC__ >= 4)
#define GCCATTR_SENTINEL __attribute ((sentinel))
#else
#define GCCATTR_SENTINEL
#endif

#if (__GNUC__ >= 3)
#define GCCATTR_NORETURN __attribute ((noreturn))
#define GCCATTR_UNUSED   __attribute ((unused))
#else
#define GCCATTR_NORETURN
#define GCCATTR_UNUSED
#endif

// (variable) block begin/end -- explicit liveness...
#define BB {
#define BE }

#define DEBUG 0
#if DEBUG
#define d1(format, ...) \
    fprintf(stderr, "%d:%s " format "\n", __LINE__, __func__, __VA_ARGS__)
//#define d0 d1
#define d0(format, ...) do { } while (0)
#define d1x(x) do { x; } while (0)
#define d0x(x) do {} while (0)
#else
#define d1(format, ...) do {} while (0)
#define d0(format, ...) do {} while (0)
#define d1x(x) do {} while (0)
#define d0x(x) do {} while (0)
#endif
#define da(format, ...) \
    fprintf(stderr, "%d:%s " format "\n", __LINE__, __func__, __VA_ARGS__)

#define xassert_eq(a, b) do { if ((a) != (b)) { fprintf(stderr, #a "(%jd) != " #b "(%jd)\n", (intmax_t)(a), (intmax_t)(b)); exit(1); }} while (0)

// set to 0 to and go through all warnings whether all vars are really unused //
#if 1
#define UU(x) (void)x
#else
#define UU(x) (void)x; x
#endif

typedef struct {
    off_t offset; // offset in mbox file
    int16_t year;
    int8_t mon;
    int8_t mday;
    int8_t hour;
    int8_t min;
    int8_t sec;
    int8_t xqho; // +- quarter-hours (900secs) from utc -- for file [amc]time:s
} FileEntry;

typedef struct {
    size_t index; // index in yearmona "array"
    int16_t year;
    int8_t mon;
    int8_t mday;
    int8_t hour;
    int8_t min;
    int8_t sec;
    int8_t xqho; // +- quarter-hours (900secs) from utc -- for file [amc]time:s
} DirEntry;


const struct {
    mode_t dirmode;
    mode_t filemode;
    time_t time_t_small; // small enough, risks & warnings when shifting 1 more
} C = {
    .dirmode  = S_IFDIR | 0555,
    .filemode = S_IFREG | 0444,
    .time_t_small = -((time_t)1 << (8 * sizeof (time_t) - 2)),
};

struct {
    const char * prgname;
    int fd;
    int32_t pad1_unused;
    off_t mboxsize;
    size_t mailc;
    FileEntry * maila;
    size_t * maili;
    unsigned yearmonc;
    int32_t pad2_unused;
    DirEntry * yearmona;
    unsigned lastdirindex;
    int32_t pad3_unused;
    time_t ht;
    uid_t uid;
    gid_t gid;
} G;

static void init_G(const char * prgname)
{
    G.prgname = prgname;

    // compiler optimizes these asserts (of constants) away in case succeeds //
    // currently, there is one DirEntry -> FileEntry typecast in the code...
    xassert_eq(&((FileEntry *)0)->year, &((DirEntry *)0)->year);
    xassert_eq(&((FileEntry *)0)->mon,  &((DirEntry *)0)->mon);
    xassert_eq(&((FileEntry *)0)->mday, &((DirEntry *)0)->mday);
    xassert_eq(&((FileEntry *)0)->hour, &((DirEntry *)0)->hour);
    xassert_eq(&((FileEntry *)0)->min,  &((DirEntry *)0)->min);
    xassert_eq(&((FileEntry *)0)->sec,  &((DirEntry *)0)->sec);
    xassert_eq(&((FileEntry *)0)->xqho, &((DirEntry *)0)->xqho);

    d0("sizeof (time_t): %lu", sizeof (time_t));
    xassert_eq(sizeof (time_t), 8);
    xassert_eq(sizeof (long), 8);

    G.uid = getuid();
    G.gid = getgid();
}

// this is modeled after my_timegm() (minor edits + no tm_isdst use) in
// *** http://www.catb.org/esr/time-programming/ ***
static inline time_t xtimegm(struct tm * tm)
{
    static const int cumdays[12] = {0,31,59,90,120,151,181,212,243,273,304,334};

    long year = 1900 + tm->tm_year + tm->tm_mon / 12;
    time_t result = (year - 1970) * 365 + cumdays[tm->tm_mon % 12];
    result += year / 4 - year / 100 + year / 400 - 477; // 1970 / 4 - ... = 477
    if ((year % 4) == 0 && ((year % 100) != 0 || (year % 400) == 0)
        && (tm->tm_mon % 12) < 2)
        result--;
    result += tm->tm_mday - 1;   result *= 24;
    result += tm->tm_hour;       result *= 60;
    result += tm->tm_min;        result *= 60;
    result += tm->tm_sec;
    //if (tm->tm_isdst == 1) result -= 3600;

    d0("%d-%02d-%02d %02d:%02d:%02d -- %jd", tm->tm_year + 1900, tm->tm_mon + 1,
       tm->tm_mday, tm->tm_hour, tm->tm_min, tm->tm_sec, result);

    return result;
}

static time_t fetime(FileEntry * fe)
{
    struct tm tm = {
        .tm_year = fe->year, .tm_mon = fe->mon, .tm_mday = fe->mday,
        .tm_hour = fe->hour, .tm_min = fe->min, .tm_sec = fe->sec,
    };
    d0("%d %d", fe->xqho, fe->xqho * 900);
#if defined (MKTIME_ME_HARDER) && MKTIME_ME_HARDER
    (void)mktime(&tm);
    d0("%d, %d", tm.tm_year + 1900, tm.tm_yday);
    return (time_t)(tm.tm_year - 70) * 31536000
//      + ((tm.tm_year-101)/4 - (tm.tm_year-101)/100 + (tm.tm_year-101)/400 + 8)
        + ((tm.tm_year+1899)/4-(tm.tm_year+1899)/100+(tm.tm_year+1899)/400-477)
        * 86400 + tm.tm_yday * 86400
        + tm.tm_hour * 3600 + tm.tm_min * 60 + tm.tm_sec - tm.tm_isdst * 3600
        - fe->xqho * 900;
#else
    return xtimegm(&tm) - fe->xqho * 900;
    //return timegm(&tm) - fe->xqho * 900;
#endif
}

static DirEntry * finddir(int16_t year, int8_t mon)
{
    d1("(%d, %d)", year + 1900, mon + 1);
    BB;
    // remember that this block needs to be thread-safe //
    unsigned o = G.lastdirindex;
    FileEntry * fe = &G.maila[G.maili[G.yearmona[o].index]];
    d1("(%u) %d,%d", o, fe->year + 1900, fe->mon + 1);
    if  (fe->year == year && fe->mon == mon)
        return &G.yearmona[o];
    // often it is also potentially next one //
    // note: for this an extra item has been added to the yearmona array.
    fe = &G.maila[G.maili[G.yearmona[o + 1].index]];
    d1("(%u) %d,%d", o+1, fe->year + 1900, fe->mon + 1);
    if  (fe->year == year && fe->mon == mon) {
        G.lastdirindex = o + 1;
        return &G.yearmona[o + 1];
    }
    BE;

    // binary search //
    unsigned min = 0, max = G.yearmonc;
     do {
        int o = (max + min) / 2;
        FileEntry * fe = &G.maila[G.maili[G.yearmona[o].index]];
        d1("%d -- %d %d - %d %d", o, year, mon, fe->year, fe->mon);
        if  (fe->year < year || (fe->year == year && fe->mon < mon)) {
            min = o + 1;
        }
        else if (fe->year > year || (fe->year == year && fe->mon > mon)) {
            max = o - 1;
        }
        else {
            G.lastdirindex = o;
            return &G.yearmona[o];
        }
    } while (max >= min);

    d1("(%d, %d) -- not found", year, mon);
    return null;
}

static inline FileEntry * findfile(const char * path)
{
    size_t i = 0;
    while (1) {
        char c = *++path;
        if (c >= '0' && c <= '9')
            i = (i << 4) + c - '0';
        else if (c >= 'a' && c <= 'f')
            i = (i << 4) + c - 'a' + 10;
        else if (c == '\0')
            break;
        else
            return null;
    }
    if (i >= G.mailc)
        return null;

    return &G.maila[i];
}

#if 0
int xisdigit(int c) { d1("%c", c); return (c >= '0' && c <= '9'); }
#undef isdigit
#define isdigit xisdigit
#endif

#define PASS_YYYY_MM_OR_RETURN_ENOENT(path) \
    if (! isdigit(*path++) || ! isdigit(*path++) || ! isdigit(*path++) \
        || ! isdigit(*path++) \
        || *path++ != '-' || ! isdigit(*path++) || ! isdigit(*path++)) \
    return -ENOENT

static int mbox_getattr(const char * path, struct stat * st)
{
    d0("(\"%s\", %p)", path, (void*)st);

    // consistency check //
    if (*path++ != '/') return -ENOENT;

    st->st_uid = G.uid;
    st->st_gid = G.gid;

    if (*path == '\0') { // root dir
        st->st_atime = st->st_mtime = st->st_ctime = G.ht;
        st->st_nlink = G.yearmonc + 2;
        st->st_mode = C.dirmode;
        st->st_size = 4096;
        st->st_ino = 0x3758;
        return 0;
    }
    // pass yyyy-mm
    PASS_YYYY_MM_OR_RETURN_ENOENT(path);

    // directory?
    if (*path == '\0') {
        int16_t year = atoi(path - 7) - 1900;
        int8_t mon = atoi(path - 2) - 1;
        DirEntry * de = finddir(year, mon);
        if (de == null)
            return -ENOENT;
        st->st_atime = st->st_mtime = st->st_ctime = fetime((FileEntry *)de);
        st->st_nlink = 2;
        st->st_mode = C.dirmode;
        st->st_size = 4096;
        st->st_ino = (year + 1900) * 100 + mon + 1;
        return 0;
    }
    if (*path == '/') {
        size_t i = 0;
        while (1) {
            char c = *++path;
            if (c >= '0' && c <= '9')
                i = (i << 4) + c - '0';
            else if (c >= 'a' && c <= 'f')
                i = (i << 4) + c - 'a' + 10;
            else if (c == '\0')
                break;
            else
                return -ENOENT;
        }
        if (i >= G.mailc)
            return -ENOENT;
        FileEntry * fe = &G.maila[i];
        st->st_atime = st->st_mtime = st->st_ctime = fetime(fe);
        st->st_nlink = 1;
        st->st_mode = C.filemode;
        st->st_size = fe[1].offset - fe[0].offset;
        st->st_ino = 1e6 + i;
        return 0;
    }
    return -ENOENT;
}

static int mbox_readdir(const char * path, void * buf, fuse_fill_dir_t filler,
                        off_t offset, struct fuse_file_info * fi)
{
    d1("(\"%s\", %p, %ld)", path, buf, offset);

    UU(offset);
    UU(fi);

    // consistency check //
    if (*path++ != '/') return -ENOENT;

    if (*path == '\0') { // root dir
        filler(buf, ".",  null, 0);
        filler(buf, "..",  null, 0);
        for (unsigned i = 0; i < G.yearmonc; i++) {
            char ym[8];
            FileEntry * fe = &G.maila[G.maili[G.yearmona[i].index]];
            snprintf(ym, sizeof ym, "%d-%02d", fe->year + 1900, fe->mon + 1);
            d0("%s", ym);
            filler(buf, ym, null, 0);
        }
        return 0;
    }
    // pass yyyy-mm
    PASS_YYYY_MM_OR_RETURN_ENOENT(path);

    if (*path == '\0') {
        int16_t year = atoi(path - 7) - 1900;
        int8_t mon = atoi(path - 2) - 1;
        DirEntry * de = finddir(year, mon);
        if (de == null)
            return -ENOENT;
        filler(buf, ".",  null, 0);
        filler(buf, "..",  null, 0);
        for (size_t i = de->index; i < G.mailc; i++) {
            size_t fn = G.maili[i];
            FileEntry * fe = &G.maila[fn];
            d1("i: %ld fn: %ld,  fe->year %d year %d  fe->mon %d mon %d",
               i, fn, fe->year, year, fe->mon, mon);
            if (fe->year != year || fe->mon != mon)
                break;
            char fname[20];
            if (fn >= ((size_t)1 << 32))
                snprintf(fname, sizeof fname, "%016lx", (uint64_t)fn);
            else
                snprintf(fname, sizeof fname, "%08x", (uint32_t)fn);
            filler(buf, fname, null, 0);
        }
        return 0;
    }
    return -ENOENT;
}

static int mbox_open(const char * path, struct fuse_file_info * fi)
{
    UU(fi);
    d1("(\"%s\")", path);

    // consistency check //
    if (*path++ != '/') return -ENOENT;

    // pass yyyy-mm
    PASS_YYYY_MM_OR_RETURN_ENOENT(path);

    FileEntry * fe = findfile(path);
    if (fe == null) return -ENOENT;

    return 0;
}

static int mbox_read(const char * path, char * buf, size_t size, off_t offset,
                     struct fuse_file_info * fi)
{
    UU(fi);
    d1("(\"%s\", %d, %ld)", path, (int)size, offset);

    // consistency check //
    if (*path++ != '/') return -ENOENT;

    // pass yyyy-mm
    PASS_YYYY_MM_OR_RETURN_ENOENT(path);

    FileEntry * fe = findfile(path);
    if (fe == null) return -ENOENT;
    size_t fs = fe[1].offset - fe[0].offset;
    if (offset < 0 || offset > (off_t)fs)
        return -EINVAL;
    if (size + offset > fs)
        size = fs - offset;
    if (lseek(G.fd, fe[0].offset + offset, SEEK_SET) < 0)
        return -errno;
    ssize_t rv = read(G.fd, buf, size);
    if (rv >= 0)
        return rv;
    return -errno;
}

static int mbox_statfs(const char * path, struct statvfs * stvfs)
{
    UU(path);
    d1("(\"%s\")", path);

    stvfs->f_bsize = 4096;
    stvfs->f_blocks = (G.mboxsize + 4095) / 4096; // *this* is needed for df(1)
    stvfs->f_bfree = 0;
    stvfs->f_bavail = 0;
    stvfs->f_files = G.mailc + G.yearmonc;
    stvfs->f_ffree = 0;
    //stvfs->f_favail = 0;
    //stvfs->f_flag = ST_RDONLY;
    stvfs->f_namemax = 32;

    return 0;
}

static struct fuse_operations mbox_oper = {
    .getattr    = mbox_getattr,
    .readdir    = mbox_readdir,
    .open       = mbox_open,
    .read       = mbox_read,
    .statfs     = mbox_statfs
};

const uint8_t ESTR[] = { 128, 0 };

void diev(const char * str, ...) GCCATTR_SENTINEL GCCATTR_NORETURN;
void diev(const char * str, ...)
{
    struct iovec iov[16];
    va_list ap;
    int errnum = errno;

    va_start(ap, str);
    *(const char **)&(iov[0].iov_base) = str;
    iov[0].iov_len = strlen(str);

    int i = 1;
    for (char * s = va_arg(ap, char *); s; s = va_arg(ap, char *)) {
        if (i == sizeof iov / sizeof iov[0])
            break;
        iov[i].iov_base = s;
        iov[i].iov_len = strlen(s);
        i++;
    }
    if (iov[i-1].iov_len == 1 && ((uint8_t *)(iov[i-1].iov_base))[0] == 128) {
        iov[i-1].iov_base = strerror(errnum);
        iov[i-1].iov_len = strlen(iov[i-1].iov_base);
    }
    /* for writev(), iov[n].iov_base is const */
    *(const char **)&(iov[i].iov_base) = ".\n";
    iov[i].iov_len = 2;
    i++;
#if (__GNUC__ >= 4 && ! (defined (__clang__) && __clang__) )
    { ssize_t __i = writev(2, iov, i); (void)(__i = __i); }
#else
    (void)writev(2, iov, i);
#endif
    exit(1);
}

static int scan_tzo(const char * p)
{
    // up to +- 29h, 99m ;) //
    int hh = p[1] - '0'; if (hh < 0 || hh > 2)  return 0;
    int hl = p[2] - '0'; if (hl < 0 || hl > 9)  return 0;
    int mh = p[3] - '0'; if (mh < 0 || mh > 9)  return 0;
    int ml = p[4] - '0'; if (ml < 0 || ml > 9)  return 0;
    if (p[5] != '\0' && ! isspace(p[5]))        return 0;
    d1("(%.5s): %d %d %d %d", p, hh, hl, mh, ml);
    return (p[0] == '-') ?
        -((hh * 10 + hl) * 3600 + (mh * 10 + ml) * 60) :
        +((hh * 10 + hl) * 3600 + (mh * 10 + ml) * 60) ;
}

static inline void skipnonspace(const char ** p)
{
    while (**p && !isspace(**p)) (*p)++;
}

// last resort, best heuristics w/o error checking
static int last_resort_get_tm(const char * string, struct tm * tm)
{
//    for (;; while (*string && !isspace(*string)) string++)) {
    for (;; skipnonspace(&string)) {
        while (isspace(*string)) string++;
        if (*string == '\0')
            break;
        unsigned hour, min, sec;
        if (sscanf(string, "%2u:%2u:%2u", &hour, &min, &sec) == 3) {
            tm->tm_hour = hour; tm->tm_min = min; tm->tm_sec = sec;
            continue;
        }
        if (*string == '+' || *string == '-') {
            tm->tm_yday = scan_tzo(string); // yday used as storage location //
            continue;
        }

        int i = atoi(string);
        if (i > 0) {
            d1("--- %d ---", i);
            // Date info may have tm y2k bug -- therefore somewhat funny
            // heuristic is close to when 32-bit unsigned time_t wraps...
            // perl -le 'print scalar localtime 1 << 32' -> 2106...
            if (i >= 200)  { tm->tm_year = i - 1900; continue; }
            if (i > 31)    { tm->tm_year = i; continue; }
            tm->tm_mday = i; continue;
        }
        int mon;
        switch (string[0]) {
        case 'J':
            if (strncasecmp(string, "Jan", 3) == 0) { mon =  0; break; }
            if (strncasecmp(string, "Jun", 3) == 0) { mon =  5; break; }
            if (strncasecmp(string, "Jul", 3) == 0) { mon =  6; break; }
            continue;
        case 'F':
            if (strncasecmp(string, "Feb", 3) == 0) { mon =  1; break; }
            continue;
        case 'M':
            if (strncasecmp(string, "Mar", 3) == 0) { mon =  2; break; }
            if (strncasecmp(string, "May", 3) == 0) { mon =  4; break; }
            continue;
        case 'A':
            if (strncasecmp(string, "Apr", 3) == 0) { mon =  3; break; }
            if (strncasecmp(string, "Aug", 3) == 0) { mon =  7; break; }
            continue;
        case 'S':
            if (strncasecmp(string, "Sep", 3) == 0) { mon =  8; break; }
            continue;
        case 'O':
            if (strncasecmp(string, "Oct", 3) == 0) { mon =  9; break; }
            continue;
        case 'N':
            if (strncasecmp(string, "Nov", 3) == 0) { mon = 10; break; }
            continue;
        case 'D':
            if (strncasecmp(string, "Dec", 3) == 0) { mon = 11; break; }
        default:
            continue;
        }
        if (! isalpha(string[3])) tm->tm_mon = mon;
    }
    d1("%d %d %d %d %d %d", tm->tm_sec, tm->tm_min, tm->tm_hour,
            tm->tm_mday, tm->tm_mon + 1, tm->tm_year + 1900);

    if (tm->tm_mday > 0 && tm->tm_mon >= 0 && tm->tm_year >= 0
        && tm->tm_sec >= 0)
        return true;
    //tm->tm_mday = 0;
    return false;
}

static int _gettm(const char * string, struct tm * tm)
{
    const char * p = strptime(string, "%a, %d %b %Y %T", tm);
    if (p == null)
        return last_resort_get_tm(string, tm);
    d1("%d %d %d %d %d %d", tm->tm_sec, tm->tm_min, tm->tm_hour,
            tm->tm_mday, tm->tm_mon + 1, tm->tm_year + 1900);
    while (isspace(*p)) p++;
    if (*p == '+' || *p == '-')
        tm->tm_yday = scan_tzo(p);  // yday used as storage location //
    else
        tm->tm_yday = 0;
    return true;
}

/* ************************* lineread.c ************************* */
/*
 * lineread.c - functions to read lines from fd:s efficiently
 *
 * Created: Mon Jan 14 06:45:00 1991 too
 */

struct lineread
{
  char *  currp;         /* current scan point in buffer */
  char *  endp;          /* pointer of last read character in buffer */
  char *  startp;        /* pointer to start of output */
  char *  sizep;         /* pointer to the end of read buffer */
  int     fd;            /* input file descriptor */
  char    selected;      /* has caller done select()/poll() or does he care */
  char    line_completed;/* line completion in LineRead */
  uint8_t saved;         /* saved char in LineRead */
  uint8_t pad_unused;
  char    data[32768];   /* the data buffer... */
};
typedef struct lineread LineRead;

static int lineread(LineRead * lr, char ** ptr)
{
  int i;

  if (lr->currp == lr->endp)

    if (lr->selected)   /* user called select() (or wants to block) */
    {
      if (lr->line_completed)
        lr->startp = lr->currp = lr->data;

      if ((i = read(lr->fd,
                    lr->currp,
                    lr->sizep - lr->currp)) <= 0) {
        /*
         * here if end-of-file or on error. set endp == currp
         * so if non-blocking I/O is in use next call will go to read()
         */
        lr->endp = lr->currp;
        *ptr = (char *)(intptr_t)i; /* user compares ptr (NULL, (char *)-1, ... */
        return -1;
      }
      else
        lr->endp = lr->currp + i;
    }
    else /* Inform user that next call may block (unless select()ed) */
    {
      lr->selected = true;
      return 0;
    }
  else /* currp has not reached endp yet. */
  {
    *lr->currp = lr->saved;
    lr->startp = lr->currp;
  }

  /*
   * Scan read string for next newline.
   */
  while (lr->currp < lr->endp)
    if (*lr->currp++ == '\n')  /* memchr ? (or rawmemchr & extra \n at end) */
    {
      lr->line_completed = true;
      lr->saved = *lr->currp;
      *lr->currp = '\0';
      lr->selected = false;
      *ptr = lr->startp;

      return lr->currp - lr->startp;
    }

  /*
   * Here if currp == endp, but no NLCHAR found.
   */
  lr->selected = true;

  if (lr->currp == lr->sizep) {
    /*
     * Here if currp reaches end-of-buffer (endp is there also).
     */
    if (lr->startp == lr->data) /* (data buffer too short for whole string) */
    {
      lr->line_completed = true;
      *ptr = lr->data;
      *lr->currp = '\0';
      return -1;
    }
    /*
     * Copy partial string to start-of-buffer and make control ready for
     * filling rest of buffer when next call to lineread() is made
     * (perhaps after select()).
     */
    memmove(lr->data, lr->startp, lr->endp - lr->startp);
    lr->endp-=  (lr->startp - lr->data);
    lr->currp = lr->endp;
    lr->startp = lr->data;
  }

  lr->line_completed = false;
  return 0;
}

static void lineread_init(LineRead * lr, int fd)
{
  lr->fd = fd;
  lr->currp = lr->endp = NULL; /* any value works */
  lr->sizep = lr->data + sizeof lr->data;
  lr->selected = lr->line_completed = true;
}

/* ^^^^^^^^^^^^^^^^^^^^^^^^^ lineread.c ^^^^^^^^^^^^^^^^^^^^^^^^^ */

static void * xrealloc(void * ptr, size_t size)
{
    ptr = realloc(ptr, size);
    if (ptr == null)
        diev("Memory allocation failed:", ESTR, null);
    return ptr;
}

static void addmail(off_t pos, struct tm * tm)
{
    # define MASIZE 1000
    if (G.mailc % MASIZE == 0) {
        G.maila = xrealloc(G.maila, (G.mailc + MASIZE) * sizeof (FileEntry));
        d0("%p %lu", (void *)G.maila, G.mailc);
    }
    FileEntry * fe = G.maila + G.mailc++;
    fe->offset = pos;
    fe->year = tm->tm_year; fe->mon = tm->tm_mon; fe->mday = tm->tm_mday;
    fe->hour = tm->tm_hour; fe->min = tm->tm_min; fe->sec  = tm->tm_sec;
    fe->xqho = tm->tm_yday / 900;

    if (fe->year > 8098) fe->year = 8098;

    d0("off %ld, time: ", pos);
    d0("%04lx: %d-%02d-%02d %02d:%02d:%02d", G.mailc - 1,
           fe->year + 1900, fe->mon + 1, fe->mday,
           fe->hour, fe->min, fe->sec);
}

// The purpose of this sorting it to get all mail belonging to year-mo
// to follow each other. In the dir those need to be in the order appended
// to the mbox (so that every later "arrived", but earlier time will add one
// second to the directory times. Future implementation change must have same
// or similar feature where every added mail to a directory will cause direc-
// tory timestamt to change.
static int sortmaili(const void * aa, const void * bb)
//int sortmaili(off_t * a, off_t * b)
//int sortmail(const FileEntry * a, const FileEntry * b)
{
    const FileEntry * a = G.maila + *(const size_t *)aa;
    const FileEntry * b = G.maila + *(const size_t *)bb;

# define cl(f) if (a->f != b->f) return a->f - b->f
    cl(year); cl(mon);
    // in a directory, keep files in closer to original order where
    // message in smaller offset is kept in smaller index.
    // these values are 64 bits wide -- and definitely different //
    // return (a->offset < b->offset)? -1: 1;
    // and so are just a & b
    return (a < b)? -1: 1;
}

static void scan_mbox(const char * mboxfile)
{
    BB;
    int fd = open(mboxfile, O_RDONLY);
    if (fd < 0)
        diev("Opening '", mboxfile, "' failed: ", ESTR, null);
    G.fd = fd;
    BE;
    off_t frompos = -1;
    struct tm tm;
    off_t pos = 0;
    int hdrline = 0;
    BB;
    LineRead lr;
    lineread_init(&lr, G.fd);
    while (1) {
        int l; char * lp;
        for (; (l = lineread(&lr, &lp)) > 0; pos += l) {
            if (frompos < 0) {
                if (memcmp(lp, "From ", 5) == 0) {
                    frompos = pos;
                    memset(&tm, 0, sizeof tm);
                    (void)_gettm(lp + 5, &tm);
                    hdrline = 0;
                }
                continue;
            }
            // else
            // XXX expect full date being in one line, w/ the header //
            if (strncasecmp(lp, "Date:", 5) == 0) {
                char * p = lp + 5;
                while (isspace(*p)) p++;
                if (*p)
                    (void)_gettm(p, &tm);
                addmail(frompos, &tm);
                frompos = -1;
                continue;
            }
            if (! hdrline) {
                char *p = lp;
                // check header field -- format in rfc 2822, section 2.2 //
                while (*p != ':' && *p >= 33 && *p <= 126)
                    p++;
                if (*p == ':')
                    hdrline = 1;
                else
                    frompos = -1;
                continue;
            }
            // XXX could check continuation lines for dates in case we don't
            // have date yet. Also we could allow email if there is some
            // date at the end of 'From ' line.
            if (isblank(lp[0]))
                continue;
            char *p = lp;
            // check header field -- format in rfc 2822, section 2.2 //
            // ... this takes care of "end-of-headers", too...
            while (*p != ':' && *p >= 33 && *p <= 126)
                p++;
            if (*p != ':')
                // XXX here we could check whether there is enough headers to
                // XXX consider this as email -- i.e. no Date: header was found
                frompos = -1;
            //write(1, lp, l);
        }
        if (l < 0) break;
        // and when l == 0, just continue to lineread next buffer full of data
    }
    BE;
    // add eof position to yet one entry //
    memset(&tm, 0, sizeof tm);
    addmail(pos, &tm);
    G.mailc--;
    G.mboxsize = pos;
    //printf("%d %d\n", G.mailc, sizeof (time_t));
    // create offset list and sort these date based...
    // this is getting a bit complicated -- restructure...
    G.maili = xrealloc(null, G.mailc * sizeof (off_t));
    for (size_t i = 0; i < G.mailc; i++)
        G.maili[i] = i;
    qsort(G.maili, G.mailc, sizeof (size_t), sortmaili);
    //for (int i = 0; i < 120; i++) printf("%d %ld\n", i, G.maili[i]); exit(0);
    int mon = -1;
    time_t ht = C.time_t_small;
    off_t bw = 0;
    FileEntry * ref = null;
    for (size_t i = 0; i < G.mailc; i++) {
        if (mon != G.maila[G.maili[i]].mon) {
#define YMSIZE 60 // 5 years
            if (G.yearmonc > 0) {
                DirEntry * pd = &G.yearmona[G.yearmonc-1];
                pd->year = ref->year; pd->mon = ref->mon; pd->mday = ref->mday;
                pd->hour = ref->hour; pd->min = ref->min; pd->sec = ref->sec;
                d0("%d-%02d %ld", pd->year + 1900, pd->mon + 1, bw);
                pd->sec += bw % 60;
                if (bw > 60) { bw /= 60; pd->min += bw % 60;
                    if (bw > 60) { bw /= 60; pd->min += bw % 24;
                        if (bw > 24) { bw /= 24; pd->min += bw % 200; }}}
                bw = 0;
                pd->xqho = ref->xqho;
            }
            if (G.yearmonc % YMSIZE == 0) {
                G.yearmona = xrealloc(G.yearmona, (G.yearmonc + YMSIZE)
                                      * sizeof (DirEntry));
            }
            G.yearmona[G.yearmonc++].index = i;
            d0("%d %d", G.maila[i].year, G.maila[i].mon);
            mon = G.maila[G.maili[i]].mon;
            ht = C.time_t_small;
        }
        FileEntry * pref = &G.maila[G.maili[i]];
        time_t pt = fetime(pref);
        d0("%ld %ld %ld", pt, ht, pt - ht);
        if (pt > ht) {
            ref = pref;
            bw-= (pt - ht - 1);
            if (bw < 0) bw = 0; // else da("bw %ld", bw);
            ht = pt;
        }
        else bw++; // cumulatively adding sec to dir timestamp when ...
    }
    G.ht = ht + bw;
    if (G.yearmonc >= 2) { // XXX add testcase(s)
        time_t pt = fetime( (FileEntry *)&G.yearmona[G.yearmonc-2]);
        if (pt > G.ht) G.ht = pt;
    }
    if (mon >= 0) {
        DirEntry * pd = &G.yearmona[G.yearmonc-1];
        pd->year = ref->year; pd->mon = ref->mon; pd->mday = ref->mday;
        pd->hour = ref->hour; pd->min = ref->min; pd->sec = ref->sec;
        d0("%d-%d %ld", pd->year + 1900, pd->mon + 1, bw);
        pd->sec += bw % 60;
        if (bw > 60) { bw /= 60; pd->min += bw % 60;
            if (bw > 60) { bw /= 60; pd->min += bw % 24;
                if (bw > 24) { bw /= 24; pd->min += bw % 222; }}}
        pd->xqho = ref->xqho;
    }
    // and extra item for finddir optimization
    if (G.yearmonc % YMSIZE == 0) {
        G.yearmona = xrealloc(G.yearmona, (G.yearmonc + YMSIZE)
                              * sizeof (DirEntry));
    }
    // extra item to be duplicate of previous to be sure it doesn't match... //
    memcpy(G.yearmona+G.yearmonc, G.yearmona+G.yearmonc-1, sizeof (DirEntry));
}

int main(int argc, char * argv[])
{
    if (argc > 1 && argv[1][0] == '-' &&
        (strcmp(argv[1], "-h") == 0 || strcmp(argv[1], "--help") == 0)) {
        // XXX first line (the usage line) lacks 'mbox-file' part :(
        return fuse_main(2, argv, null, null);
    }
    init_G(argv[0]);
    if (argc < 3)
        diev("Usage: ", argv[0], " mbox-file mountpoint [fuse options]", null);
    BB;
    struct stat st;
    if (stat(argv[1], &st) < 0)
        diev("Cannot access file ", argv[1], ": ", ESTR, null);
    if (! S_ISREG(st.st_mode))
        diev("File '", argv[1], "' is not (regular) file", null);
    if (stat(argv[2], &st) < 0)
        diev("Cannot access directory ", argv[2], ": ", ESTR, null);
    if (! S_ISDIR(st.st_mode))
        diev("File '", argv[2], "' is not directory", null);
    BE;
    scan_mbox(argv[1]);

    // I've spent enough time trying to understand this argument stuff...
    // Now, just move filename to argv[0] (to be seen in df output)
    // and put -ouse_ino arg in the old place of filename (argv[1] that is).
    char * fn = strrchr(argv[1], '/');
    if (fn == null) fn = argv[1];
    else fn+= 1;
    argv[0] = fn; char a[] = "-ouse_ino"; argv[1] = a;

    return fuse_main(argc, argv, &mbox_oper, null);
}
