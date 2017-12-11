function! SafeMakeDir()
    let outdir = expand('%:p:h') . '/' . g:mdip_imgdir
        if !isdirectory(outdir)
            call mkdir(outdir)
        endif
    return outdir
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

function! mdip#MarkdownClipboardImage()
    let workdir = SafeMakeDir()
    let tmpfile = SaveFileTMP(workdir, g:mdip_tmpname)
    if tmpfile == 1
        return
    else
        let relpath = SaveNewFile(g:mdip_imgdir, tmpfile)
        execute "normal! i![](" . relpath . ")"
    endif
endfunction

let g:mdip_imgdir = 'img'
let g:mdip_tmpname = 'tmp'
let g:mdip_imgname = 'image'

