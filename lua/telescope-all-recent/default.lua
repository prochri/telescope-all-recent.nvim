---@class AllRecentConfig.Database
---@field folder string
---@field file string
---@field max_timestamps number

---@alias AllRecentSortingStrategyEnum "recent" | "frecency"

---@class AllRecentConfig.PickerSettings
---@field disable? bool
---@field use_cwd? bool
---@field sorting? AllRecentSortingStrategyEnum

---@class AllRecentConfig.KindSettings.Extra
---@field name_include_prompt? bool
---@field prompt? string

---@alias AllRecentConfig.KindSettings AllRecentConfig.PickerSettings | AllRecentConfig.KindSettings.Extra

---@class AllRecentConfig.VimUiSelectSettings
---@field kinds table<string, AllRecentConfig.KindSettings>
---@field prompts table<string, AllRecentConfig.PickerSettings>

---@class AllRecentConfig
---@field database AllRecentConfig.Database
---@field scoring { recency_modifier: AllRecentRecencyModifier[], boost_factor: number }
---@field default AllRecentConfig.PickerSettings
---@field debug bool
---@field pickers table<string, AllRecentConfig.PickerSettings> TODO: make the types dependent on telescope builtins
---@field vim_ui_select AllRecentConfig.VimUiSelectSettings

local stdpath_data = vim.fn.stdpath("data")
if type(stdpath_data) ~= "string" and vim.isarray(stdpath_data) then
  stdpath_data = stdpath_data[1]
end
---@cast stdpath_data string
local data_folder = stdpath_data

---@type AllRecentConfig
local default_config = {
  database = {
    folder = data_folder,
    file = "telescope-all-recent.sqlite3",
    max_timestamps = 10,
  },
  scoring = {
    recency_modifier = {
      [1] = { age = 240, value = 100 }, -- past 4 hours
      [2] = { age = 1440, value = 80 }, -- past day
      [3] = { age = 4320, value = 60 }, -- past 3 days
      [4] = { age = 10080, value = 40 }, -- past week
      [5] = { age = 43200, value = 20 }, -- past month
      [6] = { age = 129600, value = 10 }, -- past 90 days
    },
    boost_factor = 0.0001,
  },
  default = {
    disable = true,
    use_cwd = true,
    sorting = "recent",
  },
  debug = false,
  -- does not make sense for:
  -- grep string
  -- live grep (too many results)
  -- TODO: buffers: might be useful for project/session, but: we must allow preprocesseing the string
  --
  -- oldfiles: are per definition already recent. If you need frecency files: use telescope-frecency
  -- command history: already recent
  -- search history: already recent
  --
  pickers = {
    -- pickers explicitly enabled
    -- not using cwd
    man_pages = {
      disable = false,
      use_cwd = false,
    },
    vim_options = {
      disable = false,
      use_cwd = false,
    },
    pickers = {
      disable = false,
      use_cwd = false,
    },
    builtin = {
      disable = false,
      use_cwd = false,
    },
    planets = {
      disable = false,
      use_cwd = false,
    },
    commands = {
      disable = false,
      use_cwd = false,
    },
    help_tags = {
      disable = false,
      use_cwd = false,
    },
    -- using cwd
    find_files = {
      disable = false,
      sorting = "frecency",
    },
    git_files = {
      disable = false,
      sorting = "frecency",
    },
    tags = {
      disable = false,
    },
    git_commits = {
      disable = false,
    },
    git_branches = {
      disable = false,
    },
    -- some explicitly disabled pickers: I consider them not useful.
    oldfiles = { disable = true },
    live_grep = { disable = true },
    grep_string = { disable = true },
    command_history = { disable = true },
    search_history = { disable = true },
    current_buffer_fuzzy_find = { disable = true },
  },
  -- support for telescope invoked through vim.ui.select, e.g. using dressing.nvim
  -- Specify the kind.
  -- Potentially fix to a specific prompt only.
  -- Other than that, all options are the same as for normal pickers
  vim_ui_select = {
    kinds = {},
    prompts = {},
  },
}

return default_config
