M = {}
M.original = nil
M.config = nil
M.reset = function()
  M.picker_info = {}
  M.picker_info.name = nil
  M.picker_info.object = nil
  M.picker_info.cwd = nil
  M.picker_info.opts = nil
  M.picker_info.vim_ui_select_opts = nil
  M.picker = {}
  -- for LSP suggestions
  M.picker.name = nil
  M.picker.cwd = nil
  M.picker = nil
  M.sorting_function_generator = nil
end
M.reset()
M.has_picker = function() end

return M
