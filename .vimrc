" ruizsamuel's vimrc settings
" Author and maintainer: Samuel Ruiz <samuel@ruizsamuel.es>
"
" LICENSE:
" You are free to read and study this bundle or snippets of it and to use
" it on your own vimrc settings. Feel free to tweak and adapt my vimrc to
" suit your needs and to make the changes yours. Attribution to this vimrc
" is not required although is thanked.

" Stop acting like classic vi
set nocompatible            " disable vi compatibility mode
set history=1000            " increase history size
set noswapfile              " don't create swapfiles
set nobackup                " don't backup, use git!

" Relative line numbers

set number relativenumber
set nu rnu

" Modify indenting settings
set autoindent              " autoindent always ON.

" Modify some other settings about files
set encoding=utf-8          " always use unicode (god damnit, windows)
set backspace=indent,eol,start " backspace always works on insert mode
set hidden

"filetype plugin indent on
" show existing tab with 4 spaces width
set tabstop=8
" when indenting with '>', use 4 spaces width
set shiftwidth=8

" Auto Open NerdTree
autocmd vimenter * NERDTree

" Auto Open VimCompletesMe
autocmd FileType vim let b:vcm_tab_complete = 'vim'

" Colorscheme configuration.
if &t_Co > 2
	syntax on
	silent! colorscheme pablo
	set background=dark

	highlight Comment ctermfg=blue

	set colorcolumn=80
endif

" Mark trailing spaces depending on whether we have a fancy terminal or not
if &t_Co > 2
	highlight ExtraWhitespace ctermbg=1
	match ExtraWhitespace /\s\+$/
else
	set listchars=trail:~
	set list
endif
