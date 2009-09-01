import numpy
import struct
import os
cimport numpy
cdef extern from "unistd.h":
   int read(int fd, void *buf, int count)
    
cdef extern from "inttypes.h":
    ctypedef int uint32_t
    ctypedef int uint64_t
    ctypedef int uint16_t

cdef struct blk_io_trace:
      uint32_t magic    #            /* MAGIC << 8 | version */
      uint32_t sequence #         /* event number */
      uint64_t time     #             /* in nanoseconds */
      uint64_t sector   #           /* disk offset */
      uint32_t bytes    #            /* transfer length */
      uint32_t action   #           /* what happened */
      uint32_t pid      #              /* who did it */
      uint32_t device   #           /* device identifier (dev_t) */
      uint32_t cpu      #              /* on what cpu did it happen */
      uint16_t error    #            /* completion error */
      uint16_t pdu_len  #          /* length of data after this trace */

cdef int BLK_TC_SHIFT = 16
cdef unsigned int BLK_TC_ACT(unsigned int act):
    return act << BLK_TC_SHIFT

cdef unsigned int BLK_TC_READ     = 1 << 0      # /* reads */
cdef unsigned int BLK_TC_WRITE    = 1 << 1      # /* writes */
cdef unsigned int BLK_TC_BARRIER  = 1 << 2      # /* barrier */
cdef unsigned int BLK_TC_SYNC     = 1 << 3      # /* sync */
cdef unsigned int BLK_TC_QUEUE    = 1 << 4      # /* queueing/merging */
cdef unsigned int BLK_TC_REQUEUE  = 1 << 5      # /* requeueing */
cdef unsigned int BLK_TC_ISSUE    = 1 << 6      # /* issue */
cdef unsigned int BLK_TC_COMPLETE = 1 << 7      # /* completions */
cdef unsigned int BLK_TC_FS       = 1 << 8      # /* fs requests */
cdef unsigned int BLK_TC_PC       = 1 << 9      # /* pc requests */
cdef unsigned int BLK_TC_NOTIFY   = 1 << 10     # /* special message */
cdef unsigned int BLK_TC_AHEAD    = 1 << 11     # /* readahead */
cdef unsigned int BLK_TC_META     = 1 << 12     # /* metadata */
cdef unsigned int BLK_TC_DISCARD  = 1 << 13     # /* discard requests */
cdef unsigned int BLK_TC_DRV_DATA = 1 << 14     # /* binary driver data */
cdef unsigned int BLK_TC_END      = 1 << 15     # /* only 16-bits, reminder */

cdef unsigned int __BLK_TA_QUEUE = 1       # /* queued */
cdef unsigned int __BLK_TA_BACKMERGE = 2   # /* back merged to existing rq */
cdef unsigned int __BLK_TA_FRONTMERGE = 3  # /* front merge to existing rq */
cdef unsigned int __BLK_TA_GETRQ = 4       # /* allocated new request */
cdef unsigned int __BLK_TA_SLEEPRQ = 5     # /* sleeping on rq allocation */
cdef unsigned int __BLK_TA_REQUEUE = 6     # /* request requeued */
cdef unsigned int __BLK_TA_ISSUE = 7       # /* sent to driver */
cdef unsigned int __BLK_TA_COMPLETE = 8    # /* completed by driver */
cdef unsigned int __BLK_TA_PLUG = 9        # /* queue was plugged */
cdef unsigned int __BLK_TA_UNPLUG_IO = 10  #  /* queue was unplugged by io */
cdef unsigned int __BLK_TA_UNPLUG_TIMER = 11 #  /* queue was unplugged by timer */
cdef unsigned int __BLK_TA_INSERT = 12       #  /* insert request */
cdef unsigned int __BLK_TA_SPLIT = 13        #  /* bio was split */
cdef unsigned int __BLK_TA_BOUNCE = 14       #  /* bio was bounced */
cdef unsigned int __BLK_TA_REMAP = 15        #  /* bio was remapped */
cdef unsigned int __BLK_TA_ABORT = 16        #  /* request aborted */
cdef unsigned int __BLK_TA_DRV_DATA = 17     #  /* binary driver data */

cdef unsigned int __BLK_TN_PROCESS = 0
cdef unsigned int __BLK_TN_TIMESTAMP = 1
cdef unsigned int __BLK_TN_MESSAGE = 2

cdef unsigned int BLK_TA_QUEUE = (__BLK_TA_QUEUE | BLK_TC_ACT(BLK_TC_QUEUE))
cdef unsigned int BLK_TA_BACKMERGE = (__BLK_TA_BACKMERGE |
		BLK_TC_ACT(BLK_TC_QUEUE))
cdef unsigned int BLK_TA_FRONTMERGE = (__BLK_TA_FRONTMERGE |
		BLK_TC_ACT(BLK_TC_QUEUE))
cdef unsigned int BLK_TA_GETRQ = (__BLK_TA_GETRQ | BLK_TC_ACT(BLK_TC_QUEUE))
cdef unsigned int BLK_TA_SLEEPRQ = (__BLK_TA_SLEEPRQ |
		BLK_TC_ACT(BLK_TC_QUEUE))
cdef unsigned int BLK_TA_REQUEUE  = (__BLK_TA_REQUEUE |
		BLK_TC_ACT(BLK_TC_REQUEUE))
cdef unsigned int BLK_TA_ISSUE = (__BLK_TA_ISSUE | BLK_TC_ACT(BLK_TC_ISSUE))
cdef unsigned int BLK_TA_COMPLETE = (__BLK_TA_COMPLETE |
		BLK_TC_ACT(BLK_TC_COMPLETE))
cdef unsigned int BLK_TA_PLUG = (__BLK_TA_PLUG | BLK_TC_ACT(BLK_TC_QUEUE))
cdef unsigned int BLK_TA_UNPLUG_IO = (__BLK_TA_UNPLUG_IO |
		BLK_TC_ACT(BLK_TC_QUEUE))
cdef unsigned int BLK_TA_UNPLUG_TIME = (__BLK_TA_UNPLUG_TIMER |
		BLK_TC_ACT(BLK_TC_QUEUE))
cdef unsigned int BLK_TA_INSERT = (__BLK_TA_INSERT | BLK_TC_ACT(BLK_TC_QUEUE))
cdef unsigned int BLK_TA_SPLIT = (__BLK_TA_SPLIT)
cdef unsigned int BLK_TA_BOUNCE = (__BLK_TA_BOUNCE)
cdef unsigned int BLK_TA_REMAP = (__BLK_TA_REMAP | BLK_TC_ACT(BLK_TC_QUEUE))
cdef unsigned int BLK_TA_ABORT = (__BLK_TA_ABORT | BLK_TC_ACT(BLK_TC_QUEUE))
cdef unsigned int BLK_TA_DRV_DATA = (__BLK_TA_DRV_DATA |
		BLK_TC_ACT(BLK_TC_DRV_DATA))

cdef unsigned int BLK_TN_PROCESS = (__BLK_TN_PROCESS |
		BLK_TC_ACT(BLK_TC_NOTIFY))
cdef unsigned int BLK_TN_TIMESTAMP = (__BLK_TN_TIMESTAMP |
		BLK_TC_ACT(BLK_TC_NOTIFY))
cdef unsigned int BLK_TN_MESSAGE = (__BLK_TN_MESSAGE |
		BLK_TC_ACT(BLK_TC_NOTIFY))

format = "IIQQIIIIIHH"
format_size = struct.calcsize(format)
first_time = None
pid_map = {}

cdef int MINORBITS = 20
cdef unsigned int MINORMASK = ((1 << MINORBITS) - 1)
cdef unsigned int MAJOR(unsigned int dev):
    return dev >> MINORBITS

cdef unsigned int MINOR(unsigned int dev):
    return dev & MINORMASK

cdef float dev_to_float(unsigned major, unsigned minor):
    cdef float res = float(minor) / 100.00
    while res > 1:
        res /= 10.0

    return res + float(major)

cdef skip_bytes(int fd, int num_bytes, char *buf, int buf_size):
    cdef int val
    cdef int ret
    while num_bytes > 0:
        val = min(num_bytes, buf_size)
        ret = read(fd, buf, val)
        if ret < 0:
            return
        num_bytes -= ret

def read_events(fp, numpy.ndarray[numpy.float_t, ndim=1] row, tags, pid_map):
    cdef int ret = 0
    cdef unsigned action
    cdef unsigned act
    cdef unsigned size
    cdef long long sector
    cdef float time
    cdef int rw
    cdef unsigned major
    cdef unsigned minor
    cdef char buf[4096]
    cdef int fd = fp.fileno()
    cdef int num
    cdef blk_io_trace *trace

    while True:

        num = read(fd, buf, format_size)
        if num < format_size:
            break

        trace = <blk_io_trace *>buf
        action = trace.action

        if action == BLK_TN_PROCESS and tags:
            payload_size = trace.pdu_len
            payload = os.read(fd, payload_size)
            idx = payload.find('\0')
            if idx >= 0:
                payload = payload[:idx]
            pid_map[trace.pid] = payload
            continue

        act = action & 0xffff
        size = trace.bytes

        if (size == 0 or (act != __BLK_TA_COMPLETE and
            act != __BLK_TA_QUEUE and
            act != __BLK_TA_ISSUE)):
            skip_bytes(fd, trace.pdu_len, buf, 4096)
            continue
        
        time = trace.time
        time = time / 1000000000.0
        rw = action & BLK_TC_ACT(BLK_TC_WRITE) != 0
        major = MAJOR(trace.device)
        minor = MINOR(trace.device)

        ret = 1
        row[1] = rw
        row[2] = major
        row[3] = minor
        row[4] = trace.sector
        row[5] = size
        row[6] = trace.sequence
        row[7] = time
        row[8] = dev_to_float(major, minor)
        row[9] = 0

        if act == __BLK_TA_QUEUE and size > 0:
            row[0] = 0.0
            if tags:
                tags[0] = trace.pid
                tags[1] = pid_map.get(trace.pid, "none")
        elif act == __BLK_TA_COMPLETE and size > 0:
            row[0] = 1.0
        elif act == __BLK_TA_ISSUE and size > 0:
            row[0] = 4.0

        skip_bytes(fd, trace.pdu_len, buf, 4096)
        break
    return ret
