function! SafeMakeDir()
    let outdir = expand('%:p:h') . '/' . g:mdip_imgdir
        if !isdirectory(outdir)
            call mkdir(outdir)
        endif
    return fnameescape(outdir)
endfunction

function! SaveFileTMPLinux(imgdir, tmpname) abort
    let targets = filter(
            \ systemlist('xclip -selection clipboard -t TARGETS -o'),
            \ 'v:val =~# ''image''')
      if empty(targets) | return 1 | endif

      let mimetype = targets[0]
      let extension = split(mimetype, '/')[-1]
      let tmpfile = a:imgdir . '/' . a:tmpname . '.' . extension
      call system(printf('xclip -selection clipboard -t %s -o > %s',
            \ mimetype, tmpfile))
      return tmpfile
endfunction

function! SaveFileTMPMacOS(imgdir, tmpname) abort
    let tmpfile = a:imgdir . '/' . a:tmpname . '.png'
    let clip_command = 'osascript'
    let clip_command .= ' -e "set png_data to the clipboard as «class PNGf»"'
    let clip_command .= ' -e "set referenceNumber to open for access POSIX path of'
    let clip_command .= ' (POSIX file \"' . tmpfile . '\") with write permission"'
    let clip_command .= ' -e "write png_data to referenceNumber"'

    silent call system(clip_command)
    if v:shell_error == 1
        return 1
    else
        return tmpfile
    endif
endfunction

function! SaveFileTMP(imgdir, tmpname)
    if has('mac')
        return SaveFileTMPMacOS(a:imgdir, a:tmpname)
    else
        return SaveFileTMPLinux(a:imgdir, a:tmpname)
    endif
endfunction

function! SaveNewFile(imgdir, tmpfile)
    let extension = split(a:tmpfile, '\.')[-1]
    let reldir = g:mdip_imgdir
    let cnt = 0
    let filename = a:imgdir . '/' . g:mdip_imgname . cnt . '.' . extension
    let relpath = reldir . '/' . g:mdip_imgname . cnt . '.' . extension
    while filereadable(filename)
        call system('diff ' . a:tmpfile . ' ' . filename)
        if !v:shell_error
            call delete(a:tmpfile)
            return relpath
        endif
        let cnt += 1
        let filename = a:imgdir . '/' . g:mdip_imgname . cnt . '.' . extension
        let relpath = reldir . '/' . g:mdip_imgname . cnt . '.' . extension
    endwhile
    if filereadable(a:tmpfile)
        call rename(a:tmpfile, filename)
    endif
    return relpath
endfunction

function! RandomName()
  let l:new_random = system('echo $(date +\%s)-$RANDOM')[0:-2]
  return l:new_random
endfunction

function! mdip#MarkdownClipboardImage()
    let workdir = SafeMakeDir()
    " change temp-file-name and image-name
    let g:mdip_tmpname = RandomName()
    " let g:mdip_imgname = g:mdip_tmpname

    let tmpfile = SaveFileTMP(workdir, g:mdip_tmpname)
    if tmpfile == 1
        return
    else
        " let relpath = SaveNewFile(g:mdip_imgdir, tmpfile)
        let extension = split(tmpfile, '\.')[-1]
        let relpath = g:mdip_imgdir . '/' . g:mdip_tmpname . '.' . extension
        execute "normal! i![Image](" . relpath . ")"
    endif
endfunction

if !exists('g:mdip_imgdir')
    let g:mdip_imgdir = 'img'
endif
if !exists('g:mdip_tmpname')
    let g:mdip_tmpname = 'tmp'
endif
if !exists('g:mdip_imgname')
    let g:mdip_imgname = 'image'
endif
