# Getting Started
NodeJs neovim tools is inteded to be a collection of utility tools that fcilitates javascript/typescript NodeJs development.

## Required dependencies
- [nvim-treesitter](https://github.com/nvim-treesitter/nvim-treesitter) is required with `json` parser installed

## Instalation
Using [vim-plug](https://github.com/junegunn/vim-plug)
```
Plug 'stoleruradu/nodejstools.nvim'

-- somewhere in your config
require('nodejstools').setup()
```

Using [packer.nvim](https://github.com/wbthomason/packer.nvim)
```
use { 'stoleruradu/nodejstools.nvim' }

-- somewhere in your config
require('nodejstools').setup()
```
Using [lazy.nvim](https://github.com/folke/lazy.nvim)
```
-- plugins/nodejstools.lua:
return { 'stoleruradu/nodejstools.nvim', opts = {} }
```
## Usage

### Scripts runner

Being in a `package.json` file, put the cursor on a script under `scripts`.

- use `<Leader>e` to run a npm script.
- use `<C-c`> to stop the execution.
