local cache = require("telescope-all-recent.cache")
local db_client = require("telescope-all-recent.frecency")
local override = require("telescope-all-recent.override")
local log = require("telescope-all-recent.log")

local default_config = require("telescope-all-recent.default")
local config = default_config

local function get_config(cfg, value)
  local config_value
  if cfg and cfg[value] ~= nil then
    config_value = cfg[value]
  else
    config_value = config.default[value]
  end
  if type(config_value) == "function" then
    config_value = config_value(cache.picker_info)
  end
  return config_value
end

local function establish_vim_ui_select_settings()
  local select_opts = cache.picker_info.vim_ui_select_opts
  if not select_opts then
    cache.reset()
    return
  end
  local cfg = config.vim_ui_select.kinds[select_opts.kind]
  local prompt = nil
  if not cfg then
    cfg = config.vim_ui_select.prompts[select_opts.prompt]
    prompt = select_opts.prompt
  end
  if not cfg then
    cache.reset()
    return
  end

  -- filter out select kinds with not fitting prompts
  if cfg.prompt and cfg.prompt ~= select_opts.prompt then
    cache.reset()
    return
  end

  local cwd
  if get_config(cfg, "use_cwd") then
    cwd = vim.fn.getcwd()
  else
    cwd = ""
  end

  -- for pickers found from the kind option, only inlcude prompt if explicitly set
  if not prompt and cfg.name_include_prompt then
    prompt = select_opts.prompt
  end

  local name = "vim_ui_select##" .. (select_opts.kind or "") .. "#" .. (prompt or "")
  cache.picker = { name = name, cwd = cwd }
  cache.sorting = get_config(cfg, "sorting")
end

local function establish_picker_settings()
  local picker_info = cache.picker_info
  if not picker_info.object then
    cache.reset()
    return
  end
  if type(picker_info.name) ~= "string" then
    establish_vim_ui_select_settings()
    return
  end

  local name = cache.picker_info.name
  local cwd = cache.picker_info.cwd
  -- disable option
  local picker_config = config.pickers[name]
  local function get_cfg(value)
    return get_config(picker_config, value)
  end

  if get_cfg("disable") then
    cache.reset()
    return
  end

  -- cwd options
  if not cwd then
    if get_cfg("use_cwd") then
      cwd = vim.fn.getcwd()
    else
      cwd = ""
    end
  end
  cache.picker = { name = name, cwd = cwd }

  -- sorting options
  cache.sorting = get_cfg("sorting")
end

local on_new_picker = function()
  log.debug("information about the started picker", cache.picker_info)
  establish_picker_settings()
  if not cache.picker then
    return
  end
  log.info("deduced information about the started picker", cache.picker, cache.sorting)

  local ok, entry_scores = pcall(db_client.get_picker_scores, cache.picker, cache.sorting)
  if not ok then
    vim.notify("Could not get picker scores for the current picker: " .. cache.picker.name, vim.log.levels.WARN)
    cache.reset()
    return
  end
  -- local entry_scores = db_client.get_picker_scores(cache.picker, cache.sorting)
  local scoring_boost_table = {}
  for i, entry_score in ipairs(entry_scores) do
    scoring_boost_table[entry_score.entry.value] = (#entry_scores - i + 1) * config.scoring.boost_factor
  end
  cache.sorting_function_generator = function(original_sorting_function)
    return function(sorter, prompt, line)
      local score = original_sorting_function(sorter, prompt, line)
      if score > 0 then
        score = score - (scoring_boost_table[line] or 0)
        if score < 0 then
          score = 0
        end
      end
      return score
    end
  end
end

local on_entry_confirm = function(value)
  if cache.picker then
    local ok, result = pcall(db_client.update_entry, cache.picker, value)
    if not ok then
      vim.notify("Could not save selected entry: " .. value .. ", error: " .. result, vim.log.levels.WARN)
    end
    cache.reset()
  end
end

local function setup_telescope_leave_autocommand()
  local telescope_all_recent_group = "telescope-all-recent"
  vim.api.nvim_create_augroup(telescope_all_recent_group, {})
  vim.api.nvim_create_autocmd("WinLeave", {
    group = telescope_all_recent_group,
    callback = function()
      if vim.bo.filetype ~= "TelescopePrompt" then
        return
      end
      cache.reset()
    end,
  })
end

local M = {}
function M.setup(opts)
  config = vim.tbl_deep_extend("force", default_config, opts)
  cache.config = config
  db_client.init(config)
  override.restore_original()
  override.override(on_new_picker, on_entry_confirm)
  setup_telescope_leave_autocommand()
end

function M.config()
  return config
end

function M.toggle_debug()
  config.debug = not config.debug
  if config.debug then
    vim.notify("debug mode enabled", vim.log.levels.INFO, { title = "telescope-all-recent" })
  else
    vim.notify("debug mode disabled", vim.log.levels.INFO, { title = "telescope-all-recent" })
  end
end

return M
