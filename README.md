# md-img-paste.vim
Yet simple tool to paste images into markdown files

## Use Case
You are editing a markdown file and have an image on the clipboard and want to paste it into the document as the text `![](img/image1.png)`. Instead of first copying it to that directory, you want to do it with a single `<leader>p` key press in Vim. So it hooks `<leader>p`, checks if you are editing a Markdown file, saves the image from the clipboard to the location  `img/image1.png`, and inserts `![](img/image1.png)` into the file.

## Installation

Using Vundle
```
Plugin 'ferrine/md-img-paste.vim'
```

## Usage
Add to .vimrc
```
autocmd FileType markdown nmap <buffer><silent> <leader>p :call mdip#MarkdownClipboardImage()<CR>
" there are some defaults for image directory and image name, you can change them
" let g:mdip_imgdir = 'img'
" let g:mdip_imgname = 'image'
```

### For linux user
This plugin gets clipboard content by running the `xclip` command.

install `xclip` first.

## Acknowledgements
I'm not yet perfect at writing vim plugins but I managed to do it. Thanks to [Karl Yngve Lervåg](https://vi.stackexchange.com/users/21/karl-yngve-lerv%C3%A5g) and [Rich](https://vi.stackexchange.com/users/343/rich) for help on [vi.stackexchange.com](https://vi.stackexchange.com/questions/14114/paste-link-to-image-in-clipboard-when-editing-markdown) where they proposed a solution for my use case.

