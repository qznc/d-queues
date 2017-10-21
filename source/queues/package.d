module queues;

public import queues.naive;
public import queues.maged;

/*** Basic interface for all queues implemented here.
    Is an input and output range. */
interface Queue(T) {
    /*** Atomically put one element into the queue. */
    void enqueue(T t);
    /*** Atomically take one element from the queue.
      Wait blocking or spinning. */
    T dequeue();
    /***
      If at least one element is in the queue,
      atomically take one element from the queue
      store it into e, and return true.
      Otherwise return false; */
    bool tryDequeue(out T e);
}

static foreach (Q; AliasSeq!(
            NaiveThreadsafeQueue!int,
            NaiveBoundedThreadsafeQueue!(int,10),
            MagedBlockingQueue!int,
            MagedNonBlockingQueue!int))
{
    unittest {
        import std.range;
        import core.thread;
        import fluent.asserts;
        auto q = new Q();
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

/***
  Start `writers` amount of threads to write into a queue.
  Start `readers` amount of threads to read from the queue.
  Each writer counts from 0 to `count` and sends each number into the queue.
  The sum is checked at the end.
*/
void test_run(alias Q)(uint writers, uint readers, uint count)
{
    import std.range;
    import core.thread;
    import core.sync.barrier : Barrier;
    import std.bigint : BigInt;
    import fluent.asserts;
    /* compute desired sum via Gauss formula */
    BigInt correct_sum = BigInt(count) * BigInt(count-1) / 2 * writers;
    /* compute sum via multiple threads and one queue */
    BigInt sum = 0;
    auto b = new Barrier(writers + readers);
    auto q = new Q();
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

/*** Exemplary benchmarking */
unittest {
    import std.datetime.stopwatch : benchmark;
    enum readers = 10;
    enum writers = 10;
    enum bnd = 10; // size for bounded queues
    enum count = 10000; // too small, so only functional test
    void f0() { test_run!(NaiveThreadsafeQueue!long)              (writers,readers,count); }
    void f1() { test_run!(NaiveBoundedThreadsafeQueue!(long,bnd)) (writers,readers,count); }
    void f2() { test_run!(MagedBlockingQueue!long)                (writers,readers,count); }
    void f3() { test_run!(MagedNonBlockingQueue!long)             (writers,readers,count); }
    auto r = benchmark!(f0, f1, f2, f3)(3);
    //import std.stdio;
    //writeln(r[0]);
    //writeln(r[1]);
    //writeln(r[2]);
    //writeln(r[3]);
}
