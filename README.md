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
  technology available (Core Text on Mac, DirectWrite on Windows, etc.), and
  support Unicode fully.

* ***Reliability***. Crashing, hanging, or losing work should never happen.

* ***Developer friendliness***. It should be easy to customize xi editor, whether
  by adding plug-ins or hacking on the core.

Screenshot (will need to be updated as syntax coloring and UI polish is added):

![xi screenshot](/doc/img/xi-mac-screenshot.png?raw=true)

## Getting started

### Requirements
- [Xcode 9.x](https://developer.apple.com/xcode/)
- [Rust](https://www.rust-lang.org/). We test against the latest stable version,
and recommend installing through [rustup](https:://rustup.rs).
- `cmake`. We recommend installing through homebrew, with `brew install cmake`.


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

### Troubleshooting

The most common cause of a failed build is an outdated version of `rustc`.
If you've installed with rustup, make sure Rust is up to date by running
`rustup update stable`.


## Configuration

User settings are currently stored in files; the general preferences are
located at `~/Library/Application Support/XiEditor/preferences.xiconfig`.
This file can be opened from File > Preferences (⌘ + ,).

Users are encouraged to try out
[Inconsolata](http://levien.com/type/myfonts/inconsolata.html), with which
Xi is principally tested.

### Theme

A few theme files are bundled with the application. A theme can be selected
from the Debug > Theme menu. There is not yet a mechanism for including
custom themes.


## Authors

The main author is Raph Levien.

## Contributions

We gladly accept contributions via GitHub pull requests, as long as the author
has signed the Google Contributor License. Please see
[CONTRIBUTING.md](CONTRIBUTING.md) for more details.

### Disclaimer

This is not an official Google product (experimental or otherwise), it
is just code that happens to be owned by Google.
