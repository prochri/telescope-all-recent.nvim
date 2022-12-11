local has_sqlite, sqlite = pcall(require, "sqlite")
if not has_sqlite then
  error("This plugin requires sqlite.lua (https://github.com/tami5/sqlite.lua) " .. tostring(sqlite))
end

-- TODO: pass in max_timestamps from db.lua
local MAX_TIMESTAMPS = 10

local db_table      = {}
db_table.pickers    = "pickers"
db_table.entries    = "entries"
db_table.timestamps = "timestamps"

--

-- TODO: NEXT!
-- extend substr sorter to have modes:
-- when current string is prefixed by `:foo`, results are tag_names that come from tags/workspaces table. (if `:foo ` token is incomplete it is ignored)
-- when a complete workspace tag is matched ':foobar:', results are indexed_files filtered by if their parent_dir is a descendant of the workspace_dir
-- a recursive scan_dir() result is added to the  :foobar: filter results; any non-indexed_files are given a score of zero, and are alphabetically sorted below the indexed_results

-- make tab completion for tab_names in insert mode`:foo|` state: cycles through available options

local M = {}

function M:new()
  local o = {}
  setmetatable(o, self)
  self.__index = self
  self.db = nil

  return o
end

function M:bootstrap(db_root)
  if self.db then return end

  -- opts = opts or {}
  -- self.max_entries = opts.max_entries or 2000

  -- create the db if it doesn't exist
  db_root = db_root or os.getenv('HOME') -- TODO: move it to data home again
  local db_filename = db_root .. "/telescope-recent.sqlite3"
  self.db = sqlite:open(db_filename)
  if not self.db then
    vim.notify("Telescope-Frecency: error in opening DB", vim.log.levels.ERROR)
    return
  end

  local first_run = false
  if not self.db:exists(db_table.pickers) then
    first_run = true

    -- create tables if they don't exist
    self.db:create(db_table.pickers, {
      id   = { "INTEGER", "PRIMARY", "KEY" },
      name = "TEXT",
      cwd  = "TEXT",
    })
    self.db:create(db_table.entries, {
      id        = { "INTEGER", "PRIMARY", "KEY" },
      value     = 'TEXT',
      picker_id = "INTEGER",
      count     = "INTEGER",
    })

    self.db:create(db_table.timestamps, {
      id        = { "INTEGER", "PRIMARY", "KEY" },
      entry_id  = "INTEGER",
      timestamp = "REAL"
      -- FOREIGN KEY(entry_id)  REFERENCES files(id)
    })
  end

  self.db:close()
  return first_run
end

--

function M:do_transaction(t, params)
  return self.db:with_open(function(db)
    local case = {
      [1] = function() return db:select(t.cmd_data, params) end,
      [2] = function() return db:insert(t.cmd_data, params) end,
      [3] = function() return db:delete(t.cmd_data, params) end,
      [4] = function() return db:eval(t.cmd_data, params) end,
    }
    return case[t.cmd]()
  end)
end

local cmd = {
  select = 1,
  insert = 2,
  delete = 3,
  eval   = 4,
}

local queries = {
  pickers = {
    add = {
      cmd      = cmd.insert,
      cmd_data = db_table.pickers
    },
    delete = {
      cmd      = cmd.delete,
      cmd_data = db_table.pickers
    },
    get = {
      cmd      = cmd.select,
      cmd_data = db_table.pickers
    },
  },
  entries = {
    add = {
      cmd      = cmd.insert,
      cmd_data = db_table.entries
      -- cmd_data = "INSERT INTO entries (count, picker_id, value) values(:count, :picker_id, :value)"
    },
    delete = {
      cmd      = cmd.delete,
      cmd_data = db_table.entries
    },
    get = {
      cmd      = cmd.select,
      cmd_data = db_table.entries
    },
    update_counter = {
      cmd      = cmd.eval,
      cmd_data = "UPDATE entries SET count = count + 1 WHERE id == :entry_id;"
    },
  },
  timestamps = {
    add = {
      cmd      = cmd.eval,
      cmd_data = "INSERT INTO timestamps (entry_id, timestamp) values(:entry_id, julianday('now'));"
    },
    delete = {
      cmd      = cmd.delete,
      cmd_data = db_table.timestamps
    },
    get = {
      cmd      = cmd.select,
      cmd_data = db_table.timestamps,
    },
    get_ages = {
      cmd      = cmd.eval,
      cmd_data = "SELECT id, entry_id, CAST((julianday('now') - julianday(timestamp)) * 24 * 60 AS INTEGER) AS age FROM timestamps WHERE entry_id == :entry_id;"
    },
    delete_before_id = {
      cmd      = cmd.eval,
      cmd_data = "DELETE FROM timestamps WHERE id < :id and entry_id == :entry_id;"
    },
  },
}

M.queries = queries

--

local function row_id(entry)
  return (not vim.tbl_isempty(entry)) and entry[1].id or nil
end

local function escape_chars(value)
  local val, _ = value:gsub("[%%()]", function(c)
    local encoding = string.format("%2x", c:byte())
    return "%" .. encoding
  end)
  return val
end

local function parse_escaped_chars(value)
  local val, _ = value:gsub("%%..", function(match)
    local s = match:sub(2)
    local c = string.char(tonumber(s, 16))
    return c
  end)
  return val
end

function M:get_or_insert(table_commands, row, additional_values)
  additional_values = additional_values or {}
  local id
  id = row_id(self:do_transaction(table_commands.get, { where = row }))
  if not id then
    -- FIXME: due to https://github.com/kkharji/sqlite.lua/issues/150, I need to escape the entry
    row = vim.tbl_extend('keep', row, additional_values)
    self:do_transaction(table_commands.add, row)
    id = row_id(self:do_transaction(table_commands.get, { where = row }))
  end
  return id
end

-- entry: { value: str, picker: {cwd: str, name: str}}
function M:update_entry(entry)
  -- get or insert picker and entry
  local picker_id = self:get_or_insert(queries.pickers, entry.picker)
  local table_entry = { value = escape_chars(entry.value), picker_id = picker_id }
  local entry_id = self:get_or_insert(queries.entries, table_entry, { count = 0 })
  -- update entry counter
  self:do_transaction(queries.entries.update_counter, { entry_id = entry_id })
  -- register timestamp for this update
  self:do_transaction(queries.timestamps.add, { entry_id = entry_id })
  return entry_id
end

function M:trim_timestamps(entry_id)
  -- trim timestamps to MAX_TIMESTAMPS per entry (there should be up to MAX_TS + 1 at this point)
  local timestamps = self:do_transaction(queries.timestamps.get, { where = { entry_id = entry_id } })
  local trim_at = timestamps[(#timestamps - MAX_TIMESTAMPS) + 1]
  if trim_at then
    self:do_transaction(queries.timestamps.delete_before_id, { id = trim_at.id, entry_id = entry_id })
  end
end

function M:get_picker_entries(picker)
  local picker_id = row_id(self:do_transaction(queries.pickers.get, { where = picker }))
  if not picker_id then return {} end
  local entries = self:do_transaction(queries.entries.get, { where = { picker_id = picker_id } })
  -- TODO: get timestamps directly via SQL query, maybe via group by
  for _, entry in ipairs(entries) do
    entry.value = parse_escaped_chars(entry.value)
    entry.timestamps = self:do_transaction(queries.timestamps.get_ages, { entry_id = entry.id })
  end
  return entries
end

function M:trim_picker_entries(picker_id)
  vim.notify('trimming picker entries not supported yet', vim.log.levels.WARN)
end

local picker = {
  cwd = '',
  name = 'help_tags'
}
local ent = {
  value = '%vim.notify()',
  picker = picker
}
local testsql = M:new()
testsql:bootstrap()
testsql:update_entry(ent)
-- p(testsql:get_picker_entries(picker))
-- p(testsql)


return M
