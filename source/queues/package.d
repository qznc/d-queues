module queues;

public import queues.naive;

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
