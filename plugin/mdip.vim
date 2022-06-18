" https://stackoverflow.com/questions/57014805/check-if-using-windows-console-in-vim-while-in-windows-subsystem-for-linux
function! s:IsWSL()
    let lines = readfile("/proc/version")
    if (lines[0] =~ "Microsoft" || lines[0] =~ "microsoft")
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
        call mkdir(outdir,"p",0700)
    endif
    if s:os == "Darwin"
        return outdir
    else
        return fnameescape(outdir)
    endif
endfunction

function! s:SaveFileTMPWSL(imgdir, tmpname) abort
    let tmpfile = a:imgdir . '/' . a:tmpname . '.png'
    let tmpfile = substitute(tmpfile, "\/", "\\\\\\", "g")
    if tmpfile =~ "mnt"
        let tmpfile = substitute(tmpfile, "\\\\\\\\mnt\\\\\\\\c", "C:", "g")
    else
        let tmpfile = '\\\\wsl\$\\Ubuntu'.tmpfile
    endif

    let clip_command = 'powershell.exe -nologo -noprofile -noninteractive -sta "Add-Type -Assembly PresentationCore;'.
          \'\$img = [Windows.Clipboard]::GetImage();'.
          \'if (\$img -eq \$null) {'.
          \'echo "Do not contain image.";'.
          \'Exit;'.
          \'} else{'.
          \'echo "good";}'.
          \'\$fcb = new-object Windows.Media.Imaging.FormatConvertedBitmap(\$img, [Windows.Media.PixelFormats]::Rgb24, \$null, 0);'.
          \'\$file = \"'. tmpfile . '\";'.
          \'\$stream = [IO.File]::Open(\$file, \"OpenOrCreate\");'.
          \'\$encoder = New-Object Windows.Media.Imaging.PngBitmapEncoder;'.
          \'\$encoder.Frames.Add([Windows.Media.Imaging.BitmapFrame]::Create(\$fcb));'.
          \'\$encoder.Save(\$stream);\$stream.Dispose();"'

    let result = system(clip_command)[:-3]
    if result ==# "good"
        return tmpfile
    else
        return 1
    endif
endfunction

function! s:SaveFileTMPLinux(imgdir, tmpname) abort
    if $WAYLAND_DISPLAY != "" && executable('wl-copy')
        let system_targets = "wl-paste --list-types"
        let system_clip = "wl-paste --no-newline --type %s > %s"
    elseif $DISPLAY != '' && executable('xclip')
        let system_targets = 'xclip -selection clipboard -t TARGETS -o'
        let system_clip = 'xclip -selection clipboard -t %s -o > %s'
    else
        echoerr 'Needs xclip in X11 or wl-clipboard in Wayland.'
        return 1
    endif

    let targets = filter(systemlist(system_targets), 'v:val =~# ''image/''')
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
    call system(printf(system_clip, mimetype, tmpfile))
    return tmpfile
endfunction

function! s:SaveFileTMPWin32(imgdir, tmpname) abort
    let tmpfile = a:imgdir . '\' . a:tmpname . '.png'
    let tmpfile = substitute(tmpfile, '\\ ', ' ', 'g')

    let clip_command = "Add-Type -AssemblyName System.Windows.Forms;"
    let clip_command .= "if ($([System.Windows.Forms.Clipboard]::ContainsImage())) {"
    let clip_command .= "[System.Drawing.Bitmap][System.Windows.Forms.Clipboard]::GetDataObject().getimage().Save('"
    let clip_command .= tmpfile ."', [System.Drawing.Imaging.ImageFormat]::Png) }"
    let clip_command = "powershell -nologo -noprofile -noninteractive -sta \"".clip_command. "\""

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

function! g:MarkdownPasteImage(relpath)
        execute "normal! i![" . g:mdip_tmpname[0:0]
        let ipos = getcurpos()
        execute "normal! a" . g:mdip_tmpname[1:] . "](" . a:relpath . ")"
        call setpos('.', ipos)
        execute "normal! vt]\<C-g>"
endfunction

function! g:LatexPasteImage(relpath)
    execute "normal! i\\includegraphics{" . a:relpath . "}\r\\caption{I"
    let ipos = getcurpos()
    execute "normal! a" . "mage}"
    call setpos('.', ipos)
    execute "normal! ve\<C-g>"
endfunction

function! g:EmptyPasteImage(relpath)
    execute "normal! i" . a:relpath 
endfunction

let g:PasteImageFunction = 'g:MarkdownPasteImage'

function! mdip#MarkdownClipboardImage()
    " detect os: https://vi.stackexchange.com/questions/2572/detect-os-in-vimscript
    let s:os = "Windows"
    if !(has("win64") || has("win32") || has("win16"))
        let s:os = substitute(system('uname'), '\n', '', '')
    endif

    " add check whether file with the name exists
    while  1
        let workdir = s:SafeMakeDir()
        " change temp-file-name and image-name
        let g:mdip_tmpname = s:InputName()
        if empty(g:mdip_tmpname)
          let g:mdip_tmpname = g:mdip_imgname . '_' . s:RandomName()
        endif
        let testpath =  workdir . '/' . g:mdip_tmpname . '.png'
        if filereadable(testpath) == 0
            break
        else
            echo "\nThis file name already exists"
        endif
    endwhile

    let tmpfile = s:SaveFileTMP(workdir, g:mdip_tmpname)
    if tmpfile == 1
        return
    else
        " let relpath = s:SaveNewFile(g:mdip_imgdir, tmpfile)
        let extension = split(tmpfile, '\.')[-1]
        let relpath = g:mdip_imgdir_intext . '/' . g:mdip_tmpname . '.' . extension
        if call(get(g:, 'PasteImageFunction'), [relpath])
            return
        endif
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
