local telescope = require("telescope")
local sorters = require("telescope.sorters")
local pickers = require("telescope.pickers")
local action_state = require("telescope.actions.state")
local actions = require("telescope.actions")
local builtin = require("telescope.builtin")
local state = require("telescope.state")

local cache = require("telescope-all-recent.cache")
local log = require("telescope-all-recent.log")

local NO_PICKER_CALLED_MESSAGE =
  "New picker was not called. No picker was opened. (Can happen in LSP definition/references)"

local function iterate_extensions()
  local iter_table = {}
  for name, extension_table in pairs(telescope.extensions) do
    for method, _ in pairs(extension_table) do
      local combi = name .. "#" .. method
      table.insert(iter_table, {
        name = name,
        method = method,
        combi = combi,
      })
    end
  end
  return iter_table
end

local function store_original()
  -- store only the original functions
  if cache.original then
    return
  end
  cache.original = {}
  cache.original.sorter_new = sorters.Sorter.new
  cache.original.picker_new = pickers._Picker.new
  cache.original.action_select_default = getmetatable(actions.select_default).__call

  cache.original.vim_ui_select = vim.ui.select

  -- builtin
  cache.original.builtin = {}
  for k, v in pairs(builtin) do
    cache.original.builtin[k] = v
  end

  -- extensions
  cache.original.load_extension = telescope.load_extension
  cache.original.extensions = {}
  for _, ext in ipairs(iterate_extensions()) do
    cache.original.extensions[ext.combi] = telescope.extensions[ext.name][ext.method]
  end
end

local function restore_original()
  if not cache.original then
    return
  end
  sorters.Sorter.new = cache.original.sorter_new
  pickers._Picker.new = cache.original.picker_new
  getmetatable(actions.select_default).__call = cache.original.action_select_default

  vim.ui.select = cache.original.vim_ui_select

  for k, _ in pairs(builtin) do
    builtin[k] = cache.original.builtin[k]
  end

  telescope.load_extension = cache.original.load_extension
  for _, ext in ipairs(iterate_extensions()) do
    telescope.extensions[ext.name][ext.method] = cache.original.extensions[ext.combi]
  end
  cache.original = nil
end

local function reset_if_new_picker_not_called()
  if not cache.new_picker_called then
    cache.reset(NO_PICKER_CALLED_MESSAGE)
  end
end

-- override builtin to cache name
local function override_builtin()
  for k, _ in pairs(builtin) do
    builtin[k] = function(...)
      cache.picker_info.name = k
      local result = cache.original.builtin[k](...)
      reset_if_new_picker_not_called()
      return result
    end
  end
end

local function restore_extensions()
  for _, ext in ipairs(iterate_extensions()) do
    telescope.extensions[ext.name][ext.method] = cache.original.extensions[ext.combi]
  end
end

local function override_extensions()
  local function generate_overide(combi)
    return function(...)
      cache.picker_info.name = combi
      local result = cache.original.extensions[combi](...)
      reset_if_new_picker_not_called()
      return result
    end
  end

  for _, ext in ipairs(iterate_extensions()) do
    telescope.extensions[ext.name][ext.method] = generate_overide(ext.combi)
  end

  -- override the load extension function
  -- the returned table is stored into the telescope.extension table. Modifying provides us with the wanted extension.
  ---@diagnostic disable-next-line: duplicate-set-field
  telescope.load_extension = function(name)
    local extension_table = cache.original.load_extension(name)
    for method, _ in pairs(extension_table) do
      local combi = name .. "#" .. method
      -- back up original method and store new one
      cache.original.extensions[combi] = extension_table[method]
      extension_table[method] = generate_overide(combi)
    end
    return extension_table
  end
end

local function override_picker_new(on_new_picker)
  ---@diagnostic disable-next-line: duplicate-set-field
  pickers._Picker.new = function(self, opts)
    local newPicker = cache.original.picker_new(self, opts)
    cache.picker_info.cwd = opts.cwd
    cache.picker_info.object = newPicker
    cache.picker_info.opts = newPicker
    cache.new_picker_called = true
    on_new_picker()
    if not cache.picker then
      return newPicker
    end
    -- try injecting scoring function, if sorter was already created
    if newPicker.sorter then
      local old_scoring_function = newPicker.sorter.scoring_function
      newPicker.sorter.scoring_function = cache.sorting_function_generator(old_scoring_function)
    end
    return newPicker
  end
end

local function override_sorter_new()
  ---@diagnostic disable-next-line: unused-local, duplicate-set-field, assign-type-mismatch
  sorters.Sorter.new = function(self, opts)
    local newSorter = cache.original.sorter_new(sorters.Sorter, opts)
    if not cache.picker then
      return newSorter
    end
    local old_scoring_function = newSorter.scoring_function
    newSorter.scoring_function = cache.sorting_function_generator(old_scoring_function)
    return newSorter
  end
end

local function override_action_select_default(on_entry_confirm)
  getmetatable(actions.select_default).__call = function(self, prompt_bufnr)
    local entry = action_state.get_selected_entry()
    if type(entry) == "table" then
      on_entry_confirm(entry.ordinal)
    end
    return cache.original.action_select_default(self, prompt_bufnr)
  end
end

local function override_vim_ui_select()
  ---@diagnostic disable-next-line: duplicate-set-field
  vim.ui.select = function(items, opts, on_choice)
    if cache.config.debug then
      log.info("information from ui select", opts)
    end
    cache.picker_info.vim_ui_select_opts = opts
    return cache.original.vim_ui_select(items, opts, on_choice)
  end
end

local function override(on_new_picker, on_entry_confirm)
  store_original()
  override_builtin()
  override_extensions()
  override_picker_new(on_new_picker)
  override_sorter_new()
  override_action_select_default(on_entry_confirm)
  override_vim_ui_select()
end

return {
  override = override,
  restore_original = restore_original,
}
