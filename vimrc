set nocompatible              " be iMproved, required
filetype off                  " required

" set the runtime path to include Vundle and initialize
set rtp+=~/.vim/bundle/Vundle.vim
" call vundle#begin()
" alternatively, pass a path where Vundle should install plugins
"call vundle#begin('~/some/path/here')

" let Vundle manage Vundle, required
" Plugin 'VundleVim/Vundle.vim'

" The following are examples of different formats supported.
" Keep Plugin commands between vundle#begin/end.
" plugin on GitHub repo
" Plugin 'tpope/vim-fugitive'
" plugin from http://vim-scripts.org/vim/scripts.html
" Plugin 'L9'
" Git plugin not hosted on GitHub
" Plugin 'git://git.wincent.com/command-t.git'
" The sparkup vim script is in a subdirectory of this repo called vim.
" Pass the path to set the runtimepath properly.
" Plugin 'git@github.com:terryma/vim-multiple-cursors.git'
" Plugin 'rstacruz/sparkup', {'rtp': 'vim/'}
" Install L9 and avoid a Naming conflict if you've already installed a
" different version somewhere else.
" Plugin 'ascenator/L9', {'name': 'newL9'}

" All of your Plugins must be added before the following line
" call vundle#end()            " required
" filetype plugin indent on    " required
" To ignore plugin indent changes, instead use:
"filetype plugin on
"
" Brief help
" :PluginList       - lists configured plugins
" :PluginInstall    - installs plugins; append `!` to update or just :PluginUpdate
" :PluginSearch foo - searches for foo; append `!` to refresh local cache
" :PluginClean      - confirms removal of unused plugins; append `!` to auto-approve removal
"
" see :h vundle for more details or wiki for FAQ
" Put your non-Plugin stuff after this line

syntax enable       " 语法高亮
"set showcmd		" Show (partial) command in status line.
set wildmode=longest,list,full  " tab的时候，和bash一样
set wildmenu
set scrolloff=2     " 设置鼠标最下面控制在倒数第六行
"colorscheme slate
"colorscheme ramwin
set nocompatible
"set nowrap          " 不要自动换行
"set linebreak       " 换行的时候不把单词拆开
set showmatch		" Show matching brackets.
set ignorecase		" Do case insensitive matching
set wildignore+=*.pyc  " 忽略python的pyc文件
set smartcase		" Do smart case matching
"set guioptions=r   " 设置滚动条，但是没有效果
set incsearch		" 查找关键字时，及时匹配
"set autowrite		" Automatically save before commands like :next and :make
"set hidden		" Hide buffers when they are abandoned
set mouse=v     " Enable mouse usage (all modes) 允许鼠标定位
set shiftwidth=4 " 设置缩进的空格数
set tabstop=4   " 制表符宽度为4
set list        " tab和\r都要显示
" set listchars=tab:>·
" set listchars+=space:␣ " 空格用特殊符号表示
set incsearch  " 设置边搜索边跳转
set wildmenu  " 设置显示菜单栏
set expandtab   " 把制表符换成空格
set autoindent  " 自动缩进
set number      " 设置行号显示
set relativenumber  " 设置相对行号
set backspace=indent,eol,start
set foldmethod=indent " 设置折叠
set colorcolumn=80  " 80列高亮
set hlsearch  " 搜索高亮
set encoding=utf-8
set fileencodings=utf-8,gbk
" set cursorline  " 设置当前行高亮
" set lisp    " 设置连字符也能自动补全， 但是会导致 autoindent 出现异常
set iskeyword+=\-
highlight ColorColumn ctermbg=6
set foldlevel=0 
set ruler
"set title  " 不修改标题
let g:netrw_bufsettings="" " 设置打开目录也有行号 noma nomod  nowrap ro
nnoremap <space> za
"vnoremap <space> zf
" 部分文件自动加前缀
function HeaderPython()
    call setline(1, "#!/usr/bin/env python3")
    call append(1, "# -*- coding: utf-8 -*-")
    call append(2, "# Xiang Wang @ ".strftime('%Y-%m-%d %T',localtime()))
    normal G
    normal o
    normal o
endf
function HeaderHtml()
    call setline(1, "<!DOCTYPE html>")
    call append(1, "<html>")
    call append(2, "  <head>")
    call append(3, "    <title></title>")
    call append(4, "    <meta http-equiv=\"content-type\" content=\"text/html; charset=UTF-8\">")
    call append(5, "  </head>")
    call append(6, "  <body>")
    call append(7, "    ")
    call append(8, "  </body>")
    call append(9, "</html>")
    set shiftwidth=2
    set tabstop=2
    normal zi
    normal 8G
endf
function HeaderBash()
    call setline(1, "#!/bin/bash")
    call append(1, "# Xiang Wang @ ".strftime('%Y-%m-%d %T',localtime()))
    normal G
    normal o
    normal o
endf
function HeaderMarkdown()
    call setline(1, "**Xiang Wang @ ".strftime('%Y-%m-%d %T',localtime()))
    call setline('.', getline('.') . '**')
    normal G
    normal o
    normal o
endf
function HeaderJavascript()
    call setline(1, "// Xiang Wang @ ".strftime('%Y-%m-%d %T',localtime()))
    normal G
    normal o
    normal o
    set shiftwidth=2
    set tabstop=2
endf
function OpenHtml()
    set shiftwidth=2
    set tabstop=2
    set filetype=html
endf
function OpenJs()
    set shiftwidth=2
    set tabstop=2
endf
function OpenCss()
    set shiftwidth=2
    set tabstop=2
    set filetype=css
endf
function OpenPython()
    set shiftwidth=4
    set tabstop=4
endf
function OpenMarkdown()
    set shiftwidth=4
    set tabstop=4
    set autoindent
endf
function SaveLess()
    !lessc <afile> > %:p:r.css
endf
autocmd bufnewfile *.py call HeaderPython()
autocmd BufNewFile *.html call HeaderHtml()
autocmd bufnewfile *.sh call HeaderBash()
autocmd bufnewfile *.md call HeaderMarkdown()
autocmd bufnewfile *.js call HeaderJavascript()
autocmd BufRead *.html call OpenHtml()
autocmd BufRead *.js call OpenJs()
autocmd BufRead *.wxml call OpenHtml()
autocmd BufRead *.wxss call OpenCss()
autocmd BufRead *.css call OpenCss()
autocmd BufRead *.less call OpenCss()
autocmd BufRead *.py call OpenPython()
autocmd BufRead *.md call OpenMarkdown()
"autocmd BufWritePost *.less call SaveLess()
"autocmd vimenter *.vue set filetype=html shiftwidth=2
"autocmd vimenter *.wxss set filetype=css
"autocmd vimenter *.wxml set filetype=html
map <F5> :call RunCode()<CR>

func! RunCode()
    exec "w"
    if &filetype == 'python'
        exec "!time python3 %"
    elseif &filetype == 'javascript'
        exec "!time node %"
    elseif &filetype == 'sh'
        exec "!time /bin/bash %"
    endif
endfunc

"set background=light
" colorscheme summerfruit256 "fruchtig solarized8 afterglow slate morning darkblue shine afterglow
:set mps+=<:>  " add square bracket to matchpairs
set title
set noeb vb t_vb=
set ffs=unix
set noswapfile
