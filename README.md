<h1 align="center">
  <a href="http://xi-editor.io/xi-editor"><img src="icons/xi-editor.png" alt="Xi Editor" width="256" height="256"/></a><br>
  <a href="http://xi-editor.io/xi-editor">Xi Editor</a>
</h1>

<p align="center"><em>(pronounced "Zigh")</em></p>

<h4 align="center">A modern editor with a backend written in Rust.</h4>

***Note:*** *This project is still in an early state. Prebuilt binaries will be made available once we start creating versioned releases.*

The xi-editor project is an attempt to build a high quality and fast text editor,
using modern software engineering techniques. This reference frontend is
built for macOS, using Cocoa for the user interface, but there are work
in progress frontends for other platforms as well. Consult the
[list in the xi-editor core README](https://github.com/xi-editor/xi-editor#frontends)
for details.

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
and recommend installing through [rustup](https://rustup.rs).


Note: the front-end and back-end are split into two separate repositories. This
is the front-end, and the back-end (or core) is now in
[xi-editor](https://github.com/xi-editor/xi-editor). Make sure to have that checked out
as a subdirectory.

```
> git clone https://github.com/xi-editor/xi-mac
> cd xi-mac
> git clone https://github.com/xi-editor/xi-editor
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

The default font for XiEditor is 
[Inconsolata](http://levien.com/type/myfonts/inconsolata.html), which
is bundled with the app.


### Theme

A few theme files are bundled with the application. A theme can be selected
from the Debug > Theme menu. There is not yet a mechanism for including
custom themes.


## Authors

The xi-editor project was started by Raph Levien but has since received
contributions from a number of other people. See the [AUTHORS](AUTHORS)
file for details.


## License

This project is licensed under the Apache 2 [license](LICENSE). The bundled fonts are under a
different license, the Open Font License. See the [fonts](fonts) directory for the fonts and associated
license.


## Contributions

We gladly accept contributions via GitHub pull requests. Please see
[CONTRIBUTING.md](CONTRIBUTING.md) for more details.

If you are interested in contributing but not sure where to start, there is
an active IRC channel at #xi on irc.mozilla.org. There is also a subreddit at
[/r/xi_editor](https://www.reddit.com/r/xi_editor/).
