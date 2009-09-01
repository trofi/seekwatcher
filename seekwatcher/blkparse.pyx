import numpy
import struct
cimport numpy

#struct blk_io_trace {
#      0  __u32 magic;            /* MAGIC << 8 | version */
#      1  __u32 sequence;         /* event number */
#      2  __u64 time;             /* in nanoseconds */
#      3  __u64 sector;           /* disk offset */
#      4  __u32 bytes;            /* transfer length */
#      5  __u32 action;           /* what happened */
#      6  __u32 pid;              /* who did it */
#      7  __u32 device;           /* device identifier (dev_t) */
#      8  __u32 cpu;              /* on what cpu did it happen */
#      9  __u16 error;            /* completion error */
#      10 __u16 pdu_len;          /* length of data after this trace */
#};

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

    while True:
        record = fp.read(format_size)
        if not record:
            break

        c = struct.unpack(format, record)
        action = c[5]
        if action == BLK_TN_PROCESS and tags:
            payload_size = c[10]
            payload = fp.read(payload_size)
            idx = payload.find('\0')
            if idx >= 0:
                payload = payload[:idx]
            pid_map[c[6]] = payload
            continue

        act = action & 0xffff
        size = c[4]

        if (size == 0 or (act != __BLK_TA_COMPLETE and
            act != __BLK_TA_QUEUE and
            act != __BLK_TA_ISSUE)):
            skip = c[10]
            if skip:
                fp.read(skip)
            continue
        
        time = float(c[2]) / 1000000000.0
        rw = action & BLK_TC_ACT(BLK_TC_WRITE) != 0
        major = MAJOR(c[7])
        minor = MINOR(c[7])

        ret = 1
        row[1] = rw
        row[2] = major
        row[3] = minor
        row[4] = c[3]
        row[5] = size
        row[6] = c[1]
        row[7] = time
        row[8] = dev_to_float(major, minor)
        row[9] = 0

        if act == __BLK_TA_QUEUE and size > 0:
            row[0] = 0.0
            if tags:
                tags[0] = c[6]
                tags[1] = pid_map.get(c[6], "none")
        elif act == __BLK_TA_COMPLETE and size > 0:
            row[0] = 1.0
        elif act == __BLK_TA_ISSUE and size > 0:
            row[0] = 4.0
        skip = c[10]
        if skip:
            fp.read(skip)
        break
    return ret
