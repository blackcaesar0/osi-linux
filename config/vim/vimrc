" OSI Linux vimrc — minimal, plugin-free, cyberpunk colors

set nocompatible
syntax on
filetype plugin indent on

" Display
set number relativenumber
set cursorline
set showmatch
set ruler showcmd
set wildmenu
set scrolloff=8
set signcolumn=yes

" Search
set hlsearch incsearch
set ignorecase smartcase

" Indentation — 4 spaces, no tabs
set expandtab tabstop=4 shiftwidth=4 softtabstop=4
set autoindent smartindent

" No swap or backup files
set noswapfile nobackup nowritebackup

" Splits open right and below
set splitright splitbelow

" Status line
set laststatus=2
set statusline=
set statusline+=%#OsiAccent#
set statusline+=\ %f\
set statusline+=%#OsiMid#
set statusline+=\ %m%r\ [%{&ff}]\ %y
set statusline+=%=
set statusline+=%#OsiMid#
set statusline+=\ %l/%L\ col:%c\
set statusline+=%#OsiAccent#
set statusline+=\ %p%%\

" Misc
set backspace=indent,eol,start
set encoding=utf-8
set hidden ttyfast
set updatetime=250

" Cyberpunk color overrides
set background=dark
hi Normal       ctermbg=NONE
hi CursorLine   ctermbg=235 cterm=NONE
hi CursorLineNr ctermfg=6 cterm=bold
hi LineNr       ctermfg=239
hi Visual       ctermbg=236
hi Search       ctermfg=0 ctermbg=6
hi IncSearch    ctermfg=0 ctermbg=5
hi OsiAccent    ctermbg=6 ctermfg=0 cterm=bold
hi OsiMid       ctermbg=235 ctermfg=7
hi StatusLine   cterm=NONE ctermbg=235 ctermfg=7
hi StatusLineNC cterm=NONE ctermbg=234 ctermfg=239
hi Pmenu        ctermbg=235 ctermfg=7
hi PmenuSel     ctermbg=6 ctermfg=0
hi VertSplit    ctermfg=235 ctermbg=NONE
hi Comment      ctermfg=239
hi String       ctermfg=2
hi Constant     ctermfg=3
hi Function     ctermfg=4
hi Keyword      ctermfg=5
hi Type         ctermfg=6
hi SignColumn   ctermbg=NONE

" Leader key
let mapleader = "\\"

" Clear search highlight with Enter
nnoremap <CR> :nohlsearch<CR><CR>

" Quick save
nnoremap <leader>w :w<CR>

" Split navigation
nnoremap <C-h> <C-w>h
nnoremap <C-j> <C-w>j
nnoremap <C-k> <C-w>k
nnoremap <C-l> <C-w>l
