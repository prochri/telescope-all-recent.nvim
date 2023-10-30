local M = {}
local plugin_name = "telescope-all-recent.nvim"

function M.log(level, ...)
  local cache = require("telescope-all-recent.cache")
  if not cache.config.debug then
    return
  end
  local printResult = ""
  for _, v in ipairs({ ... }) do
    printResult = printResult .. vim.inspect(v, { depth = 2 }) .. "\n"
  end
  vim.notify(printResult, level, { title = plugin_name })
end

function M.debug(...)
  M.log(vim.log.levels.DEBUG, ...)
end

function M.info(...)
  M.log(vim.log.levels.INFO, ...)
end

function M.warn(...)
  M.log(vim.log.levels.WARN, ...)
end

function M.error(...)
  M.log(vim.log.levels.ERROR, ...)
end

return M
