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

/*** Most simple bounded blocking multi-producer multi-consumer queue */
class NaiveBoundedThreadsafeQueue(T,size_t max) : Queue!T {
    private T[max] data;
    private size_t start = 0;
    private size_t end = 0;
    private Semaphore empty;
    private Semaphore full;
    private Mutex m;
    this() {
        this.empty = new Semaphore(0);
        this.full = new Semaphore(max);
        this.m = new Mutex();
    }
    void enqueue(T t) {
        full.wait(); /* need space for one element */
        m.lock();
        scope(exit) m.unlock();
        data[end] = t;
        end = (end + 1) % max;
        empty.notify(); /* in case some dequeue waits */
    }
    T dequeue() {
        empty.wait(); /* ensure at least one element */
        m.lock();
        scope(exit) m.unlock();
        auto r = data[start];
        start = (start + 1) % max;
        full.notify(); /* in case some enqueue waits */
        return r;
    }
    bool tryDequeue(out T e) {
        if (empty.tryWait()) {
            m.lock();
            scope (exit) m.unlock();
            e = data[start];
            start = (start + 1) % max;
            return true;
        }
        return false;
    }
}
