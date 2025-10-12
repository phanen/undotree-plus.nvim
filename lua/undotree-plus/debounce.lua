---START INJECT debounce.lua

local M = {}

---@generic F: function
---@param ms integer|fun():integer Timeout in ms
---@param func F Function to debounce
---@param hash? integer|fun(...): any Function that determines id from arguments to func
---@return F Debounced function.
function M.debounce_trailing(ms, func, hash)
  local running = {} --- @type table<any,uv.uv_timer_t>

  if type(hash) == 'number' then
    local hash_i = hash
    hash = function(...) return select(hash_i, ...) end
  end

  if type(ms) == 'number' then
    local ms_i = ms
    ms = function() return ms_i end
  end

  return function(...)
    local id = hash and hash(...) or true
    if running[id] == nil then running[id] = assert(uv.new_timer()) end
    local timer = running[id]
    local argv = { ... }

    timer:start(ms(), 0, function()
      timer:stop()
      running[id] = nil
      func(unpack(argv, 1, table.maxn(argv)))
    end)
  end
end

---@generic F: function
---@param argc integer
---@param func F Function to throttle
---@param schedule? boolean
---@return F throttled function.
function M.throttle_by_id(argc, func, schedule)
  local scheduled = {} --- @type table<any,boolean>
  local running = {} --- @type table<any,boolean>
  return function(...)
    local id = table.concat(vim.list_slice({ ... }, 1, argc), ':')
    if scheduled[id] then return end
    if not running[id] or schedule then scheduled[id] = true end
    if running[id] then return end
    while scheduled[id] do
      scheduled[id] = nil
      running[id] = true
      func(...)
      running[id] = nil
    end
  end
end

return M
