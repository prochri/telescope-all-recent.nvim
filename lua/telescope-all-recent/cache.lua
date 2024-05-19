local log = require("telescope-all-recent.log")
---@class AllRecentCache.PickerInfo
---@field name string
---@field object any
---@field cwd string
---@field opts any
---@field vim_ui_select_opts any

---@class AllRecentCache.Picker
---@field name string
---@field cwd string

---@class AllRecentCache
---@field original any
---@field config AllRecentConfig
---@field picker_info AllRecentCache.PickerInfo
---@field picker AllRecentCache.Picker
---@field new_picker_called boolean
---@field sorting AllRecentSortingStrategyEnum
---@field sorting_function_generator function
local M = {}
M.original = nil
M.config = nil
local function reset()
  -- actually resetting here
  M.picker = {}
  M.picker_info = {}
  M.sorting_function_generator = nil
  M.new_picker_called = false
end
reset()
function M.reset(reason)
  log.debug("Resetting cache" .. (reason and ": " .. reason or ""))
  reset()
end
M.has_picker = function() end

return M
