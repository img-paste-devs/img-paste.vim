" https://stackoverflow.com/questions/57014805/check-if-using-windows-console-in-vim-while-in-windows-subsystem-for-linux
function! s:IsWSL()
    let lines = readfile("/proc/version")
    if lines[0] =~ "Microsoft"
        return 1
    endif
    return 0
endfunction

function! s:SafeMakeDir()
    if !exists('g:mdip_imgdir_absolute')
        if s:os == "Windows"
            let outdir = expand('%:p:h') . '\' . g:mdip_imgdir
    else
            let outdir = expand('%:p:h') . '/' . g:mdip_imgdir
        endif
    else
	let outdir = g:mdip_imgdir
    endif
    if !isdirectory(outdir)
        call mkdir(outdir)
    endif
    if s:os == "Darwin"
        return outdir
    else
        return fnameescape(outdir)
    endif
endfunction

function! s:SaveFileTMPWSL(imgdir, tmpname) abort
    let tmpfile = a:imgdir . '/' . a:tmpname . '.png'
    let tmpfile = substitute(system("wslpath -m ".tmpfile), '\n\+$', '', '')

    let clip_command = "Add-Type -AssemblyName System.Windows.Forms;"
    let clip_command .= "if ([Windows.Forms.Clipboard]::ContainsImage()) {"
    let clip_command .= "[Windows.Forms.Clipboard]::GetImage().Save(\\\""
    let clip_command .= tmpfile ."\\\", [System.Drawing.Imaging.ImageFormat]::Png) }"
    let clip_command = "powershell.exe -sta \"".clip_command. "\""

    call system(clip_command)
    if v:shell_error == 1
        return 1
    else
        return tmpfile
    endif
endfunction

function! s:SaveFileTMPLinux(imgdir, tmpname) abort
    let targets = filter(
                \ systemlist('xclip -selection clipboard -t TARGETS -o'),
                \ 'v:val =~# ''image/''')
    if empty(targets) | return 1 | endif

    if index(targets, "image/png") >= 0
        " Use PNG if available
        let mimetype = "image/png"
        let extension = "png"
    else
        " Fallback
        let mimetype = targets[0]
        let extension = split(mimetype, '/')[-1]
    endif

    let tmpfile = a:imgdir . '/' . a:tmpname . '.' . extension
    call system(printf('xclip -selection clipboard -t %s -o > %s',
                \ mimetype, tmpfile))
    return tmpfile
endfunction

function! s:SaveFileTMPWin32(imgdir, tmpname) abort
    let tmpfile = a:imgdir . '/' . a:tmpname . '.png'

    let clip_command = "Add-Type -AssemblyName System.Windows.Forms;"
    let clip_command .= "if ($([System.Windows.Forms.Clipboard]::ContainsImage())) {"
    let clip_command .= "[System.Drawing.Bitmap][System.Windows.Forms.Clipboard]::GetDataObject().getimage().Save('"
    let clip_command .= tmpfile ."', [System.Drawing.Imaging.ImageFormat]::Png) }"
    let clip_command = "powershell -sta \"".clip_command. "\""

    silent call system(clip_command)
    if v:shell_error == 1
        return 1
    else
        return tmpfile
    endif
endfunction

function! s:SaveFileTMPMacOS(imgdir, tmpname) abort
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

function! s:SaveFileTMP(imgdir, tmpname)
    if s:os == "Linux"
        " Linux could also mean Windowns Subsystem for Linux
        if s:IsWSL()
            return s:SaveFileTMPWSL(a:imgdir, a:tmpname)
        endif
        return s:SaveFileTMPLinux(a:imgdir, a:tmpname)
    elseif s:os == "Darwin"
        return s:SaveFileTMPMacOS(a:imgdir, a:tmpname)
    elseif s:os == "Windows"
        return s:SaveFileTMPWin32(a:imgdir, a:tmpname)
    endif
endfunction

function! s:SaveNewFile(imgdir, tmpfile)
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

function! s:RandomName()
    " help feature-list
    if has('win16') || has('win32') || has('win64') || has('win95')
        let l:new_random = strftime("%Y-%m-%d-%H-%M-%S")
        " creates a file like this: `2019-11-12-10-27-10.png`
        " the filesystem on Windows does not allow : character.
    else
        let l:new_random = strftime("%Y-%m-%d-%H-%M-%S")
    endif
    return l:new_random
endfunction

function! s:InputName()
    call inputsave()
    let name = input('Image name: ')
    call inputrestore()
    return name
endfunction

function! mdip#MarkdownClipboardImage()
    " detect os: https://vi.stackexchange.com/questions/2572/detect-os-in-vimscript
    let s:os = "Windows"
    if !(has("win64") || has("win32") || has("win16"))
        let s:os = substitute(system('uname'), '\n', '', '')
    endif

    let workdir = s:SafeMakeDir()
    " change temp-file-name and image-name
    let g:mdip_tmpname = s:InputName()
    if empty(g:mdip_tmpname)
      let g:mdip_tmpname = g:mdip_imgname . '_' . s:RandomName()
    endif

    let tmpfile = s:SaveFileTMP(workdir, g:mdip_tmpname)
    if tmpfile == 1
        return
    else
        " let relpath = s:SaveNewFile(g:mdip_imgdir, tmpfile)
        let extension = split(tmpfile, '\.')[-1]
        let relpath = g:mdip_imgdir_intext . '/' . g:mdip_tmpname . '.' . extension
        execute "normal! i![I"
        let ipos = getcurpos()
        execute "normal! amage](" . relpath . ")"
        call setpos('.', ipos)
        execute "normal! ve\<C-g>"
    endif
endfunction

if !exists('g:mdip_imgdir') && !exists('g:mdip_imgdir_absolute')
    let g:mdip_imgdir = 'img'
endif
"allow absolute paths. E.g., on linux: /home/path/to/imgdir/
if exists('g:mdip_imgdir_absolute')
    let g:mdip_imgdir = g:mdip_imgdir_absolute
endif
"allow a different intext reference for relative links
if !exists('g:mdip_imgdir_intext')
    let g:mdip_imgdir_intext = g:mdip_imgdir
endif
if !exists('g:mdip_tmpname')
    let g:mdip_tmpname = 'tmp'
endif
if !exists('g:mdip_imgname')
    let g:mdip_imgname = 'image'
endif
