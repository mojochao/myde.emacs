# My Development Environment

My Development Environment, or MyDE for short, is my personal Emacs configuration
for modern Emacs versions (minimum v29), providing a consistent, convenient DX
across Linux and macOS platforms.

It uses James Cherti's most excellent [Minimal Emacs](https://github.com/jamescherti/minimal-emacs.d)
base configuration as a foundation for building My Development Environment.

## Installation

Run the following commands to install MyDE configuration into your

```shell
git clone https://github.com/mojochao/myde.el
cd myde.el
make init     # clones the minimal-emacs.d repo locally for use
make link     # symlinks my custom elisp in the cloned minimal-emacs.d repo
make install  # symlinks the cloned minimal-emacs.d repo to emacs init directory
```

At this point, you should be able to launch Emacs, at which time packages
will be downloaded and configured as defined by MyDE elisp configuration.
