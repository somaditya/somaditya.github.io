---
layout: post
title: "Modern Multithreading in Java"
subtitle: "Threads, executors, virtual threads, and structured concurrency"
author: Somaditya Basak
tags: [java, concurrency, multithreading]
---

Multithreading lets a Java program make progress on multiple tasks at once. It can improve throughput and responsiveness, but it also introduces coordination problems: tasks can finish in different orders, failures must be handled, and shared mutable state can produce race conditions.

This guide uses current Java conventions, including executors and virtual threads. Structured concurrency is also covered, but is still a preview API in Java 25.

## Start with tasks, not thread management

For simple background work, `Runnable` represents a task that produces no result, while `Callable<T>` represents one that returns a result or throws an exception:

```java
Runnable logTask = () -> System.out.println("Running in the background");

Callable<Integer> calculation = () -> 6 * 7;
```

Instead of creating and managing operating-system threads yourself for every job, submit tasks to an `ExecutorService`. The executor manages their execution and provides a clear place to wait for results and shut down the service.

## Use virtual threads for many blocking tasks

Virtual threads became a permanent Java feature in Java 21. They are lightweight threads managed by the Java runtime and are especially useful for workloads that spend time waiting on network or file I/O. A virtual-thread-per-task executor is a good fit when you have many independent blocking tasks:

```java
import java.util.ArrayList;
import java.util.List;
import java.util.concurrent.Callable;
import java.util.concurrent.ExecutionException;
import java.util.concurrent.ExecutorService;
import java.util.concurrent.Executors;
import java.util.concurrent.Future;

class ConcurrentLookups {
    static List<String> fetchAll(List<String> urls)
            throws InterruptedException, ExecutionException {
        try (ExecutorService executor =
                     Executors.newVirtualThreadPerTaskExecutor()) {
            List<Future<String>> futures = new ArrayList<>();

            for (String url : urls) {
                futures.add(executor.submit(() -> fetch(url)));
            }

            List<String> results = new ArrayList<>();
            for (Future<String> future : futures) {
                results.add(future.get());
            }
            return results;
        }
    }

    static String fetch(String url) {
        // Replace with a blocking HTTP request.
        return "Response from " + url;
    }
}
```

Closing the executor waits for its submitted tasks to finish. `Future.get()` waits for a result and reports task failures through `ExecutionException`. In production code, also consider timeouts and how cancellation should be handled.

Virtual threads make blocking code scale to many concurrent tasks; they do not make CPU-bound work run faster. For CPU-intensive work, a bounded executor sized to the available processing capacity is usually more appropriate. Virtual threads should generally be created per task, not pooled as though they were scarce platform threads. Use semaphores or other limits when a downstream service or resource has a concurrency limit.

## Protect shared state

Two tasks updating the same unsynchronized variable can overwrite each other's changes. For simple independent counters, use an atomic type:

```java
import java.util.concurrent.atomic.AtomicInteger;

class CounterExample {
    private final AtomicInteger completed = new AtomicInteger();

    void markCompleted() {
        completed.incrementAndGet();
    }

    int completedCount() {
        return completed.get();
    }
}
```

An atomic operation such as `incrementAndGet()` updates and reads the value as one indivisible operation. For invariants spanning multiple fields or steps, use a lock or `synchronized` block to protect the whole operation:

```java
private final Object lock = new Object();
private int balance;

void deposit(int amount) {
    if (amount < 0) {
        throw new IllegalArgumentException("amount must not be negative");
    }

    synchronized (lock) {
        balance += amount;
    }
}
```

Prefer immutable data and task-local variables where possible. They reduce the need for locks and make concurrent code easier to reason about.

## Coordinate related tasks with structured concurrency

Often a request needs several independent results, such as a user record and an order. With unrelated futures, the caller must coordinate their lifetimes and decide what to do if one fails. Structured concurrency groups related subtasks into a lexical scope so their results, failures, and cancellation are handled together.

In Java 25, the `StructuredTaskScope` API is still in preview (JEP 505). This example demonstrates the preview API:

```java
import java.util.concurrent.StructuredTaskScope;

record Response(String user, int order) {}

Response handle() throws InterruptedException {
    try (var scope = StructuredTaskScope.open()) {
        var user = scope.fork(() -> findUser());
        var order = scope.fork(() -> fetchOrder());

        scope.join();
        return new Response(user.get(), order.get());
    }
}
```

The default scope policy fails when a subtask fails and cancels unfinished siblings. Exiting the scope waits for its subtasks to finish, so they do not outlive the operation that started them. This API may change in a later Java release and requires preview features to be enabled:

```sh
javac --release 25 --enable-preview Main.java
java --enable-preview Main
```

For stable Java 25 code, use regular `ExecutorService` and `Future` APIs unless you deliberately opt into preview features.

## Share request context with scoped values

When many methods need the same immutable context, passing it as a parameter can become repetitive. Java 25's finalized `ScopedValue` API provides a bounded, read-only binding that callees can access:

```java
private static final ScopedValue<String> REQUEST_ID =
        ScopedValue.newInstance();

static void handle(String requestId) {
    ScopedValue.where(REQUEST_ID, requestId).run(() -> processRequest());
}

static void processRequest() {
    System.out.println("Handling request " + REQUEST_ID.get());
}
```

The binding is available only while the scoped operation runs. Unlike mutable `ThreadLocal` state, a scoped value is designed for one-way sharing of a value through a bounded call tree. For context that is only needed by one or two methods, ordinary parameters are often simpler.

## Practical guidelines

- Prefer `ExecutorService` over manually starting and tracking threads.
- Use virtual threads for large numbers of tasks that mostly block on I/O; use bounded parallelism for CPU-heavy work.
- Keep shared mutable state small. Use atomics for simple independent values and locks for multi-step invariants.
- Propagate interruption and define how failures, timeouts, and cancellation should behave.
- Use structured concurrency when its preview status is acceptable and subtasks belong to one operation.
- Measure real workloads. More threads do not automatically mean better throughput.

For more detail, see the [Java 25 Virtual Threads guide](https://docs.oracle.com/en/java/javase/25/core/virtual-threads.html), [JEP 444](https://openjdk.org/jeps/444), [JEP 505](https://openjdk.org/jeps/505), and [JEP 506](https://openjdk.org/jeps/506).
