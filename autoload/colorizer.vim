" colorizer.vim	Colorize all text in the form #rrggbb or #rgb; autoload functions
" Maintainer:	lilydjwg <lilydjwg@gmail.com>
" Version:	1.4.2
" License:	Vim License  (see vim's :help license)
"
" See plugin/colorizer.vim for more info.

let s:keepcpo = &cpo
set cpo&vim

function! s:FGforBG(bg) "{{{1
  " takes a 6hex color code and returns a matching color that is visible
  let pure = substitute(a:bg,'^#','','')
  let r = str2nr(pure[0:1], 16)
  let g = str2nr(pure[2:3], 16)
  let b = str2nr(pure[4:5], 16)
  let fgc = g:colorizer_fgcontrast
  if r*30 + g*59 + b*11 > 12000
    return s:predefined_fgcolors['dark'][fgc]
  else
    return s:predefined_fgcolors['light'][fgc]
  end
endfunction

" Cache for RGB to xterm color mappings
let s:rgb_to_xterm_cache = get(s:, 'rgb_to_xterm_cache', {})

" Predefined mappings for common colors
let s:common_colors = {
  \ '#000000': 0, '#ffffff': 15, '#ff0000': 9, '#00ff00': 10,
  \ '#0000ff': 12, '#ffff00': 11, '#ff00ff': 13, '#00ffff': 14
  \ }

" Xterm color cube values
let s:valuerange = [0x00, 0x5F, 0x87, 0xAF, 0xD7, 0xFF]

" Basic 16 colors for xterm
let s:basic16 = [
  \ [0x00, 0x00, 0x00], [0xCD, 0x00, 0x00],
  \ [0x00, 0xCD, 0x00], [0xCD, 0xCD, 0x00],
  \ [0x00, 0x00, 0xEE], [0xCD, 0x00, 0xCD],
  \ [0x00, 0xCD, 0xCD], [0xE5, 0xE5, 0xE5],
  \ [0x7F, 0x7F, 0x7F], [0xFF, 0x00, 0x00],
  \ [0x00, 0xFF, 0x00], [0xFF, 0xFF, 0x00],
  \ [0x5C, 0x5C, 0xFF], [0xFF, 0x00, 0xFF],
  \ [0x00, 0xFF, 0xFF], [0xFF, 0xFF, 0xFF]
  \ ]

function! s:Rgb2xterm(color) abort
  " Converts an RGB color (#RRGGBB) to the nearest xterm-256 color index
  " Args:
  "   color: Hex color string (e.g., #FF0000)
  " Returns: xterm color index (0-255)

  " Check cache for previously computed color
  if has_key(s:rgb_to_xterm_cache, a:color)
    return s:rgb_to_xterm_cache[a:color]
  endif

  " Check common colors LUT
  if has_key(s:common_colors, a:color)
    let s:rgb_to_xterm_cache[a:color] = s:common_colors[a:color]
    return s:common_colors[a:color]
  endif

  " Extract RGB components
  let r = str2nr(a:color[1:2], 16)
  let g = str2nr(a:color[3:4], 16)
  let b = str2nr(a:color[5:6], 16)

  " Initialize best match
  let best_match = 0
  let smallest_distance = 10000000000

  " Check basic 16 colors
  for c in range(0, 15)
    let [r2, g2, b2] = s:basic16[c]
    let d = (r - r2) * (r - r2) + (g - g2) * (g - g2) + (b - b2) * (b - b2)
    if d < smallest_distance
      let smallest_distance = d
      let best_match = c
    endif
  endfor

  " Find closest color in 6x6x6 cube (indices 16-231)
  let r_idx = 0
  let g_idx = 0
  let b_idx = 0
  let min_diff_r = 256
  let min_diff_g = 256
  let min_diff_b = 256

  for i in range(6)
    let diff_r = abs(s:valuerange[i] - r)
    let diff_g = abs(s:valuerange[i] - g)
    let diff_b = abs(s:valuerange[i] - b)
    if diff_r < min_diff_r
      let min_diff_r = diff_r
      let r_idx = i
    endif
    if diff_g < min_diff_g
      let min_diff_g = diff_g
      let g_idx = i
    endif
    if diff_b < min_diff_b
      let min_diff_b = diff_b
      let b_idx = i
    endif
  endfor

  let cube_idx = 16 + (r_idx * 36) + (g_idx * 6) + b_idx
  let [r2, g2, b2] = [s:valuerange[r_idx], s:valuerange[g_idx], s:valuerange[b_idx]]
  let d = (r - r2) * (r - r2) + (g - g2) * (g - g2) + (b - b2) * (b - b2)
  if d < smallest_distance
    let smallest_distance = d
    let best_match = cube_idx
  endif

  " Check grayscale (indices 232-255)
  for c in range(232, 255)
    let gray = 8 + (c - 232) * 10
    let d = (r - gray) * (r - gray) + (g - gray) * (g - gray) + (b - gray) * (b - gray)
    if d < smallest_distance
      let smallest_distance = d
      let best_match = c
    endif
  endfor

  " Cache and return result
  let s:rgb_to_xterm_cache[a:color] = best_match
  return best_match
endfunction

function! s:Xterm2rgb(color) "{{{1
  " 16 basic colors
  let r = 0
  let g = 0
  let b = 0
  if a:color<16
    let r = s:basic16[a:color][0]
    let g = s:basic16[a:color][1]
    let b = s:basic16[a:color][2]
  endif

  " color cube color
  if a:color>=16 && a:color<=232
    let l:color=a:color-16
    let r = s:valuerange[(l:color/36)%6]
    let g = s:valuerange[(l:color/6)%6]
    let b = s:valuerange[l:color%6]
  endif

  " gray tone
  if a:color>=233 && a:color<=253
    let r=8+(a:color-232)*0x0a
    let g=r
    let b=r
  endif
  let rgb=[r,g,b]
  return rgb
endfunction

function! s:SetMatcher(color, pat) "{{{1
  " "color" is the converted color and "pat" is what to highlight
  let group = 'Color' . strpart(a:color, 1)
  if !hlexists(group) || s:force_group_update
    let fg = g:colorizer_fgcontrast < 0 ? a:color : s:FGforBG(a:color)
    if &t_Co == 256 && !(has('termguicolors') && &termguicolors)
      exe 'hi '.group.' ctermfg='.s:Rgb2xterm(fg).' ctermbg='.s:Rgb2xterm(a:color)
    endif
    " Always set gui* as user may switch to GUI version and it's cheap
    exe 'hi '.group.' guifg='.fg.' guibg='.a:color
  endif
  if !exists("w:colormatches[a:pat]")
    let w:colormatches[a:pat] = matchadd(group, a:pat)
  endif
endfunction

" Convert background color to RGB
function! s:RgbBgColor() abort
  let bg = synIDattr(synIDtrans(hlID("Normal")), "bg")
  if empty(bg)
    return []
  endif
  let r = str2nr(bg[1:2], 16)
  let g = str2nr(bg[3:4], 16)
  let b = str2nr(bg[5:6], 16)
  return [r, g, b]
endfunction

" Convert hex color with alpha to RGBA
function! s:Hexa2Rgba(hex, alpha) abort
  let r = str2nr(a:hex[1:2], 16)
  let g = str2nr(a:hex[3:4], 16)
  let b = str2nr(a:hex[5:6], 16)
  let alpha = printf("%.2f", str2float(str2nr(a:alpha, 16)) / 255.0)
  return [r, g, b, alpha]
endfunction

" Convert RGBA to RGB with background blending
function! s:Rgba2Rgb(r, g, b, alpha, percent, rgb_bg) abort
  if a:percent
    let r = a:r * 255 / 100
    let g = a:g * 255 / 100
    let b = a:b * 255 / 100
  else
    let r = a:r
    let g = a:g
    let b = a:b
  endif
  if r > 255 || g > 255 || b > 255
    return []
  endif
  if empty(a:rgb_bg)
    return [r, g, b]
  endif
  let alpha = str2float(a:alpha)
  if alpha < 0
    let alpha = 0.0
  elseif alpha > 1
    let alpha = 1.0
  endif
  if alpha == 1.0
    return [r, g, b]
  endif
  let r = float2nr(ceil(r * alpha + a:rgb_bg[0] * (1 - alpha)))
  let g = float2nr(ceil(g * alpha + a:rgb_bg[1] * (1 - alpha)))
  let b = float2nr(ceil(b * alpha + a:rgb_bg[2] * (1 - alpha)))
  return [min([r, 255]), min([g, 255]), min([b, 255])]
endfunction

function! s:HexCode(str, lineno) abort
  " Finds and processes hex color codes (#RGB, #RRGGBB, #RGBA, #AARRGGBB) in a string
  " Args:
  "   str: String to search for color codes
  "   lineno: Line number (for context, not used here)
  " Returns: List of [color, pattern] pairs for highlighting
  let ret = []
  let len_str = strlen(a:str)
  let pos = 0

  " Determine background for alpha blending
  let rgb_bg = has("gui_running") || (has("termguicolors") && &termguicolors) ? s:RgbBgColor() : []

  " Cache for processed colors to avoid redundant conversions
  let s:color_cache = get(s:, 'color_cache', {})

  while pos < len_str
    " Find next '#' symbol
    let pos = stridx(a:str, '#', pos)
    if pos == -1
      break
    endif

    " Extract potential color code
    let start = pos
    let pos += 1
    let code_len = 0
    let max_len = min([9, len_str - pos])  " Max length for #AARRGGBB (9 chars including #)
    let code = '#'

    " Collect characters after '#' (up to 8 for #AARRGGBB or #RRGGBBAA)
    while code_len < max_len && pos + code_len < len_str
      let char = a:str[pos + code_len]
      if char !~# '[0-9A-Fa-f]'
        break
      endif
      let code .= char
      let code_len += 1
    endwhile

    " Validate color code length
    if code_len != 3 && code_len != 4 && code_len != 6 && code_len != 8
      let pos = start + 1
      continue
    endif

    " Check if code is cached
    if has_key(s:color_cache, code)
      call add(ret, s:color_cache[code])
      let pos = start + code_len + 1
      continue
    endif

    " Process color code
    let is_alpha_first = get(g:, 'colorizer_hex_alpha_first', 0)
    let hr = ''
    let hg = ''
    let hb = ''
    let ha = 'ff'  " Default alpha (opaque)

    if code_len == 3 || code_len == 4
      " Handle #RGB or #RGBA
      let hr = tolower(code[1]) . tolower(code[1])
      let hg = tolower(code[2]) . tolower(code[2])
      let hb = tolower(code[3]) . tolower(code[3])
      if code_len == 4
        let ha = tolower(code[4]) . tolower(code[4])
      endif
    else
      " Handle #RRGGBB or #AARRGGBB or #RRGGBBAA
      if is_alpha_first && code_len == 8
        let ha = tolower(code[1:2])
        let hr = tolower(code[3:4])
        let hg = tolower(code[5:6])
        let hb = tolower(code[7:8])
      else
        let hr = tolower(code[1:2])
        let hg = tolower(code[3:4])
        let hb = tolower(code[5:6])
        if code_len == 8
          let ha = tolower(code[7:8])
        endif
      endif
    endif

    let foundcolor = '#' . hr . hg . hb
    let pat = '\V' . escape(code, '\')  " Exact match for the original code

    " Handle alpha channel if present
    if ha != 'ff' && !empty(rgb_bg)
      let rgba = s:Hexa2Rgba(foundcolor, ha)
      let rgb = s:Rgba2Rgb(rgba[0], rgba[1], rgba[2], rgba[3], 0, rgb_bg)
      if !empty(rgb)
        let foundcolor = printf('#%02x%02x%02x', rgb[0], rgb[1], rgb[2])
        " Adjust pattern to match RGB part only if alpha was processed
        if code_len == 4
          let pat = '\V' . escape(code[0:3], '\') . '\x'
        elseif code_len == 8
          let pat = is_alpha_first ? '\V' . '\x\x' . escape(code[3:8], '\') : '\V' . escape(code[0:6], '\') . '\x\x'
        endif
      endif
    endif

    " Cache and store result
    let result = [foundcolor, pat]
    let s:color_cache[code] = result
    call add(ret, result)
    let pos = start + code_len + 1
  endwhile

  return ret
endfunction

function! s:RgbColor(str, lineno) "{{{2
  let ret = []
  let place = 0
  let colorpat = '\<rgb(\v\s*(\d+(\%)?)\s*,\s*(\d+%(\2))\s*,\s*(\d+%(\2))\s*\)'
  while 1
    let foundcolor = matchlist(a:str, colorpat, place)
    if empty(foundcolor)
      break
    endif
    let place = matchend(a:str, colorpat, place)
    if foundcolor[2] == '%'
      let r = foundcolor[1] * 255 / 100
      let g = foundcolor[3] * 255 / 100
      let b = foundcolor[4] * 255 / 100
    else
      let r = foundcolor[1]
      let g = foundcolor[3]
      let b = foundcolor[4]
    endif
    if r > 255 || g > 255 || b > 255
      break
    endif
    let pat = printf('\<rgb(\v\s*%s\s*,\s*%s\s*,\s*%s\s*\)', foundcolor[1], foundcolor[3], foundcolor[4])
    if foundcolor[2] == '%'
      let pat = substitute(pat, '%', '\\%', 'g')
    endif
    let l:color = printf('#%02x%02x%02x', r, g, b)
    call add(ret, [l:color, pat])
  endwhile
  return ret
endfunction

function! s:RgbaColor(str, lineno) "{{{2
  if has("gui_running") || (has("termguicolors") && &termguicolors)
    let rgb_bg = s:RgbBgColor()
  else
    " translucent colors would display incorrectly, so ignore the alpha value
    let rgb_bg = []
  endif
  let ret = []
  let place = 0
  let percent = 0
  let colorpat = '\<rgba(\v\s*(\d+(\%)?)\s*,\s*(\d+%(\2))\s*,\s*(\d+%(\2))\s*,\s*(-?[.[:digit:]]+)\s*\)'
  while 1
    let foundcolor = matchlist(a:str, colorpat, place)
    if empty(foundcolor)
      break
    endif
    if foundcolor[2] == '%'
      let percent = 1
    endif
    let rgb = s:Rgba2Rgb(foundcolor[1], foundcolor[3], foundcolor[4], foundcolor[5], percent, rgb_bg)
    if empty(rgb)
      break
    endif
    let place = matchend(a:str, colorpat, place)
    if empty(rgb_bg)
      let pat = printf('\<rgba(\v\s*%s\s*,\s*%s\s*,\s*%s\s*,\ze\s*(-?[.[:digit:]]+)\s*\)', foundcolor[1], foundcolor[3], foundcolor[4])
    else
      let pat = printf('\<rgba(\v\s*%s\s*,\s*%s\s*,\s*%s\s*,\s*%s0*\s*\)', foundcolor[1], foundcolor[3], foundcolor[4], foundcolor[5])
    endif
    if percent
      let pat = substitute(pat, '%', '\\%', 'g')
    endif
    let l:color = printf('#%02x%02x%02x', rgb[0], rgb[1], rgb[2])
    call add(ret, [l:color, pat])
  endwhile
  return ret
endfunction

function! s:PreviewColorInLine(where) "{{{1
  let line = getline(a:where)
  for Func in s:ColorFinder
    let ret = Func(line, a:where)
    " returned a list of a list: color as #rrggbb, text pattern to highlight
    for r in ret
      call s:SetMatcher(r[0], r[1])
    endfor
  endfor
endfunction

function! s:CursorMoved() "{{{1
  if !exists('w:colormatches')
    return
  endif
  if exists('b:colorizer_last_update')
    if b:colorizer_last_update == b:changedtick
      " Nothing changed
      return
    endif
  endif
  call s:PreviewColorInLine('.')
  let b:colorizer_last_update = b:changedtick
endfunction

function! s:TextChanged() "{{{1
  if !exists('w:colormatches')
    return
  endif
  echomsg "TextChanged"
  call s:PreviewColorInLine('.')
endfunction

function! colorizer#ColorHighlight(update, ...) "{{{1
  if exists('w:colormatches')
    if !a:update
      return
    endif
    call s:ClearMatches()
  endif
  if (g:colorizer_maxlines > 0) && (g:colorizer_maxlines <= line('$'))
    return
  end
  let w:colormatches = {}
  if g:colorizer_fgcontrast != s:saved_fgcontrast || (exists("a:1") && a:1 == '!')
    let s:force_group_update = 1
  endif
  for i in range(1, line("$"))
    call s:PreviewColorInLine(i)
  endfor
  let s:force_group_update = 0
  let s:saved_fgcontrast = g:colorizer_fgcontrast
  augroup Colorizer
    au!
    if exists('##TextChanged')
      autocmd TextChanged * silent call s:TextChanged()
      if v:version > 704 || v:version == 704 && has('patch143')
        autocmd TextChangedI * silent call s:TextChanged()
      else
        " TextChangedI does not work as expected
        autocmd CursorMovedI * silent call s:CursorMoved()
      endif
    else
      autocmd CursorMoved,CursorMovedI * silent call s:CursorMoved()
    endif
    " rgba handles differently, so need updating
    autocmd GUIEnter * silent call colorizer#ColorHighlight(1)
    autocmd BufEnter * silent call colorizer#ColorHighlight(1)
    autocmd WinEnter * silent call colorizer#ColorHighlight(1)
    autocmd ColorScheme * let s:force_group_update=1 | silent call colorizer#ColorHighlight(1)
  augroup END
endfunction

function! colorizer#ColorClear() "{{{1
  augroup Colorizer
    au!
  augroup END
  augroup! Colorizer
  let save_tab = tabpagenr()
  let save_win = winnr()
  tabdo windo call s:ClearMatches()
  exe 'tabn '.save_tab
  exe save_win . 'wincmd w'
endfunction

function! s:ClearMatches() "{{{1
  if !exists('w:colormatches')
    return
  endif
  for i in values(w:colormatches)
    try
      call matchdelete(i)
    catch /.*/
      " matches have been cleared in other ways, e.g. user has called clearmatches()
    endtry
  endfor
  unlet w:colormatches
endfunction

function! colorizer#ColorToggle() "{{{1
  if exists('#Colorizer')
    call colorizer#ColorClear()
    echomsg 'Disabled color code highlighting.'
  else
    call colorizer#ColorHighlight(0)
    echomsg 'Enabled color code highlighting.'
  endif
endfunction

function! colorizer#AlphaPositionToggle() "{{{1
  if exists('#Colorizer')
    if get(g:, 'colorizer_hex_alpha_first') == 1
      let g:colorizer_hex_alpha_first = 0
    else
      let g:colorizer_hex_alpha_first = 1
    endif
    call colorizer#ColorHighlight(1)
  endif
endfunction

function! s:GetXterm2rgbTable() "{{{1
  if !exists('s:table_xterm2rgb')
    let s:table_xterm2rgb = []
    for c in range(0, 254)
      let s:color = s:Xterm2rgb(c)
      call add(s:table_xterm2rgb, s:color)
    endfor
  endif
  return s:table_xterm2rgb
endfun

" Setups {{{1
let s:ColorFinder = [function('s:HexCode'), function('s:RgbColor'), function('s:RgbaColor')]
let s:force_group_update = 0
let s:predefined_fgcolors = {}
let s:predefined_fgcolors['dark']  = ['#444444', '#222222', '#000000']
let s:predefined_fgcolors['light'] = ['#bbbbbb', '#dddddd', '#ffffff']
if !exists("g:colorizer_fgcontrast")
  " Default to black / white
  let g:colorizer_fgcontrast = len(s:predefined_fgcolors['dark']) - 1
elseif g:colorizer_fgcontrast >= len(s:predefined_fgcolors['dark'])
  echohl WarningMsg
  echo "g:colorizer_fgcontrast value invalid, using default"
  echohl None
  let g:colorizer_fgcontrast = len(s:predefined_fgcolors['dark']) - 1
endif
let s:saved_fgcontrast = g:colorizer_fgcontrast

" Restoration and modelines {{{1
let &cpo = s:keepcpo
unlet s:keepcpo
" vim:ft=vim:fdm=marker:fmr={{{,}}}:ts=8:sw=2:sts=2:et
