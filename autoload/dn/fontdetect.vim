" Vim plugin for detecting fonts
" Last change: 2018 Aug 6
" Maintainer: David Nebauer
" License: GPL3

" Control statements    {{{1
set encoding=utf-8
scriptencoding utf-8

let s:save_cpo = &cpoptions
set cpoptions&vim

" Documentation    {{{1

""
" @section Introduction, intro
" @order usage credits
" There are some rough edges in Vim related to the detection of fonts. Vim
" supplies the |getfontname()| function that seems ideal for detecting
" whether a font is available, but there are a couple of problems. First,
" |getfontname()| cannot be called until the GUI has started (i.e., until
" the |GUIEnter| event occurs), which means that it can't be used from
" .vimrc (or .gvimrc). This makes it hard to define other settings that
" depend on the font (e.g., the Powerline plugin's g:Powerline_symbols
" setting must be defined before |GUIEnter| occurs).
" 
" In addition, the GTK+ 2 GUI seems unable to determine whether a given
" font is installed, so |getfontname()| always simply returns the input
" argument, and setting 'guifont' always succeeds even if the font is not
" present.
" 
" @plugin(name) works around these issues, providing methods for detecting
" which fonts are installed on the system.
" 
" At present, the following platforms are supported:
" 
" * Linux (using fontdetect for GTK+ 2 GUI and xlsfonts for X11)
" * Windows (by querying the registry)
" * Mac OS X (by using python to query the system Cocoa API)

""
" @section Usage, usage
" 
" @plugin(name) provides the two functions for detecting fonts.
" @function(dn#fontdetect#hasFontFamily) checks whether a single font is
" available and @function(dn#fontdetect#firstFontFamily) locates the first
" available font in a list of fonts.
" 
" A font family should be specified as a string with unescaped spaces,
" e.g., "DejaVu Sans Mono", "Consolas", etc. Do not replace spaces with
" underscores.
" 
" Font detection is case-insensitive.
" 
" If using X11 fonts, e.g., console vim, use only the font family. Do not
" use an X logical font description (XLFD).
" 
" The additional function @function(dn#fontdetect#reset) causes rescanning
" of font families. It is useful if a font has been added to the system
" during an editing session.

""
" @section Credits, credits
" 
" The method of listing installed fonts on OS X is taken from 
" http://stackoverflow.com/questions/1113040/list-of-installed-fonts-os-x-c.
" 
" @plugin(name) is based on the vim-fontdetect plugin developed by Michael
" Henry, located at https://github.com/drmikehenry/vim-fontdetect.

" }}}1

" Script variables

" s:fonts - fonts installed on system    {{{1
let s:fonts = {}
" }}}1

" Script functions

" s:getFontsUsingFontconfig()    {{{1

""
" @private
" Return |List| of installed fonts using fontconfig fc-list utility.
function! s:getFontsUsingFontconfig() abort
    if !executable('fc-list') | return [] | endif
    return systemlist("fc-list --format '%{family}\n'")
endfunction

" s:getFontsUsingPythonCocoa()    {{{1

""
" @private
" Use Cocoa font manager to return |List| of all installed font families on
" Apple Mac. More specifically, uses the python interface to Apple's cocoa
" api for Mac. Fails silently and returns an empty |List| if unable to use
" python or to successfully access the Cocoa font manager.
if has('python')
python << endpython
def fontdetect_listFontFamiliesUsingCocoa():
    try:
        import Cocoa
    except ImportError:
        return []
    manager = Cocoa.NSFontManager.sharedFontManager()
    font_families = list(manager.availableFontFamilies())
    return font_families
endpython
endif
function! s:getFontsUsingPythonCocoa() abort
    if !has('python') | return [] | endif
    return pyeval('fontdetect_listFontFamiliesUsingCocoa()')
endfunction

" s:getFontsUsingWindowsRegistry()    {{{1

""
" @private
" Return |List| of installed fonts available on windows operating systems.
function! s:getFontsUsingWindowsRegistry() abort
    " use reg command    {{{2
    if !executable('reg')
        return []
    endif
    " get and tidy registry output    {{{2
    let l:output = systemlist('reg query "HKLM\SOFTWARE\Microsoft' .
                \ '\Windows NT\CurrentVersion\Fonts"')
    unlet l:output[0]  " remove registry key at start of output
    call filter(l:output, 'strlen(v:val) > 0')  " remove blank lines
    " extract font family from each line    {{{2
    " - all lines begin with leading spaces and can have spaces in the
    "   font family portion
    " - lines have one of the following formats:
    "     Font family REG_SZ FontFilename
    "     Font family (TrueType) REG_SZ FontFilename
    "     Font family 1,2,3 (TrueType) REG_SZ FontFilename
    " - throw away everything before and after the font family
    " - assume that any '(' is not part of the family name
    " - assume digits followed by comma indicates point size
    call map(l:output, 'substitute(l:output,'
                \ . ''' *\(.\{-}\)\ *\((\|\d\+,\|REG_SZ\).\{-}$'', '
                \ . '''\1'', ''g'')')
    " return result    {{{2
    return l:output    " }}}2
endfunction

" s:getFontsUsingXlsfonts()    {{{1

""
" @private
" Return |List| of registered X server fonts using xlsfonts utility.
function! s:getFontsUsingXlsfonts() abort
    if !executable('xlsfonts') | return [] | endif
    let l:output = systemlist('xlsfonts')
    call filter(l:output, 'len(split(v:val, ''-'', 1)) == 15')
    call map(l:output, '(split(v:val, ''-''))[1]')
    return uniq(sort(l:output))
endfunction

" s:setFonts()    {{{1

""
" @private
" Sets list of installed fonts using method appropriate for environment.
function! s:setFonts() abort
    " get font list    {{{2
    if has('win32') || has('win64')                        " windows
        let l:families = s:getFontsUsingWindowsRegistry()
    elseif has('macunix')                                  " mac
        let l:families = s:getFontsUsingPythonCocoa()
        " fall back on fontconfig
        if len(l:families) == 0 && executable('fc-list')
            let l:families = s:getFontsUsingFontconfig()
        endif
    elseif has('gui_gtk2') || has('gui_gtk3')              " unix (gtk2+)
        if executable('fc-list')
            let l:families = s:getFontsUsingFontconfig()
        endif
    elseif has('x11') && executable('xlsfonts')            " unix (x11)
        let l:families = s:getFontsUsingXlsfonts()
    else  " handle failure
        let l:families = []
    endif
    if empty(l:families) | echomsg 'No way to detect fonts' | endif

    " load s:fonts variable    {{{2
    call map(l:families, 'tolower(v:var)')
    let s:fonts = {}
    for l:font_family in l:families
        let s:fonts[l:font_family] = v:true
    endfor    " }}}2
endfunction

" }}}1

" Public functions

" dn#fontdetect#firstFontFamily(font_families)    {{{1

""
" @public
" Return the first installed font family |String| from the specified |List|
" of {font_families}, or "" if none are installed. Any spaces in font
" family names must be unescaped. For example (using Windows GUI):
" > 
"   let &guifont = dn#fontdetect#firstFontFamily([
"               \ 'DejaVu Sans Mono',
"               \ 'Consolas',
"               \ ]) . ':h14'
" <
function! dn#fontdetect#firstFontFamily(font_families) abort
    for l:font_family in a:font_families
        if dn#fontdetect#hasFontFamily(l:font_family)
            return l:font_family
        endif
    endfor
    return ''
endfunction

" dn#fontdetect#hasFontFamily(font_family)    {{{1

""
" @public
" Determine whether a {font_family} is available. Do not escape spaces in
" the {font_family} name. Returns a |String| font family name, or "" if it
" is not available. For example (using GTK+ 2 GUI):
" >
"   if dn#fontdetect#hasFontFamily('DejaVu Sans Mono')
"       let &guifont = 'DejaVu Sans Mono 14'
"   endif
" <
function! dn#fontdetect#hasFontFamily(font_family) abort
    if !exists('s:fonts') | call s:setFonts() | endif
    return has_key(s:fonts, tolower(a:font_family))
endfunction

" dn#fontdetect#reset()    {{{1

""
" @public
" Erase any previously generated font list.
function! dn#fontdetect#reset() abort
    let s:fonts = {}
endfunction
" }}}1

" Control statements    {{{1
let &cpoptions = s:save_cpo
unlet s:save_cpo
" }}}1

" vim:tw=75:fdm=marker:
