# telescope-all-recent.nvim
(F)recency sorting for all [Telescope](https://github.com/nvim-telescope/telescope.nvim) pickers.

Very hacky solution, overriding telescope internals to provide recency/frecency sorting for any picker.

For now, only builtin pickers are supported.


## Requirements

- [telescope.nvim](https://github.com/nvim-telescope/telescope.nvim) (required)
- [sqlite.lua](https://github.com/kkharji/sqlite.lua) (required)

Timestamps and selected records are stored in an [SQLite3](https://www.sqlite.org/index.html) database for persistence and speed and accessed via `sqlite.lua`.

## Installation

Via [packer.nvim](https://github.com/wbthomason/packer.nvim):

```lua
use {
  'prochri/telescope-all-recent.nvim'
  config = function()
    require'telescope-all-recent'.setup{
      -- your config goes here
    }
  end
}
```

Make sure to load this after telescope.

## Configuration

The default configuration should come with sane values, so you can get started right away! If you want to change, here is how:
```lua
require'telescope-all-recent'.setup{
  -- TODO: add config settings here
}
```


## Inspiration

The overall structure, sqlite usage and the `frecency` sorting algorithm is heavily inspired by [telescope-frecency.nvim](https://github.com/nvim-telescope/telescope-frecency.nvim).
