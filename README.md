# telescope-all-recent.nvim
(F)recency sorting for all [Telescope](https://github.com/nvim-telescope/telescope.nvim) pickers.

![demo](https://user-images.githubusercontent.com/38609485/210369490-98c0fecc-ad96-4efa-9360-55b012d70eb6.gif)

Very hacky solution, overriding telescope internals to provide recency/frecency sorting for any picker.


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

If you are creating keybindings to telescope via lua functions,
either load this plugin first and then bind the function, or wrap the call in another function (see [#2](https://github.com/prochri/telescope-all-recent.nvim/issues/2)):
```lua
-- This may bind to old telescope function depending on your load order:
-- vim.keymap.set('n', '<leader>f', require'telescope'.builtins.find_files)
-- So: better wrap it in a function:
vim.keymap.set('n', '<leader>f', function() require'telescope'.builtins.find_files() end)
```

## Configuration

The default configuration should come with sane values, so you can get started right away! 
The following builtin pickers are activated by default:
- man_pages
- vim_options
- pickers
- builtin
- planets
- commands
- help_tags
- find_files
- git_files
- tags
- git_commits
- git_branches

There are two different sorting algorithms available. They can be set for each picker individually:
- **recent**: show the most recently selected items first.
- **frecent**: consider both the frequency and recency of the items (see [telescope-frecency.nvim](https://github.com/nvim-telescope/telescope-frecency.nvim))

To use all-recent for a telescope extension, find out the extensions name and picker method,
for example using `print(vim.inspect(require'telescope'.extensions))` and then add this in the plugins configuration:
```lua
{
  pickers = {
    // ...
    ['extension_name#extension_method'] = {
      disable = false,
      use_cwd = false,
      sorting = 'recent',
    }
  }
}
```

If you want to change some settings or add pickers, here is how:

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
    disable = true, -- disable any unkown pickers (recommended)
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

The default config values can be found [here](./lua/telescope-all-recent/default.lua).

## How it works

Telescope does not provide the relevant hooks/callback functions to build this nicely.
So, this plugin first stores some of the original functions and then overrides them:

- calls to `telescope.builtin` and `telescope.extensions[extension_name]` are overriden. This allows us to get the name of the called picker.
- the `Picker:new` is replaced. We want to get all information we can about what picker we are dealing with.
- the `Sorter:new` function is replaced to allow us to insert a custom sorting function, which boosts the scores of (f)recent items by a small amount.
- the `action.select_default.__call` allows us to see, which result is finally selected and add it to the database.

All of this is done in [override.lua](./lua/telescope-all-recent/override.lua).
  

## Inspiration

The overall structure, sqlite usage and the `frecency` sorting algorithm is heavily inspired by [telescope-frecency.nvim](https://github.com/nvim-telescope/telescope-frecency.nvim).
