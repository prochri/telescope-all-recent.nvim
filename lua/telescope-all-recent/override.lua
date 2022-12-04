local sorters = require "telescope.sorters"
local pickers = require "telescope.pickers"
local action_state = require "telescope.actions.state"
local actions = require "telescope.actions"

local builtin = require 'telescope.builtin'

local cache = require 'telescope-all-recent.cache'

-- p(telescope.extensions)

local function store_original()
  -- store only the original functions
  if cache.original then
    return
  end
  cache.original = {}
  cache.original.sorter_new = sorters.Sorter.new
  cache.original.picker_new = pickers._Picker.new
  cache.original.action_select_default = getmetatable(actions.select_default).__call

  cache.original.builtin = {}
  for k, v in pairs(builtin) do
    cache.original.builtin[k] = v
  end
end

local function restore_original()
  if not cache.original then
    return
  end
  sorters.Sorter.new = cache.original.sorter_new
  pickers._Picker.new = cache.original.picker_new
  getmetatable(actions.select_default).__call = cache.original.action_select_default

  for k, _ in pairs(builtin) do
    builtin[k] = cache.original.builtin[k]
  end
  cache.original = nil
end

-- override builtin to cache name
local override_builtin = function()
  for k, _ in pairs(builtin) do
    builtin[k] = function(...)
      cache.picker_info.name = k
      return cache.original.builtin[k](...)
    end
  end
end


local override_picker_new = function(on_new_picker)
  ---@diagnostic disable-next-line: duplicate-set-field
  pickers._Picker.new = function(self, opts)
    local newPicker = cache.original.picker_new(self, opts)
    cache.picker_info.cwd = opts.cwd
    cache.picker_info.object = newPicker
    on_new_picker()
    if not cache.picker then
      return newPicker
    end
    -- try injecting scoring function after
    if newPicker.sorter then
      local old_scoring_function = newPicker.sorter.scoring_function
      newPicker.sorter.scoring_function = cache.sorting_function_generator(old_scoring_function)
    end
    return newPicker
  end
end

local override_sorter_new = function()
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

local override_action_select_default = function(on_entry_confirm)
  getmetatable(actions.select_default).__call = function(self, prompt_bufnr)
    local entry = action_state.get_selected_entry()
    on_entry_confirm(entry.ordinal)
    return cache.original.action_select_default(self, prompt_bufnr)
  end
end

local override = function(on_new_picker, on_entry_confirm)
  store_original()
  override_builtin()
  override_picker_new(on_new_picker)
  override_sorter_new()
  override_action_select_default(on_entry_confirm)
end

return {
  override = override,
  restore_original = restore_original
}
