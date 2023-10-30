local log = require("telescope-all-recent.log")
local M = {}
M.original = nil
M.config = nil
local function reset()
  -- for LSP suggestions
  M.picker_info = {}
  M.picker_info.name = nil
  M.picker_info.object = nil
  M.picker_info.cwd = nil
  M.picker_info.opts = nil
  M.picker_info.vim_ui_select_opts = nil
  M.picker_info = {}
  M.picker = {}
  M.picker.name = nil
  M.picker.cwd = nil
  -- actually resetting here
  M.picker = nil
  M.sorting_function_generator = nil
end
reset()
function M.reset(reason)
  log.debug("Resetting cache" .. (reason and ": " .. reason or ""))
  reset()
end
M.has_picker = function() end

return M
