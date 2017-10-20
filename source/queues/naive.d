module queues.naive;

import queues;

import core.sync.semaphore : Semaphore;
import core.sync.mutex : Mutex;

/*** Most simple blocking multi-producer multi-consumer queue */
class NaiveThreadsafeQueue(T) : Queue!T {
    private T[] data;
    private Semaphore s;
    private Mutex m;
    this() {
        this.s = new Semaphore(0);
        this.m = new Mutex();
    }
    void enqueue(T t) {
        this.m.lock();
        scope(exit) this.m.unlock();
        this.data ~= t;
        s.notify(); /* in case it was empty and some wait */
    }
    T dequeue() {
        s.wait(); /* ensure at least one element */
        this.m.lock();
        scope(exit) this.m.unlock();
        auto r = this.data[0];
        this.data = data[1..$];
        return r;
    }
    bool tryDequeue(out T e) {
        if (this.s.tryWait()) {
            this.m.lock();
            e = this.data[0];
            this.data = data[1..$];
            this.m.unlock();
            return true;
        }
        return false;
    }
}

unittest {
    import std.range;
    import std.stdio;
    import core.thread;
    alias Q = NaiveThreadsafeQueue!int;
    auto q = new Q();
    enum count = 10;
    auto t1 = new Thread({
        foreach(d; 0 .. count) {
            auto x = q.dequeue();
            assert (x == d);
        }
    });
    auto t2 = new Thread({
        foreach(d; 0 .. count)
            q.enqueue(d);
    });
    t1.start();
    t2.start();
    t1.join();
    t2.join();
}
