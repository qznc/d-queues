import std.stdio;
import std.experimental.checkedint;

import queues;

void busy_work() {
    // assume compiler is unable to evaluate this at compile time
    import std.random;
    auto gen = Mt19937(11);
    foreach(x;gen) {
        if (x < 80000) break;
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
    import core.thread;
    import core.sync.barrier : Barrier;
    import std.bigint : BigInt;
    assert (checked(count) * readers * writers);
    const items = count * readers * writers;
    const items_per_writer = count * readers;
    //writefln("Put %d items with %d writers each", items_per_writer, writers);
    const items_per_reader = count * writers;
    //writefln("Get %d items with %d readers each", items_per_reader, readers);
    /* compute desired sum via Gauss formula */
    BigInt correct_sum = BigInt(items_per_writer) * BigInt(items_per_writer-1) / 2 * writers;
    /* compute sum via multiple threads and one queue */
    BigInt sum = 0;
    auto b = new Barrier(writers + readers);
    auto q = new Q();
    auto w = new Thread({
            Thread[] ts;
            foreach(i; 0 .. writers) {
                auto t = new Thread({
                        b.wait();
                        foreach(n; 0 .. items_per_writer) {
                            q.enqueue(n);
                            busy_work();
                        }
                        });
                t.start();
                ts ~= t;
            }
            foreach(t; ts) { t.join(); }
            });
    auto r = new Thread({
            Thread[] ts;
            foreach(i; 0 .. readers) {
                auto t = new Thread({
                        BigInt s = 0;
                        b.wait();
                        foreach(_; 0 .. items_per_reader) {
                            auto n = q.dequeue();
                            s += n;
                            busy_work();
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
    assert(sum == correct_sum);
}

enum MagedMichaelOpCount = 100_000; /* 1_000_000 in paper */
/***
  Benchmark like Maged and Michael.
*/
void test_run2(Queue!long q, uint threads)
{
    import core.thread;
    import core.sync.barrier : Barrier;
    import std.bigint : BigInt;
    const count = MagedMichaelOpCount / threads;
    Thread[] ts;
    foreach(i; 0 .. threads) {
        auto t = new Thread({
                foreach(n; 0 .. count) {
                    q.enqueue(n);
                    busy_work();
                    auto x = q.dequeue();
                    busy_work();
                }
                });
        t.start();
        ts ~= t;
    }
    foreach(t; ts) { t.join(); }
}

void main(string[] args) {
    import std.datetime.stopwatch : benchmark;
    enum readers = 2;
    enum writers = 3;
    enum bnd = 10; // size for bounded queues
    enum count = 100000;
    void baseline() {
        /* purely the busy work of one thread */
        foreach(_; 0..MagedMichaelOpCount / writers) {
            busy_work();
            busy_work();
        }
    }
    void f0() { test_run2(new NaiveThreadsafeQueue!(long)(),            writers); }
    void f1() { test_run2(new NaiveBoundedThreadsafeQueue!(long,bnd)(), writers); }
    void f2() { test_run2(new MagedBlockingQueue!long(),                writers); }
    void f3() { test_run2(new MagedNonBlockingQueue!long(),             writers); }
    auto r = benchmark!(baseline, f0, f1, f2, f3)(3);
    import std.stdio;
    auto base = r[0];
    writeln(r[1] - base);
    writeln(r[2] - base);
    writeln(r[3] - base);
    writeln(r[4] - base);
}
