---
layout: post
title: "From C to x86 Assembly"
subtitle: "Following a small C function through the compiler"
author: Somaditya Basak
tags: [c, compilers, assembly, x86]
---

When you compile a C program, the compiler translates its operations into instructions for a target processor. Let’s follow a program that prints a Fibonacci sequence and connect its C loop to x86-64 assembly.

## The C program

Save this as `fibonacci.c`:

```c
#include <stdio.h>

void print_fibonacci(int count)
{
    int previous = 0;
    int current = 1;

    for (int i = 0; i < count; i++) {
        printf("%d\n", previous);

        int next = previous + current;
        previous = current;
        current = next;
    }
}

int main(void)
{
    print_fibonacci(10);
    return 0;
}
```

The loop prints the current value, then advances the pair. Starting from 0 and 1, it prints `0, 1, 1, 2, 3, 5, 8, 13, 21, 34`. C describes the work, but leaves register allocation, instruction selection, and the mechanics of calling `printf` to the compiler and platform ABI.

## Ask GCC to emit assembly

GCC can stop after generating assembly instead of assembling and linking a complete program:

```sh
gcc -O2 -S -masm=intel fibonacci.c -o fibonacci.s
```

Here, `-O2` enables optimization, `-S` writes assembly source, and `-masm=intel` selects Intel syntax. The target is the machine on which GCC is running; the example below assumes 64-bit x86 running a System V ABI, commonly used by Linux.

The compiler emits additional directives and metadata. The central part of `print_fibonacci` can look like this. It uses GNU assembler directives with Intel instruction syntax; the `nasm` fence is used to enable syntax highlighting:

```nasm
; Representative Intel syntax, x86-64 System V output
.LC0:
    .string "%d\n"

print_fibonacci:
    test edi, edi
    jle .Lreturn
    push r12
    push rbp
    push rbx
    mov r12d, edi
    xor ebp, ebp
    mov ebx, 1
.Lloop:
    lea rdi, .LC0[rip]
    mov esi, ebp
    xor eax, eax
    call printf@PLT
    lea edx, [rbp + rbx]
    mov ebp, ebx
    mov ebx, edx
    sub r12d, 1
    jne .Lloop
    pop rbx
    pop rbp
    pop r12
.Lreturn:
    ret
```

This is an illustrative optimized listing; exact instructions and labels vary between compiler versions and targets. Follow the loop state:

- The `count` argument arrives in `edi`. `test` and `jle` handle zero or negative counts without entering the loop.
- `ebp` holds `previous`, `ebx` holds `current`, and `r12d` holds the remaining iteration count. These registers are saved on entry and restored before returning because they are callee-saved in the System V ABI.
- Before `printf`, the code puts the format-string address in `rdi` and the integer to print in `esi`, the first two argument registers. `xor eax, eax` indicates that no vector registers are used for variadic arguments.
- `call printf@PLT` calls the C library function. The three pushes also keep the stack correctly aligned for the call.
- `lea edx, [rbp + rbx]` adds the two sequence values without reading memory. Then the moves advance `previous` and `current`, and `sub`/`jne` repeat the loop until the requested count is reached.
- `ret` returns control to the caller.

The registers named `rdi` and `rsi` are the 64-bit versions of `edi` and `esi`; instructions using their 32-bit names operate on the lower halves.

## Why your assembly might differ

There is no single assembly listing for a C program. The output depends on the compiler, optimization level, target processor, and calling convention. For example, the update step could use separate add and move instructions instead of `lea`:

```nasm
; Also Intel syntax
    mov edx, ebp
    add edx, ebx
```

Both forms calculate the next Fibonacci value. `lea` combines the addition in one instruction, while the second form copies one operand before adding the other.

Calling conventions also matter. On 64-bit Windows, integer arguments are initially passed in `ecx` and `edx`, and `printf` arguments use different registers from the System V example. When building for a different platform, the compiler selects that platform’s conventions and target instructions.

## From source to executable

A typical build has several stages:

1. **Preprocessing** expands `#include` directives and macros.
2. **Compilation** analyzes the C program and generates assembly for the target.
3. **Assembly** converts assembly instructions into an object file containing machine code and metadata.
4. **Linking** combines object files and libraries into an executable, resolving references between them.

You can ask GCC to produce an object file directly:

```sh
gcc -O2 -c fibonacci.c -o fibonacci.o
```

The object file contains machine code, not the original C source or the readable assembly listing. GCC can also compile and link the complete program in one step:

```sh
gcc -O2 fibonacci.c -o fibonacci
```

The compiler driver invokes the necessary tools for you. If you want to inspect each stage, use `-E` to see preprocessed C, `-S` to emit assembly, and `-c` to stop after creating an object file.
