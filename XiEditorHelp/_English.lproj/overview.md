---
title: About Xi-Editor
description: An overview of Xi-Editor
order: -.INF
---

_(Pronounced "Zigh")_

The xi editor project is an attempt to build a high quality text editor, using modern software engineering techniques. It is initially built for Mac OS X, using Cocoa for the user interface. There are also frontends for other operating systems available from third-party developers.

Goals include:

- **Incredibly high performance**. All editing operations should commit and paint
  in under 16ms. The editor should never make you wait for anything.
- **Beauty**. The editor should fit well on a modern desktop, and not look like a
  throwback from the &apos;80s or &apos;90s. Text drawing should be done with the best
  technology available (Core Text on Mac, DirectWrite on Windows, etc.), and
  support Unicode fully.
- **Reliability**. Crashing, hanging, or losing work should never happen.
- **Developer friendliness**. It should be easy to customize xi editor, whether by adding plug-ins or hacking on the core.
