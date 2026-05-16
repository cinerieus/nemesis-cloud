"" ~/.config/nvim/init.vim
call plug#begin('~/.vim/plugged')
Plug 'catppuccin/nvim', { 'as': 'catppuccin' }
Plug 'itchyny/lightline.vim'
call plug#end()

""Look
colorscheme catppuccin-macchiato
let g:lightline = {'colorscheme': 'catppuccin'}
let $NVIM_TUI_ENABLE_TRUE_COLOR=1
set termguicolors

""Feel
set number
set mouse:a
"Return to last position in file
if has("autocmd")
  au BufReadPost * if line("'\"") > 0 && line("'\"") <= line("$") | exe "normal! g`\"" | endif
endif

""Syntax and Formatting
syntax enable
filetype plugin indent on
set tabstop=4
set shiftwidth=4
set shiftwidth=4
set expandtab
set foldmethod=manual

""Fix Pasting
nmap <PasteStart>  <NOP>
nmap <PasteEnd>    <NOP>
cmap <PasteStart>  <NOP>
cmap <PasteEnd>    <NOP>
