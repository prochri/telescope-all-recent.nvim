package.loaded["telescope-all-recent.sql_wrapper"] = nil
local sqlwrap = require("telescope-all-recent.sql_wrapper")
local log = require("telescope-all-recent.log")

local MAX_TIMESTAMPS = 10

---@class AllRecentRecencyModifier
---@field age number -- age in minutes
---@field value number -- the score to apply to this age

-- modifier used as a weight in the recency_score calculation:
---@type AllRecentRecencyModifier[]
local recency_modifier = {
  [1] = { age = 240, value = 100 }, -- past 4 hours
  [2] = { age = 1440, value = 80 }, -- past day
  [3] = { age = 4320, value = 60 }, -- past 3 days
  [4] = { age = 10080, value = 40 }, -- past week
  [5] = { age = 43200, value = 20 }, -- past month
  [6] = { age = 129600, value = 10 }, -- past 90 days
}

local sql_wrapper = nil

-- TODO: rewrite and actually validate the db at some point

local function init(config)
  if sql_wrapper then
    return
  end
  sql_wrapper = sqlwrap:new()
  sql_wrapper:bootstrap(config.database)
  recency_modifier = config.scoring.recency_modifier

  -- if auto_validate then
  --   validate_db(safe_mode)
  -- end
end

local calculate_score = {}
function calculate_score.recent(_, timestamps)
  local min_age = nil
  for _, ts in ipairs(timestamps) do
    if not min_age or ts.age < min_age then
      min_age = ts.age
    end
  end
  return -min_age
end

function calculate_score.frecency(frequency, timestamps)
  local recency_score = 0
  for _, ts in pairs(timestamps) do
    for _, rank in ipairs(recency_modifier) do
      if ts.age <= rank.age then
        recency_score = recency_score + rank.value
        break
      end
    end
  end

  return frequency * recency_score / MAX_TIMESTAMPS
end

local function update_entry(picker, value)
  if not sql_wrapper then
    log.warn("SQL wrapper not initialized")
    return
  end
  sql_wrapper:update_entry({
    value = value,
    picker = picker,
  })
end

local function get_picker_scores(picker, sorting)
  if not sql_wrapper then
    return {}
  end
  local entries = sql_wrapper:get_picker_entries(picker)

  local scores = {}
  for _, entry in ipairs(entries) do
    local score = entry.count == 0 and 0 or calculate_score[sorting](entry.count, entry.timestamps)
    table.insert(scores, {
      entry = entry,
      score = score,
    })
  end

  table.sort(scores, function(a, b)
    return a.score > b.score
  end)
  return scores
end

-- local picker = {
--   cwd = '',
--   name = 'commands'
-- }
-- local ent = {
--   value = 'PackerStatus',
--   picker = picker
-- }
-- init()
-- get_picker_scores(picker)

return {
  init = init,
  get_picker_scores = get_picker_scores,
  update_entry = update_entry,
}
