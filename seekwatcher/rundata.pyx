import numpy
import sys
import seekwatcher.blkparse
cimport numpy

cdef extern from "math.h":
    float floor(float val)
    float ceil(float val)
    double fmod(double x, double y)

cdef float QUEUE_EVENT = 0.0
cdef float COMPLETION_EVENT = 1.0
cdef float DISPATCH_EVENT = 4.0
ctypedef numpy.float_t DTYPE_t
cdef int ROWINC = 16384

#
# the rundata class holds all underlying data used to create each graph.
# seeks, throughput and iops are calculated once as we load the data
# in, and then the data is filtered to only include enough for the
# movies and IO graph.  If we aren't doing the IO graph, the
# data is stripped almost bare.
#
cdef class rundata:
    cdef public seek_hist
    cdef public seeks
    cdef public tput
    cdef public iops
    cdef public stats
    cdef public last_seek
    cdef public last_tput
    cdef public float last_time
    cdef public last_iops
    cdef public last_line
    cdef public data
    cdef int found_issued
    cdef int found_completion
    cdef int found_queue
    cdef int data_rows
    cdef int data_filled

    def add_data_row(self, numpy.ndarray[DTYPE_t, ndim=2] data,
            numpy.ndarray[DTYPE_t, ndim=1] row):

        cdef int i
        cdef int index = self.data_filled

        if self.data_filled == self.data_rows:
            extend = numpy.empty((ROWINC, 10), dtype=float)
            data = numpy.append(self.data, extend, axis=0)
            self.data = data
            self.data_rows += ROWINC

        i = 0
        while i < 10:
            data[index,i] = row[i]
            i += 1
        self.data_filled += 1
    
    def __init__(self):
        self.seek_hist = {}
        self.seeks = {}
        self.tput = {}
        self.iops = {}
        self.stats = {}
        self.last_seek = None
        self.last_tput = None
        self.last_iops = None
        self.last_time = 0
        self.last_line = None
        self.data = numpy.empty((ROWINC, 10), dtype=float)
        self.data_rows = ROWINC
        self.data_filled = 0
        self.found_issued = False
        self.found_completion = False
        self.found_queue = False

    def add_seek(self, numpy.ndarray[DTYPE_t, ndim=1] data, float cur_time):
        cdef float dev = data[8]
        cdef float sector = data[4]
        cdef float io_size = data[5] / 512
        cdef float last
        cdef float last_size
        cdef float old
        cdef float diff

        last = self.seek_hist.get(dev, 0)

        if last != 0:
            diff = abs(last - sector)
            if diff > 128:
                old = self.seeks.get(cur_time, 0)
                self.seeks[cur_time] = old + 1
        self.seek_hist[dev] = sector + io_size
        self.last_seek = data
        self.last_time = data[7]

    def add_tput(self, numpy.ndarray[DTYPE_t, ndim=1] data, float cur_time):
        cdef float old = self.tput.get(cur_time, 0)

        self.tput[cur_time] = old + data[5]
        self.last_tput = data
        self.last_time = data[7]

    def add_iop(self, numpy.ndarray[DTYPE_t, ndim=1] data, float cur_time):
        cdef float old = self.iops.get(cur_time, 0)
        self.iops[cur_time] = old + 1
        self.last_iops = data
        self.last_time = data[7]

    def add_line(self, numpy.ndarray[DTYPE_t, ndim=1] data):
        cdef float op = data[0]
        cdef float floor_time = floor(data[7])
        self.last_line = data

        # for seeks, we want to use the dispatch event
        # and if those aren't in the trace we want
        # the queued event, and if those aren't in
        # the trace, we want the completion event
        if op == DISPATCH_EVENT:
            # dispatch
            self.add_seek(data, floor_time)
        elif op == COMPLETION_EVENT and not self.found_issued and not \
                self.found_queue:
            # completion
            self.add_seek(data, floor_time)
        elif op == QUEUE_EVENT and not self.found_issued:
            # queue
            self.add_seek(data, floor_time)

        # for tput and iops, we want to use the completion event
        # otherwise dispatch, otherwise queue
        if op == COMPLETION_EVENT:
            self.add_tput(data, floor_time)
            self.add_iop(data, floor_time)
        elif op == DISPATCH_EVENT and not self.found_completion:
            self.add_tput(data, floor_time)
            self.add_iop(data, floor_time)
        elif op == QUEUE_EVENT and not self.found_completion and not \
                self.found_issued:
            self.add_tput(data, floor_time)
            self.add_iop(data, floor_time)

    def load_data(self, fh, delimiter, io_plot,
            devices_sector_max, tags, options):

        cdef int total_lines = 0
        cdef int total_out = 0
        cdef int first_line = 0
        cdef float last_sector = 0
        cdef float last_rw = 0
        cdef float last_end = 0
        cdef float last_cmd = 0
        cdef float last_size = 0
        cdef float last_dev = 0
        cdef float last_tag = 0
        cdef tag_data
        cdef numpy.ndarray[DTYPE_t, ndim=1] last_row = None
        cdef numpy.ndarray[DTYPE_t, ndim=1] row = None
        cdef int should_tag = options.tag_process
        cdef writes_only = options.writes_only
        cdef reads_only = options.reads_only
        cdef int io_seeks_only = options.only_io_graph_seeks
        cdef int i
        cdef int this_tag
        cdef float this_op
        cdef float this_time
        cdef float this_dev
        cdef float this_sector
        cdef float this_rw
        cdef float this_size

        row = numpy.empty(10)
        pid_map = {}
        if should_tag:
            tag_data = [ 0, 0 ]
        else:
            tag_data = None

        while seekwatcher.blkparse.read_events(fh, row, tag_data, pid_map) > 0:
            this_op = row[0]
            if not self.found_completion and this_op == COMPLETION_EVENT:
                self.found_completion = 1
            if not self.found_queue and this_op == QUEUE_EVENT:
                self.found_queue = 1
            if not self.found_issued and this_op == DISPATCH_EVENT:
                self.found_issued = 1

            if this_op == QUEUE_EVENT and should_tag:
                if 'all' in options.merge or \
                        options.merge.count(tag_data[1]) > 0:
                    v = str(tag_data[1])
                else:
                    v = str(tag_data[1]) + "(" + str(tag_data[0]) + ")"
                this_tag = tags.setdefault(v, len(tags))

            row[9] = this_tag
            this_time = row[7]
            this_dev = row[8]
            this_sector = row[4]
            this_rw = row[1]
            this_size = row[5] / 512

            total_lines += 1
            if writes_only and this_rw == 0:
                continue
            if reads_only and this_rw == 1:
                continue

            self.add_line(row)

            devices_sector_max[this_dev] = max(this_sector + this_size,
                                    devices_sector_max.get(this_dev, 0));

            if should_tag:
                if this_op != QUEUE_EVENT and self.found_queue:
                    continue
                if this_op == DISPATCH_EVENT and self.found_completion:
                    continue

            elif io_seeks_only:
                if this_op == COMPLETION_EVENT and (self.found_queue or
                        self.found_issued):
                    continue
                if this_op == QUEUE_EVENT and self.found_issued:
                    continue
            else:
                if this_op == QUEUE_EVENT and (self.found_completion or
                        self.found_issued):
                    continue
                if this_op == DISPATCH_EVENT and self.found_completion:
                    continue

            if last_row != None:
                if (this_op == last_op and 
                this_rw == last_rw and
                this_dev == last_dev and
                this_time - last_time < .5 and last_size < 128 and
                this_sector == last_end and this_tag == last_tag):
                    last_end += this_size
                    last_size += this_size
                    last_row[5] += row[5]
                    continue
                total_out += 1
                self.add_data_row(self.data, last_row)
                
            last_row = row
            last_op = this_op
            last_sector = this_sector
            last_time = this_time
            last_rw = this_rw
            last_end = this_sector + this_size
            last_size = this_size
            last_dev = this_dev
            last_tag = this_tag

        if last_row != None:
            if last_row.any():
                self.add_data_row(self.data, last_row)
                total_out += 1

        self.data = numpy.resize(self.data, (self.data_filled, 10))
        self.data_rows = self.data_filled

    def translate_run(self, devices_sector_max, device_translate):
        cdef int i
        cdef numpy.ndarray[DTYPE_t, ndim=2] data = self.data
        cdef numpy.ndarray[DTYPE_t, ndim=1] row

        if len(devices_sector_max) > 1:
            i = 0
            while i < self.data_filled:
                row = data[i]
                sector = row[4]
                row[4] = device_translate[row[8]] + sector
                i += 1

cdef class moviedata:
    cdef data
    cdef public int datai
    cdef public int total_frames
    cdef public int start_second
    cdef public int secs_per_frame
    cdef public int end
    cdef public int xmax
    cdef public yzoommin
    cdef public yzoommax
    cdef public sectors_per_cell
    cdef public float num_cells

    def __init__(self, data, xmax, yzoommin, yzoommax,
            sectors_per_cell, num_cells):
        self.data = data
        self.datai = 0
        self.xmax = xmax
        self.yzoommin = yzoommin
        self.yzoommax = yzoommax
        self.sectors_per_cell = sectors_per_cell
        self.num_cells = num_cells

    cdef xycalc(self, float sector):
        cdef float xval
        cdef float yval

        if sector < self.yzoommin or sector > self.yzoommax:
            return None
        sector = sector - self.yzoommin
        sector = sector / self.sectors_per_cell
        yval = floor(sector / self.num_cells)
        xval = fmod(sector, self.num_cells)
        return (xval + 5, yval + 5)

    def make_frame(self, float start, float end, read_xvals, read_yvals,
            write_xvals, write_yvals, prev):
        cdef int datalen = len(self.data)
        cdef numpy.ndarray[DTYPE_t, ndim=2] data = self.data
        cdef numpy.ndarray[DTYPE_t, ndim=1] row
        cdef float time
        cdef float sector
        cdef int size
        cdef float rbs
        cdef float cell

        while self.datai < datalen and data[self.datai][7] < end:
            row = data[self.datai]
            time = row[7]
            self.datai += 1
            if time < start:
                print "dropping time %.2f < start %.2f" % (time, start)
                continue
            if time > self.xmax:
                continue
            sector = row[4]
            size = int(max(row[5] / 512, 1))
            rbs = row[1]
            cell = 0
            while cell < size:
                xy = self.xycalc(sector)
                sector += self.sectors_per_cell
                cell += self.sectors_per_cell
                if xy:
                    if rbs:
                        write_xvals.append(xy[0])
                        write_yvals.append(xy[1])
                    else:
                        read_xvals.append(xy[0])
                        read_yvals.append(xy[1])

        if read_xvals or write_xvals:
            if len(prev) > 10:
                del prev[0]
            prev.append((read_xvals, read_yvals, write_xvals, write_yvals))
