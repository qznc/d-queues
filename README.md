# Synchronized Queues

There are so many variants and I want to implement a few.

## Current State

* There is a naive bounded and unbounded queue.
* Implemented the paper [Simple, fast, and practical non-blocking and blocking concurrent queue algorithms](https://dl.acm.org/citation.cfm?id=248106).

I'm not confident that everything is correct yet.
There are only a few tests.
So, **not production ready**!

## Naming Scheme

Here are some variants and letters for naming FIFO queues:

* Lock-free (L) or blocking:
  Blocking means that kernel-level locks are used,
  while lock-free algorithms use instructions like Compare-And-Swap.
* Bounded or unbounded (B):
  Bounded queues have a constant memory need.
* Single or multiple producer (SP/MP)
  Only supporting a single producer allows higher speed.
* Single or multiple consumer (SC/MC)
  Only supporting a single consumer allows higher speed.

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

The next level would be sorted (priority) queues.
Another aspect is memory management,
because relying on the garbage collector is the easy way out.
