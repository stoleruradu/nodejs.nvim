# Getting Started
NodeJs neovim tools that fcilitates javascript/typescript NodeJs development.

## Required dependencies
- [nvim-treesitter](https://github.com/nvim-treesitter/nvim-treesitter) is required with `json` parser installed

## Instalation
Using [vim-plug](https://github.com/junegunn/vim-plug)
```
Plug 'stoleruradu/nodejs.nvim'

-- somewhere in your config
require('nodejs').setup()
```

Using [packer.nvim](https://github.com/wbthomason/packer.nvim)
```
use { 'stoleruradu/nodejs.nvim' }

-- somewhere in your config
require('nodejs').setup()
```
Using [lazy.nvim](https://github.com/folke/lazy.nvim)
```
-- plugins/nodejs.lua:
return { 'stoleruradu/nodejs.nvim', opts = {} }
```
## Usage

### Scripts runner

Being in a `package.json` file, put the cursor on a script under `scripts`.

- use `<Leader>e` to run a npm script.
- use `<C-c`> to stop the execution.

