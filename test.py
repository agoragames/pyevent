#!/usr/bin/env python

import glob, os, signal, sys, thread, time, unittest
sys.path.insert(0, glob.glob('./build/lib.*')[0])
import event

class EventTest(unittest.TestCase):
    def setUp(self):
        event.init()

    def test_timeout(self):
        def __timeout_cb(ev, handle, evtype, ts):
            now = time.time()
            assert int(now - ts['start']) == ts['secs'], 'timeout failed'
        print 'test_timeout'
        ts = { 'start':time.time(), 'secs':5 }
        ev = event.event(__timeout_cb, arg=ts)
        ev.add(ts['secs'])
        event.dispatch()

    def test_timeout2(self):
        def __timeout2_cb(start, secs):
            dur = int(time.time() - start)
            assert dur == secs, 'timeout2 failed'
        print 'test_timeout2'
        event.timeout(5, __timeout2_cb, time.time(), 5)
        event.dispatch()
    
    def test_signal(self):
        def __signal_cb(ev, sig, evtype, arg):
            if evtype == event.EV_SIGNAL:
                ev.delete()
            elif evtype == event.EV_TIMEOUT:
                os.kill(os.getpid(), signal.SIGUSR1)
        print 'test_signal'
        event.event(__signal_cb, handle=signal.SIGUSR1,
                    evtype=event.EV_SIGNAL).add()
        event.event(__signal_cb).add(2)
        event.dispatch()

    def test_signal2(self):
        def __signal2_cb(sig):
            if sig:
                event.abort()
            else:
                os.kill(os.getpid(), signal.SIGUSR1)
        print 'test_signal2'
        event.signal(signal.SIGUSR1, __signal2_cb, signal.SIGUSR1)
        event.timeout(2, __signal2_cb)
    
    def test_read(self):
        def __read_cb(ev, fd, evtype, pipe):
            buf = os.read(fd, 1024)
            assert buf == 'hi niels', 'read event failed'
        print 'test_read'
        pipe = os.pipe()
        event.event(__read_cb, handle=pipe[0],
                    evtype=event.EV_READ).add()
        os.write(pipe[1], 'hi niels')
        event.dispatch()

    def test_read2(self):
        def __read2_cb(fd, msg):
            assert os.read(fd, 1024) == msg, 'read2 event failed'
        print 'test_read2'
        msg = 'hello world'
        pipe = os.pipe()
        event.read(pipe[0], __read2_cb, pipe[0], msg)
        os.write(pipe[1], msg)
        event.dispatch()

    def test_exception(self):
        print 'test_exception'
        def __bad_cb(foo):
            raise NotImplementedError, foo
        event.timeout(0, __bad_cb, 'bad callback')
        try:
            event.dispatch()
        except NotImplementedError:
            pass

    def test_abort(self):
        print 'test_abort'
        def __time_cb():
            raise NotImplementedError, 'abort failed!'
        event.timeout(5, __time_cb)
        event.timeout(1, event.abort)
        event.dispatch()

    def test_callback_exception(self):
        print 'test_callback_exception'
        def __raise_cb(exc):
            raise exc
        def __raise_catch_cb(exc):
            try:
                raise exc
            except:
                pass
        event.timeout(0, __raise_cb, StandardError())
        event.timeout(0, __raise_catch_cb, Exception())
        self.assertRaises(StandardError, event.dispatch)

    def test_thread(self):
        print 'test_thread'
        def __time_cb(d):
            assert d['count'] == 3
        def __time_thread(count, d):
            for i in range(count):
                time.sleep(1)
                d['count'] += 1
        d = { 'count': 0 }
        thread.start_new_thread(__time_thread, (3, d))
        event.timeout(4, __time_cb, d)
        event.dispatch()

if __name__ == '__main__':
    unittest.main()
