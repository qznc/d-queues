module queues.maged;

import queues;

import std.meta : AliasSeq;
import core.sync.mutex : Mutex;
import core.atomic;

private static class Cons(T) {
    public Cons!T nxt;
    public T value;
}

/*** blocking multi-producer multi-consumer queue 
    from "Simple, fast, and practical non-blocking and blocking concurrent queue algorithms"
    by Maged and Michael. "*/
class MagedBlockingQueue(T) : Queue!T {
    private Cons!T head;
    private Cons!T tail;
    private Mutex head_lock;
    private Mutex tail_lock;

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

/*** non-blocking multi-producer multi-consumer queue 
    from "Simple, fast, and practical non-blocking and blocking concurrent queue algorithms"
    by Maged and Michael. "*/
class MagedNonBlockingQueue(T) : Queue!T {
    private shared(Cons!T) head;
    private shared(Cons!T) tail;

    this() {
        shared n = new Cons!T();
        this.head = this.tail = n;
    }
    void enqueue(T t) {
        shared end = new Cons!T();
        end.value = t;
        while (true) {
            auto tl = tail;
            auto cur = tl.nxt;
            if (cur !is null) {
                // obsolete tail, try update
                cas(&this.tail, tl, cur);
                continue;
            }
            shared(Cons!T) dummy = null;
            if (cas(&tl.nxt, dummy, end)) {
                // successfull enqueued new end node
                break;
            }
        }
    }
    T dequeue() {
        T e = void;
        while (!tryDequeue(e)) { }
        return e;
    }
    bool tryDequeue(out T e) {
        auto dummy = this.head;
        auto tl = this.tail;
        auto nxt = dummy.nxt;
        if (dummy is tl) {
            if (nxt is null) { /* queue empty */
                return false;
            } else { /* tail is obsolete */
                cas(&this.tail, tl, nxt);
            }
        } else {
            if (cas(&this.head, dummy, nxt)) {
                e = nxt.value;
                return true;
            }
        }
        return false;
    }
}

static foreach (Q; AliasSeq!(MagedBlockingQueue, MagedNonBlockingQueue))
{
    unittest {
        import std.range;
        import std.stdio;
        import core.thread;
        import fluent.asserts;
        auto q = new Q!int();
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
}
