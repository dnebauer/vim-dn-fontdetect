" Vim global plugin for detecting installed fonts
" Last Change: 2016-07-10
" Maintainer:  David Nebauer <david@nebauer.org>
" Credits:     Fork of Michael Henry's vim-fontdetect plugin at
"              https://github.com/drmikehenry/vim-fontdetect
" License:     Distributed under the same conditions as vim
"              See |license| in any vim installation

" SETTINGS:

" load once                                                            {{{1
if exists('autoloaded_fontdetect') | finish | endif
let autoloaded_fontdetect = 1

" save 'cpoptions' and set vim to enable line continuations            {{{1
let s:save_cpoptions = &cpoptions
set cpoptions&vim                                                    " }}}1

" PUBLIC FUNCTIONS:

" fontdetect#hasFontFamily(font_family)                                {{{1
"  intent: determine whether a font is available
"  params: font_family - font family to check
"                       [string, include spaces unescaped]
"  return: string/boolean - font family name if available
"                           '' if not available
function! fontdetect#hasFontFamily(font_family) abort
    if !exists('s:fonts') | call s:GetFonts() | endif
    return has_key(s:fonts, a:font_family)
endfunction

" fontdetect#firstFontFamily(font_families)                            {{{1
"  intent: return first available font family from list
"  params: font_families - font families to check
"                          [List, include spaces unescaped]
"  return: string/boolean - font family name if available
"                           '' if not available
function! fontdetect#firstFontFamily(font_families) abort
    for l:font_family in a:font_families
        if fontdetect#hasFontFamily(l:font_family)
            return l:font_family
        endif
    endfor
    return ''
endfunction                                                          " }}}1

" PRIVATE FUNCTIONS:

" s:GetFonts()                                                         {{{1
"  intent: get list of installed fonts using method appropriate for
"          environment
"  params: nil
"  return: nil
"  sets:   sets 's:fonts' variable
function! s:GetFonts() abort

    " windows                                                          {{{2
    if has('win32') || has('win64')
        let l:families = s:GetFontsUsingWindowsRegistry()

    " mac                                                              {{{2
    elseif has('macunix')
        let l:families = s:GetFontsUsingPythonCocoa()
        " fall back on fontconfig
        if len(l:families) == 0 && executable('fc-list')
            let l:families = s:GetFontsUsingFontconfig()
        endif

    " unix (gtk2)                                                      {{{2
    elseif has('gui_gtk2') && executable('fc-list')
        let l:families = s:GetFontsUsingFontconfig()

    " unix (x11)                                                       {{{2
    elseif has('x11') && executable('xlsfonts')
        let l:families = s:GetFontsUsingXlsfonts()

    " handle failure                                                   {{{2
    else
        let l:families = []
    endif
    if len(l:families) == 0
        echomsg 'No way to detect fonts'
    endif

    " build s:fonts                                                    {{{2
    let s:fonts = {}
    for l:font_family in l:families
        let s:fonts[l:font_family] = 1
    endfor                                                           " }}}2

endfunction

" SETTINGS:

" s:GetFontsUsingWindowsRegistry()                                     {{{1
"  intent: get list of installed fonts available on windows
"  params: nil
"  return: List of strings
function! s:GetFontsUsingWindowsRegistry() abort

    " use reg command                                                  {{{2
    if !executable('reg')
        return []
    endif

    " get and tidy registry output                                     {{{2
    let l:output = systemlist('reg query "HKLM\SOFTWARE\Microsoft' .
                \ '\Windows NT\CurrentVersion\Fonts"')

    " - remove registry key at start of output
    unlet l:output[0]

    " - remove blank lines
    call filter(l:output, 'strlen(v:val) > 0')

    " extract font family from each line                               {{{2
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

   " return result                                                    {{{2
    return l:output                                                  " }}}2

endfunction

" s:GetFontsUsingPythonCocoa()                                         {{{1
"  intent: use Cocoa font manager to return list of all
"          installed font families on Apple Mac
"  params: nil
"  return: List of strings
"  depend: uses python interface to Apple's cocoa api for Mac
" pyfunc fontdetect_listFontFamiliesUsingCocoa()                       {{{2
"  intent: python function for detecting installed font families
"          using Cocoa
"  params: nil
"  return: List
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
endif                                                                " }}}2
function! s:GetFontsUsingPythonCocoa() abort
    if !has('python') | return [] | endif
    return pyeval('fontdetect_listFontFamiliesUsingCocoa()')
endfunction

" s:GetFontsUsingFontconfig()                                          {{{1
"  intent: get installed fonts using fontconfig fc-list utility
"  params: nil
"  return: List of strings
function! s:GetFontsUsingFontconfig() abort
    if !executable('fc-list') | return [] | endif
    return systemlist("fc-list --format '%{family}\n'")
endfunction

" s:GetFontsUsingXlsfonts()                                            {{{1
"  intent: get registered X server fonts using xlsfonts utility
"  params: nil
"  return: List of strings
function! s:GetFontsUsingXlsfonts() abort
    if !executable('xlsfonts') | return [] | endif
    let l:output = systemlist('xlsfonts')
    " if 14 fields extract font family, else set to ''
    call map(l:output, '(len(split(v:val, ''-'')) == 14) '
                \ . '? (split(v:val, ''-''))[1] : ''''')
    call uniq(sort(l:output))
    call filter(l:output, 'strlen(v:val) > 0')  " remove empty elements
    return l:output
endfunction                                                          " }}}1

" SETTINGS:

" restore saved 'cpoptions'                                            {{{1
let &cpoptions = s:save_cpoptions                                    " }}}1

" vim: tw=75 fdm=marker :
