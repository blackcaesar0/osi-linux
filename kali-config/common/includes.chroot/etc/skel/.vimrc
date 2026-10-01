" OSI Linux vimrc — minimal, plugin-free, OSI-Noir (strict B&W)

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

" OSI-Noir color overrides — strict B&W.
" Uses the 256-colour grayscale ramp (232-255) rather than ANSI 1-6, so the
" scheme stays monochrome even outside xfce4-terminal (TTY, ssh, tmux) where
" the OSI-Noir 16-colour palette remap is not in effect. Syntax is
" differentiated by brightness and weight instead of hue.
set background=dark
hi Normal       ctermbg=NONE ctermfg=250
hi CursorLine   ctermbg=235 cterm=NONE
hi CursorLineNr ctermfg=255 cterm=bold
hi LineNr       ctermfg=240
hi Visual       ctermbg=238
hi Search       ctermfg=16  ctermbg=250
hi IncSearch    ctermfg=16  ctermbg=255 cterm=bold
hi OsiAccent    ctermbg=255 ctermfg=16  cterm=bold
hi OsiMid       ctermbg=236 ctermfg=250
hi StatusLine   cterm=NONE ctermbg=236 ctermfg=250
hi StatusLineNC cterm=NONE ctermbg=234 ctermfg=240
hi Pmenu        ctermbg=236 ctermfg=250
hi PmenuSel     ctermbg=255 ctermfg=16  cterm=bold
hi VertSplit    ctermfg=236 ctermbg=NONE
hi Comment      ctermfg=242
hi String       ctermfg=252
hi Constant     ctermfg=247
hi Identifier   ctermfg=250
hi Function     ctermfg=255 cterm=bold
hi Keyword      ctermfg=255 cterm=bold
hi Statement    ctermfg=255 cterm=bold
hi Type         ctermfg=252 cterm=bold
hi PreProc      ctermfg=247
hi Special      ctermfg=247
hi MatchParen   ctermbg=240 ctermfg=255 cterm=bold
hi Todo         ctermbg=255 ctermfg=16  cterm=bold
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
