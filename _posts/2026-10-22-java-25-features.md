---
layout: post
title: "A Tour of Java 25"
subtitle: "Language improvements, scoped data, and JVM updates"
author: Somaditya Basak
tags: [java, java-25, programming]
---

Java 25 was released on September 16, 2025, and is an LTS release for many Java vendors. It includes finalized language and API features, several runtime improvements, and features that are still in preview or incubation. This article walks through a selection of changes; the links point to the corresponding OpenJDK JEPs.

## Smaller programs with less ceremony

[Compact Source Files and Instance Main Methods (JEP 512)](https://openjdk.org/jeps/512) is now a permanent feature. For small programs, a source file can omit the enclosing class and use an instance `main` method:

```java
void main() {
    IO.println("Hello, Java 25!");
}
```

The `IO` class provides simple console input and output. This is still Java: the compiler supplies an implicit class around the code, so a small example can grow into ordinary classes and packages as a program gets larger.

Java 25 also finalizes [Module Import Declarations (JEP 511)](https://openjdk.org/jeps/511). An import such as

```java
import module java.base;
```

imports the public types from packages exported by `java.base`. That includes commonly used types such as `List`, `Map`, and `Path`, reducing import boilerplate in examples and small tools. Regular package and type imports remain useful when explicit dependencies are preferable.

## More flexible constructors

[Flexible Constructor Bodies (JEP 513)](https://openjdk.org/jeps/513) lets a constructor validate or prepare arguments before calling `super(...)` or `this(...)`. For example:

```java
class Person {
    Person(String name) {
        System.out.println("Creating " + name);
    }
}

class Employee extends Person {
    Employee(String name) {
        String normalizedName = name.strip();
        if (normalizedName.isEmpty()) {
            throw new IllegalArgumentException("Name must not be blank");
        }
        super(normalizedName);
    }
}
```

The statements before `super(...)` must not use the object that is still being constructed. Here, validation only uses the constructor argument, so invalid input is rejected before the superclass constructor runs.

## Scoped values for request context

[Scoped Values (JEP 506)](https://openjdk.org/jeps/506) provide a way to share immutable data with methods called within a bounded scope. They can be a better fit than mutable `ThreadLocal` state for context such as a request ID:

```java
private static final ScopedValue<String> REQUEST_ID =
        ScopedValue.newInstance();

static void handleRequest(String requestId) {
    ScopedValue.where(REQUEST_ID, requestId).run(() -> {
        log("Request started");
        processRequest();
    });
}

static void log(String message) {
    System.out.println("[" + REQUEST_ID.get() + "] " + message);
}
```

While the bound action runs, its callees can read the request ID without threading it through every method parameter. The binding is limited to the dynamic scope of `run`; it is not general-purpose mutable storage.

## Primitive patterns are still in preview

[Primitive Types in Patterns, `instanceof`, and `switch` (JEP 507)](https://openjdk.org/jeps/507) is a third preview in Java 25, not a finalized feature. It extends pattern matching to primitive types. For example, a switch can match an object as an `int`, `long`, or `double`:

```java
static String describe(Object value) {
    return switch (value) {
        case int i -> "int: " + i;
        case long l -> "long: " + l;
        case double d -> "double: " + d;
        case String s -> "text: " + s;
        default -> "other";
    };
}
```

Preview features can change between releases and require explicit preview flags when compiling and running. Treat this as an example to explore, rather than a feature to use without checking your toolchain and deployment requirements.

## Runtime and performance work

Java 25 includes several changes that do not require rewriting application code:

- [Compact Object Headers (JEP 519)](https://openjdk.org/jeps/519) makes a compact object-header layout a product feature. It can reduce per-object memory overhead when enabled; it is not the default layout.
- [Generational Shenandoah (JEP 521)](https://openjdk.org/jeps/521) makes generational mode a product feature for the Shenandoah garbage collector. It remains opt-in; Shenandoah's default mode does not change.
- [Ahead-of-Time Method Profiling (JEP 515)](https://openjdk.org/jeps/515) and [Ahead-of-Time Command-Line Ergonomics (JEP 514)](https://openjdk.org/jeps/514) improve the JVM's ability to use profiling information from earlier runs to prepare applications for startup.
- Java Flight Recorder gains [cooperative sampling (JEP 518)](https://openjdk.org/jeps/518), [method timing and tracing (JEP 520)](https://openjdk.org/jeps/520), and experimental [CPU-time profiling (JEP 509)](https://openjdk.org/jeps/509).

These features can help with memory use, startup, garbage collection, and diagnostics, but their impact depends on the application and JVM configuration. Benchmark representative workloads before changing production settings.

## Other APIs and incubating work

The [Key Derivation Function API (JEP 510)](https://openjdk.org/jeps/510) is finalized. It provides a standard Java API for algorithms that derive keys from existing secret material; applications should choose parameters and algorithms appropriate to their security design rather than inventing their own derivation scheme.

The [Vector API (JEP 508)](https://openjdk.org/jeps/508) continues as an incubator API, and [Structured Concurrency (JEP 505)](https://openjdk.org/jeps/505) remains in preview. Incubator and preview features are not the same as finalized Java SE features, so check their status and release requirements before adopting them.

## Takeaway

Java 25 makes several useful features permanent: compact source files, module imports, flexible constructor bodies, scoped values, and the KDF API. Alongside those language and API changes, the release continues work on startup, memory use, garbage collection, and profiling. Preview and incubator features offer a look at what may come next, but should be evaluated separately from finalized features.

For the full release contents, see the [OpenJDK JDK 25 feature list](https://openjdk.org/projects/jdk/25/).
