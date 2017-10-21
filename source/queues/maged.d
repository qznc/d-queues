module queues.maged;

import queues;

import core.sync.mutex : Mutex;
import core.atomic;

/*** blocking multi-producer multi-consumer queue 
    from "Simple, fast, and practical non-blocking and blocking concurrent queue algorithms"
    by Maged and Michael. "*/
class MagedBlockingQueue(T) : Queue!T {
    private Cons!T head;
    private Cons!T tail;
    private Mutex head_lock;
    private Mutex tail_lock;

    private static class Cons(T) {
        public Cons!T nxt;
        public T value;
    }

    this() {
        auto n = new Cons!T();
        this.head = this.tail = n;
        this.head_lock = new Mutex();
        this.tail_lock = new Mutex();
    }
    void enqueue(T t) {
        auto end = new Cons!T();
        this.tail_lock.lock();
        scope (exit) this.tail_lock.unlock();
        auto tl = this.tail;
        this.tail = end;
        tl.value = t;
        atomicFence();
        tl.nxt = end; // accessible to dequeue
    }
    T dequeue() {
        this.head_lock.lock();
        scope (exit) this.head_lock.unlock();
        while (true) { // FIXME non-blocking!
            auto hd = this.head;
            auto scnd = hd.nxt;
            if (scnd !is null) {
                this.head = scnd;
                return hd.value;
            }
        }
        assert(0);
    }
    bool tryDequeue(out T e) {
        this.head_lock.lock();
        scope (exit) this.head_lock.unlock();
        auto hd = this.head;
        auto scnd = hd.nxt;
        if (scnd !is null) {
            this.head = scnd;
            e = hd.value;
            return true;
        }
        return false;
    }
}

unittest {
    import std.range;
    import std.stdio;
    import core.thread;
    import fluent.asserts;
    auto q = new MagedBlockingQueue!int();
    enum count = 1000;
    auto t1 = new Thread({
        foreach(d; 0 .. count) {
            (q.dequeue()).should.equal(d)
                .because("the other thread put that into the queue");
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
