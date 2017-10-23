<h1 align="center">
  <a href="https://github.com/google/xi-editor"><img src="icons/xi-editor.png" alt="Xi Editor" width="256" height="256"/></a><br>
  <a href="https://github.com/google/xi-editor">Xi Editor</a>
</h1>

<h4 align="center">A modern editor with a backend written in Rust.</h4>

The xi editor project is an attempt to build a high quality text editor,
using modern software engineering techniques. It is initially built for
macOS, using Cocoa for the user interface, but other targets are planned.

Goals include:

* ***Incredibly high performance***. All editing operations should commit and paint
  in under 16ms. The editor should never make you wait for anything.

* ***Beauty***. The editor should fit well on a modern desktop, and not look like a
  throwback from the ’80s or ’90s. Text drawing should be done with the best
  technology available (Core Text on macOS, DirectWrite on Windows, etc.), and
  support Unicode fully.

* ***Reliability***. Crashing, hanging, or losing work should never happen.

* ***Developer friendliness***. It should be easy to customize xi editor, whether
  by adding plug-ins or hacking on the core.

Screenshot (will need to be updated as syntax coloring and UI polish is added):

![xi screenshot](/doc/img/xi-mac-screenshot.png?raw=true)

## Getting started
You need [Xcode 8.2](https://developer.apple.com/xcode/) (only on macOS) and [Rust](https://www.rust-lang.org/) (version 1.13+ is
recommended and supported). You should have `cargo` in your path. You'll also need
cmake installed, to run the syntax highlighter. If you have homebrew,
easiest to run `brew install cmake`. It is possible to build without cmake,
but requires some editing of build scripts.

Note: the front-end and back-end are now split into two separate repositories. This
is the front-end, and the back-end (or core) is now in:
[xi-editor](https://github.com/google/xi-editor). Make sure to have that checked out
as a subdirectory.

```
> git clone https://github.com/google/xi-mac
> cd xi-mac
> git clone https://github.com/google/xi-editor
> xcodebuild
> open build/Release/XiEditor.app
```

Or `open XiEditor.xcodeproj` and hit the Run button.

It will look better if you have
[InconsolataGo](http://levien.com/type/myfonts/inconsolata.html) installed, a
customized version of Inconsolata tuned for code editing. You can change fonts
per window in the Font menu or with `Cmd-Shift-T`. To choose another default font,
edit the `CTFontCreateWithName()` call in EditView.swift.



## Authors

The main author is Raph Levien.

## Contributions

We gladly accept contributions via GitHub pull requests, as long as the author
has signed the Google Contributor License. Please see
[CONTRIBUTING.md](CONTRIBUTING.md) for more details.

### Disclaimer

This is not an official Google product (experimental or otherwise), it
is just code that happens to be owned by Google.
