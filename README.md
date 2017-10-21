# Synchronized Queues

There are so many variants and I want to implement all of them.
Here are the variants and letters for naming FIFO queues:

* lock-free or blocking (L)
* bounded or unbounded (B)
* single or multiple producer (SP/MP)
* single or multiple consumer (SC/MC)

That means we get the following variants:

* SPSC queue synchronizes between reader and writer
* MPMC queue is simply synchronized.
  Not bounded and not lock-free.
* LMPMC queue is lock-free, which implicitly means a changed interface.
  Modifying the queue might fail.
  Usually, users should just try again until an operation succeeds.
* BMPMC queue is bounded, which might be useful to limit memory consumption.
  Inserting elements blocks until there is enough space.
* LBMPMC is lock-free and bounded.
* SPMC requires that only one thread inserts elements to the queue.
  This allows for better performance.
* LSPMC
* BSPMC
* LBSPMC
* MPSC requires that only one thread extracts elements from the queue.
  This allows for better performance.
* LMPSC
* BMPSC
* LBMPSC
