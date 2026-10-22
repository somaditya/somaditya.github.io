---
layout: post
title: "Linear Algebra: Vectors, Transformations, and Eigenvectors"
subtitle: "A visual-friendly introduction to a few essential concepts"
author: Somaditya Basak
mathjax: true
tags: [math, mathjax, linear-algebra]
---

Linear algebra studies vectors, the spaces they inhabit, and the transformations that act on them. It is useful in fields ranging from computer graphics and data science to physics and differential equations.

## Vectors and linear combinations

A vector is an ordered collection of numbers. In two dimensions, for example,

$$
\mathbf{v} =
\begin{bmatrix}
2\\
1
\end{bmatrix}
$$

describes a direction and magnitude in the plane. Given vectors \\(\mathbf{v}_1,\ldots,\mathbf{v}_n\\), a linear combination is any expression of the form

$$
c_1\mathbf{v}_1 + c_2\mathbf{v}_2 + \cdots + c_n\mathbf{v}_n,
$$

where the \\(c_i\\) are scalars. The set of all linear combinations of a collection of vectors is their **span**. If the vectors are independent (none can be built from the others), they provide distinct directions in that span.

A **basis** is a linearly independent set of vectors that spans a space. The standard basis for the plane is

$$
\mathbf{e}_1 =
\begin{bmatrix}
1\\
0
\end{bmatrix},
\qquad
\mathbf{e}_2 =
\begin{bmatrix}
0\\
1
\end{bmatrix}.
$$

Every vector in the plane can be written as a combination of these two:

$$
\begin{bmatrix}
x\\
y
\end{bmatrix}
= x\mathbf{e}_1 + y\mathbf{e}_2.
$$

## Matrices as linear transformations

A matrix can represent a function that transforms vectors while preserving vector addition and scalar multiplication. For example,

$$
A =
\begin{bmatrix}
2 & 0\\
0 & 1
\end{bmatrix}
$$

scales the horizontal coordinate by \\(2\\), while leaving the vertical coordinate unchanged:

$$
A
\begin{bmatrix}
x\\
y
\end{bmatrix}
=
\begin{bmatrix}
2x\\
y
\end{bmatrix}.
$$

In general, multiplying a matrix \\(A\\) by a vector \\(\mathbf{x}\\) produces the transformed vector \\(A\mathbf{x}\\).

## Eigenvectors and eigenvalues

Some vectors keep their direction under a transformation. A nonzero vector \\(\mathbf{v}\\) is an **eigenvector** of \\(A\\) if applying \\(A\\) only scales it:

$$
A\mathbf{v} = \lambda\mathbf{v}.
$$

The scalar \\(\lambda\\) is its **eigenvalue**. A positive eigenvalue stretches the vector, a negative one reverses and scales it, and an eigenvalue of zero maps it to the zero vector.

For the matrix above, the horizontal basis vector is an eigenvector:

$$
A
\begin{bmatrix}
1\\
0
\end{bmatrix}
=
\begin{bmatrix}
2\\
0
\end{bmatrix}
=
2
\begin{bmatrix}
1\\
0
\end{bmatrix}.
$$

Its eigenvalue is \\(2\\). The vertical basis vector is also an eigenvector:

$$
A
\begin{bmatrix}
0\\
1
\end{bmatrix}
=
\begin{bmatrix}
0\\
1
\end{bmatrix}
=
1
\begin{bmatrix}
0\\
1
\end{bmatrix},
$$

with eigenvalue \\(1\\). Geometrically, these are the directions that remain fixed while the matrix stretches the plane.

## Finding eigenvalues

Starting from \\(A\mathbf{v}=\lambda\mathbf{v}\\), move both sides to one side and factor out \\(\mathbf{v}\\):

$$
(A-\lambda I)\mathbf{v}=\mathbf{0},
$$

where \\(I\\) is the identity matrix. For this equation to have a nonzero solution, \\(A-\lambda I\\) must be singular, so its determinant must vanish:

$$
\det(A-\lambda I)=0.
$$

For our example,

$$
\det
\begin{bmatrix}
2-\lambda & 0\\
0 & 1-\lambda
\end{bmatrix}
=(2-\lambda)(1-\lambda)=0.
$$

Thus the eigenvalues are \\(\lambda=2\\) and \\(\lambda=1\\). Substituting each value into \\((A-\lambda I)\mathbf{v}=\mathbf{0}\\) gives the corresponding eigenvector directions.

Eigenvectors are useful because they reveal the natural directions of a transformation. In higher-dimensional applications, they help describe stable patterns, dominant directions in data, and the long-term behavior of repeated transformations.
