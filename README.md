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
  database = {
    folder = vim.fn.stdpath("data"),
    file = "telescope-all-recent.sqlite3",
    max_timestamps = 10,
  },
  scoring = {
    recency_modifier = { -- also see telescope-frecency for these settings
      [1] = { age = 240, value = 100 }, -- past 4 hours
      [2] = { age = 1440, value = 80 }, -- past day
      [3] = { age = 4320, value = 60 }, -- past 3 days
      [4] = { age = 10080, value = 40 }, -- past week
      [5] = { age = 43200, value = 20 }, -- past month
      [6] = { age = 129600, value = 10 } -- past 90 days
    },
    -- how much the score of a recent item will be improved.
    boost_factor = 0.0001
  },
  default = {
    disable = true, -- disable all-recent
    use_cwd = true, -- differentiate scoring for each picker based on cwd
    sorting = 'recent' -- sorting: options: 'recent' and 'frecency'
  },
  pickers = { -- allows you to overwrite the default settings for each picker
    man_pages = { -- enable man_pages picker. Disable cwd and use frecency sorting.
      disable = false,
      use_cwd = false,
      sorting = 'frecency',
    },

    -- change settings for a telescope extension.
    -- To find out about extensions, you can use `print(vim.inspect(require'telescope'.extensions))`
    ['extension_name#extension_method'] = {
      -- [...]
    }
  }
}
```

The default config values can be found [here](./lua/telescope-all-recent/default.lua)


## Inspiration

The overall structure, sqlite usage and the `frecency` sorting algorithm is heavily inspired by [telescope-frecency.nvim](https://github.com/nvim-telescope/telescope-frecency.nvim).
