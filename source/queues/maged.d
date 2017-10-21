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

/***
  Start `writers` amount of threads to write into a queue.
  Start `readers` amount of threads to read from the queue.
  Each writer counts from 0 to `count` and sends each number into the queue.
  The sum is checked at the end.
*/
void test_run(alias Q)(uint writers, uint readers, uint count)
{
    import std.range;
    import std.stdio;
    import core.thread;
    import core.sync.barrier : Barrier;
    import std.bigint : BigInt;
    import fluent.asserts;
    /* compute desired sum via Gauss formula */
    BigInt correct_sum = BigInt(count) * BigInt(count-1) / 2 * writers;
    /* compute sum via multiple threads and one queue */
    BigInt sum = 0;
    auto b = new Barrier(writers + readers);
    auto q = new Q!long();
    auto w = new Thread({
            Thread[] ts;
            foreach(i; 0 .. writers) {
                auto t = new Thread({
                        b.wait();
                        foreach(n; 1 .. count) {
                            q.enqueue(n);
                        }
                        });
                t.start();
                ts ~= t;
            }
            foreach(t; ts) { t.join(); }
            });
    auto r = new Thread({
            Thread[] ts;
            foreach(i; 0 .. writers) {
                auto t = new Thread({
                        BigInt s = 0;
                        b.wait();
                        foreach(_; 1 .. count) {
                            auto n = q.dequeue();
                            s += n;
                        }
                        synchronized { sum += s; }
                        });
                t.start();
                ts ~= t;
            }
            foreach(t; ts) { t.join(); }
            });
    w.start();
    r.start();
    w.join();
    r.join();
    sum.should.equal(correct_sum);
}

import queues.naive : NaiveThreadsafeQueue;
unittest {
    import std.stdio;
    import std.datetime.stopwatch : benchmark;
    enum readers = 10;
    enum writers = 10;
    enum count = 200000;
    void f0() { test_run!NaiveThreadsafeQueue (writers,readers,count); }
    void f1() { test_run!MagedBlockingQueue   (writers,readers,count); }
    void f2() { test_run!MagedNonBlockingQueue(writers,readers,count); }
    auto r = benchmark!(f0, f1, f2)(5);
    writeln(r[0]);
    writeln(r[1]);
    writeln(r[2]);
}

static foreach (Q; AliasSeq!(NaiveThreadsafeQueue, MagedBlockingQueue, MagedNonBlockingQueue))
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
