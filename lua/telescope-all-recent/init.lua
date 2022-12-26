local cache = require "telescope-all-recent.cache"
local db_client = require "telescope-all-recent.frecency"
local override = require "telescope-all-recent.override"

local default_config = require 'telescope-all-recent.default'
local config = default_config

local function establish_picker_settings()
  local picker_info = cache.picker_info
  if type(picker_info.name) ~= "string" or not picker_info.object then
    cache.reset()
    return
  end

  local name = cache.picker_info.name
  local cwd = cache.picker_info.cwd
  -- disable option
  local picker_config = config.pickers[name]
  local function get_config(value)
    local config_value
    if picker_config and picker_config[value] ~= nil then
      config_value = picker_config[value]
    else
      config_value = config.default[value]
    end
    if type(config_value) == "function" then
      config_value = config_value(cache.picker_info)
    end
    return config_value
  end

  if get_config('disable') then
    cache.reset()
    return
  end

  -- cwd options
  if not cwd then
    if get_config('use_cwd') then
      cwd = vim.fn.getcwd()
    else
      cwd = ''
    end
  end
  cache.picker = { name = name, cwd = cwd }

  -- sorting options
  cache.sorting = get_config('sorting')
  print(cache.sorting)
end

local on_new_picker = function()
  establish_picker_settings()
  if not cache.picker then
    return
  end
  -- TODO: inform user about picker config (with log level)

  local ok, entry_scores = pcall(db_client.get_picker_scores, cache.picker, cache.sorting)
  if not ok then
    vim.notify('Could not get picker scores for the current picker: ' .. result, vim.log.levels.WARN)
    cache.reset()
    return
  end
  -- local entry_scores = db_client.get_picker_scores(cache.picker, cache.sorting)
  local scoring_boost_table = {}
  for i, entry_score in ipairs(entry_scores) do
    scoring_boost_table[entry_score.entry.value] = (#entry_scores - i + 1) * 0.000001
  end
  cache.sorting_function_generator = function(original_sorting_function)
    return function(sorter, prompt, line)
      local score = original_sorting_function(sorter, prompt, line)
      if score > 0 then
        score = score - (scoring_boost_table[line] or 0)
        if score < 0 then score = 0 end
      end
      -- print("new score", score, "item", line, "scoring boost", scoring_boost_table[line])
      return score
    end
  end
end

local on_entry_confirm = function(value)
  if cache.picker then
    local ok, result = pcall(db_client.update_entry, cache.picker, value)
    if not ok then
      vim.notify('Could not get save selected entry: ' .. value .. ', error: ' .. result, vim.log.levels.WARN)
    end
    cache.reset()
  end
end
-- TODO: on telescope exit also reset the cache

local M = {}
function M.setup(opts)
  config = vim.tbl_deep_extend('force', default_config, opts)
  db_client.init(config.database)
  override.restore_original()
  override.override(on_new_picker, on_entry_confirm)
end

return M
