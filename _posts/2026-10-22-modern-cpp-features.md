---
layout: post
title: "Modern C++: Writing More with Less"
subtitle: "A practical tour of compact C++ features from C++14 through C++23"
author: Somaditya Basak
tags: [c++, cpp, programming, modern-cpp]
---

C++ has gained a steady stream of features since C++14 that make common code shorter and more expressive. The important change is not simply fewer characters: type deduction, standard vocabulary types, ranges, and compile-time constraints can make intent clearer while preserving control over performance and resources.

This tour focuses on finalized features in C++14, C++17, C++20, and C++23. Each example is independent unless noted.

## C++14: generic lambdas and simpler factories

C++14 lets a lambda parameter use `auto`, so one small function can work with several types:

```cpp
auto multiply = [](auto value, auto factor) {
    return value * factor;
};

auto twice = multiply(21, 2);       // int: 42
auto scaled = multiply(1.5, 2.0);   // double: 3.0
```

Before generic lambdas, the same idea often required a function template or separate overloads. C++14 also added `std::make_unique`, which creates an object managed by `std::unique_ptr` without spelling out `new`:

```cpp
auto name = std::make_unique<std::string>("Ada");
```

Prefer the smart pointer factory over a raw owning pointer: ownership is explicit, and the object is cleaned up automatically.

## C++17: describe values directly

Structured bindings unpack pairs, tuples, and suitable structs:

```cpp
std::map<std::string, int> scores{
    {"Ada", 98},
    {"Linus", 95},
};

for (const auto& [name, score] : scores) {
    std::cout << name << ": " << score << '\n';
}
```

The `if` and `switch` statements can also introduce a variable whose scope is limited to that decision:

```cpp
if (auto it = scores.find("Ada"); it != scores.end()) {
    std::cout << it->second << '\n';
}
```

This keeps a lookup result close to the condition that uses it.

`std::optional` expresses a value that might be absent without using a sentinel such as `-1`:

```cpp
std::optional<int> find_score(std::string_view name) {
    if (name == "Ada") {
        return 98;
    }
    return std::nullopt;
}
```

The caller can check whether a result exists before using it. C++17 also introduced `std::variant` for a value that may be one of a fixed set of types, and `std::string_view` for a non-owning view of character data.

## C++20: constraints and ranges

Concepts let a template state what operations it needs. This example accepts integral types and rejects unrelated types during overload resolution:

```cpp
#include <concepts>

template <std::integral T>
constexpr T twice(T value) {
    return value + value;
}
```

The constraint documents the function's requirements and usually gives a more direct diagnostic than an error deep inside a template instantiation.

Ranges let us express a transformation as a sequence of operations. Here, a view filters even numbers and then squares them:

```cpp
#include <ranges>
#include <vector>

std::vector<int> values{1, 2, 3, 4, 5, 6};

auto even_squares = values
    | std::views::filter([](int n) { return n % 2 == 0; })
    | std::views::transform([](int n) { return n * n; });

for (int n : even_squares) {
    std::cout << n << ' '; // 4 16 36
}
```

The views are lazy: they describe how to produce values and do work as the range is traversed, rather than building an intermediate vector at each step.

C++20 also added designated initializers for aggregates:

```cpp
struct Point {
    double x;
    double y;
};

Point origin{.x = 0.0, .y = 0.0};
```

The designators must follow the members' declaration order. C++20 coroutines also provide language support for writing suspendable functions, though using them generally involves a coroutine library or framework.

## C++23: useful results without exceptions

`std::expected<T, E>` represents either a successful value of type `T` or an error of type `E`. It is useful when failure is an ordinary result callers should handle:

```cpp
#include <expected>
#include <string>

std::expected<int, std::string> divide(int numerator, int denominator) {
    if (denominator == 0) {
        return std::unexpected("division by zero");
    }
    return numerator / denominator;
}

auto result = divide(10, 2);
if (result) {
    std::cout << *result << '\n';
} else {
    std::cerr << result.error() << '\n';
}
```

C++23 adds `std::ranges::to`, which makes it straightforward to materialize a range pipeline into a container:

```cpp
#include <ranges>
#include <vector>

std::vector<int> values{1, 2, 3, 4, 5, 6};

auto even_squares = values
    | std::views::filter([](int n) { return n % 2 == 0; })
    | std::views::transform([](int n) { return n * n; })
    | std::ranges::to<std::vector>();
```

Unlike the previous lazy view, this creates a `std::vector<int>` containing `{4, 16, 36}`.

## Compact code still needs clear ownership

Modern C++ makes it easier to state intent with less scaffolding, but concise code is not automatically good code. In particular:

- `auto` deduces a type; use it when the initializer makes that type clear.
- `std::string_view` and range views do not own their underlying data. Do not keep them past the lifetime of that data.
- Use `std::unique_ptr` for exclusive ownership and `std::shared_ptr` only when ownership is genuinely shared.
- Prefer standard algorithms and ranges when they make the transformation easier to understand, not just shorter.
- Check your compiler and standard library support when adopting newer language or library features.

For further reading, see the [C++ language history overview](https://en.cppreference.com/w/cpp/language/history.html), [C++20 ranges](https://en.cppreference.com/w/cpp/ranges.html), and [C++23 `std::expected`](https://en.cppreference.com/w/cpp/utility/expected.html).
