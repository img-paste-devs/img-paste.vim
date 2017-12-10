function! MarkdownClipboardImage() abort
  let targets = filter(
        \ systemlist('xclip -selection clipboard -t TARGETS -o'),
        \ 'v:val =~# ''image''')
  if empty(targets) | return | endif

  let outdir = expand('%:p:h') . '/img'
  if !isdirectory(outdir)
    call mkdir(outdir)
  endif

  let mimetype = targets[0]
  let extension = split(mimetype, '/')[-1]
  let tmpfile = outdir . '/savefile_tmp.' . extension
  call system(printf('xclip -selection clipboard -t %s -o > %s',
        \ mimetype, tmpfile))

  let cnt = 0
  let filename = outdir . '/image' . cnt . '.' . extension
  while filereadable(filename)
    call system('diff ' . tmpfile . ' ' . filename)
    if !v:shell_error
      call delete(tmpfile)
      break
    endif

    let cnt += 1
    let filename = outdir . '/image' . cnt . '.' . extension
    let relpath = 'img/image' . cnt . '.' . extention
  endwhile

  if filereadable(tmpfile)
    call rename(tmpfile, filename)
  endif

  let @* = '![](' . fnamemodify(relpath , ':.') . ')'
  normal! "*p
endfunction
"
" ---------------------------MacOS-version---------------------------------------
"
function! MarkdownClipboardImageMacOS() abort
  " Create `img` directory if it doesn't exist
  let img_dir = expand('%:p:h') . '/img'
  if !isdirectory(img_dir)
    silent call mkdir(img_dir)
  endif

  " First find out what filename to use
  let index = 1
  let file_path = img_dir . "/image" . index . ".png"
  while filereadable(file_path)
    let index = index + 1
    let file_path = img_dir . "/image" . index . ".png"
    let rel_path = "img/image" . index . ".png"
  endwhile

  let clip_command = 'osascript'
  let clip_command .= ' -e "set png_data to the clipboard as «class PNGf»"'
  let clip_command .= ' -e "set referenceNumber to open for access POSIX path of'
  let clip_command .= ' (POSIX file \"' . file_path . '\") with write permission"'
  let clip_command .= ' -e "write png_data to referenceNumber"'

  silent call system(clip_command)
  if v:shell_error == 1
    normal! p
  else
    execute "normal! i![](" . file_path . ")"
  endif
endfunction

