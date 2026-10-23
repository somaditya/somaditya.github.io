---
layout: post
title: "MathJax Sample: Fourier and Laplace Transforms"
subtitle: "A quick tour of mathematical notation in blog posts"
author: Somaditya Basak
mathjax: true
tags: [math, mathjax, transforms]
---

![fourier](/assets/img/fourier.jpg){: .mx-auto.d-block :}

This sample post demonstrates inline and display equations rendered with MathJax. For example, Euler's identity is \(e^{i\pi} + 1 = 0\), and the Gaussian integral is

$$
\int_{-\infty}^{\infty} e^{-x^2}\,dx = \sqrt{\pi}.
$$

## Fourier transform

Using angular frequency \(\omega\), define the Fourier transform and its inverse by

$$
\mathcal{F}\{f\}(\omega)
= \widehat{f}(\omega)
= \int_{-\infty}^{\infty} f(t)e^{-i\omega t}\,dt,
\qquad
f(t)
= \frac{1}{2\pi}\int_{-\infty}^{\infty}
\widehat{f}(\omega)e^{i\omega t}\,d\omega.
$$

As an example, the transform of a Gaussian is another Gaussian:

$$
f(t) = e^{-t^2/(2\sigma^2)}
\quad\Longrightarrow\quad
\widehat{f}(\omega)
= \sigma\sqrt{2\pi}\,e^{-\sigma^2\omega^2/2},
\qquad \sigma > 0.
$$

Differentiation in time becomes multiplication by \(i\omega\) in the frequency domain:

$$
\mathcal{F}\{f^{(n)}\}(\omega)
=(i\omega)^n\widehat{f}(\omega).
$$

The convolution theorem turns convolution into pointwise multiplication. With
\((f \* g)(t) = \int\_{-\infty}^{\infty} f(\tau)g(t-\tau)\,d\tau\), it reads

$$
\mathcal{F}\{f*g\}(\omega)
= \widehat{f}(\omega)\widehat{g}(\omega).
$$

## Laplace transform

For a causal signal, the one-sided Laplace transform is

$$
\mathcal{L}\{f\}(s)
= F(s)
= \int_0^\infty f(t)e^{-st}\,dt.
$$

For \(f(t)=e^{-at}\), where \(a>0\), direct integration gives

$$
\mathcal{L}\{e^{-at}\}(s)
= \int_0^\infty e^{-(s+a)t}\,dt
= \frac{1}{s+a},
\qquad \operatorname{Re}(s)>-a.
$$

The transform of a derivative also records the initial value:

$$
\mathcal{L}\{f'\}(s)
= sF(s)-f(0^+).
$$

This is why Laplace transforms are useful for initial-value problems. For example,
transforming \(y'(t)+ay(t)=0\), with \(y(0)=y_0\), gives

$$
sY(s)-y_0+aY(s)=0
\quad\Longrightarrow\quad
Y(s)=\frac{y_0}{s+a}
\quad\Longrightarrow\quad
y(t)=y_0e^{-at}.
$$

## A transform pair in action

The Fourier transform can turn a differential equation into an algebraic one.
For the heat equation

$$
\frac{\partial u}{\partial t}
= \kappa\frac{\partial^2 u}{\partial x^2},
\qquad \kappa > 0,
$$

transform in \(x\), using frequency \(\xi\). Since
\(\mathcal{F}\_x\{\partial_x^2 u\}=-\xi^2\widehat{u}\), the equation becomes

$$
\frac{\partial \widehat{u}}{\partial t}
= -\kappa\xi^2\widehat{u}.
$$

Solving this ordinary differential equation in time yields

$$
\widehat{u}(\xi,t)
= \widehat{u}(\xi,0)e^{-\kappa\xi^2t}.
$$

The exponential factor damps high frequencies most rapidly, which is the frequency-domain
view of heat smoothing out sharp variations.
