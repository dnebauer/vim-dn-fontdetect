vim-dn-fontdetect - global plugin to detect installed fonts
===========================================================

This plugin helps vim detect which fonts are installed on the system.

For example (using GTK+ 2 GUI):
```vim
    if fontdetect#hasFontFamily("DejaVu Sans Mono")
        let &guifont = "DejaVu Sans Mono 14"
    endif
```

At present, the following platforms are supported:

* Linux: using `fontdetect` on GTK+ 2 GUI and `xlsfonts` on X11

* Windows: by querying the registry

* Mac OS X: using a python interface to the Cocoa API

See documentation in [doc/fontdetect.txt](doc/fontdetect.txt) for installation instructions.

Based on [vim-fontdetect](https://github.com/drmikehenry/vim-fontdetect) by Michael Henry.

Distributed under vim's license.

Git repository: [https://github.com/dnebauer/vim-dn-fontdetect](https://github.com/dnebauer/vim-dn-fontdetect)
