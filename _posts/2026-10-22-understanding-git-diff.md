---
layout: post
title: "Understanding Git Diff Syntax"
subtitle: "How to read changed files, hunks, and line markers"
author: Somaditya Basak
tags: [git, version-control, programming]
---

`git diff` shows how text differs between two versions of a file. Its default output uses a format called **unified diff**: a little context around each change, with prefixes that distinguish added, removed, and unchanged lines.

## A small example

Suppose a file changes from:

```text
color = "blue"
enabled = false
```

to:

```text
color = "green"
enabled = true
```

A unified diff could look like this:

```diff
diff --git a/settings.txt b/settings.txt
index 12ab34c..56de78f 100644
--- a/settings.txt
+++ b/settings.txt
@@ -1,2 +1,2 @@
-color = "blue"
+color = "green"
-enabled = false
+enabled = true
```

## File headers

The first lines identify the file and the versions being compared:

- `diff --git a/settings.txt b/settings.txt` begins a file's diff. The `a/` and `b/` prefixes conventionally refer to the old and new sides.
- `index 12ab34c..56de78f 100644` shows abbreviated object IDs for the old and new contents, followed by the file mode. This line may be omitted in some kinds of diff.
- `--- a/settings.txt` labels the old file.
- `+++ b/settings.txt` labels the new file.

For a newly created or deleted file, one side may instead be labeled `/dev/null`, meaning that there was no file on that side.

## Hunk headers and line prefixes

A **hunk** is a section containing nearby changes. Its header looks like this:

```text
@@ -1,2 +1,2 @@
```

The numbers describe ranges in the old and new files:

- `-1,2` means the hunk covers 2 lines starting at line 1 of the old file.
- `+1,2` means it covers 2 lines starting at line 1 of the new file.

If a range contains only one line, Git may omit the count. For example, `@@ -4 +4,2 @@` means one old line beginning at line 4 and two new lines beginning at line 4. Git may add a function or section name after the closing `@@` to help orient you.

Within a hunk, the first character has a specific meaning:

```diff
 context line: unchanged
-removed line: present only in the old version
+added line: present only in the new version
```

That leading space on an unchanged line is part of the diff format. It provides context but is not an addition to the file.

## Reading counts

The hunk counts must match the lines shown:

- Count lines prefixed with a space and `-` toward the old range.
- Count lines prefixed with a space and `+` toward the new range.
- A removed line (`-`) counts only toward the old range.
- An added line (`+`) counts only toward the new range.

For example:

```diff
@@ -10,3 +10,4 @@
 keep this
-remove this
+add this
+add another line
 keep that
```

The old range has three lines: two context lines and one removed line. The new range has four: two context lines and two added lines.

## Other lines you may encounter

Some output contains information beyond ordinary text edits:

- `\ No newline at end of file` notes that a file does not end with a newline character. It is metadata, not a line to copy into the file.
- `old mode 100644` and `new mode 100755` indicate a file permission change, such as making a script executable.
- `rename from ...` and `rename to ...` identify a detected rename. Git infers renames by comparing file contents; a rename may also have edits in its hunks.
- `Binary files ... differ` means Git detected a binary change and did not print text hunks.
- `+` and `-` lines in a diff are markers. When copying code from a diff, remove those prefixes if you want the actual file contents.

## Comparing different things

The format stays similar while the two sides you compare change:

```sh
# Unstaged edits compared with the index
git diff

# Staged edits compared with the last commit
git diff --cached

# Compare two commits
git diff main..feature

# Compare one file between two commits
git diff main..feature -- src/app.cpp
```

In `git diff`, `main..feature` compares the trees named by those two commits; it does not show the commit history between them. Use `git log main..feature` to inspect commits reachable from `feature` but not from `main`.

## Useful display options

```sh
# Show fewer or more context lines around each hunk
git diff -U1
git diff -U10

# Show a summary of changed files
git diff --stat

# Show only paths that differ
git diff --name-only

# Ignore whitespace-only changes
git diff -w
```

Whitespace can matter in some languages and files, so `-w` is useful for review but should not be used to conclude that two files are equivalent in every context.

## A quick mental model

Read a unified diff from the outside in: identify the file, read the hunk header to locate the changed lines, then interpret each line by its first character. A `-` line is removed, a `+` line is added, and a leading space is context. Once those conventions become familiar, even large diffs become much easier to scan.
