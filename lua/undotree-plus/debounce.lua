---START INJECT debounce.lua

local uv = vim.uv or vim.loop ---@diagnostic disable-line: deprecated

local M = {}

--- @class debounce_trailing
--- @field timeout integer|fun():integer Timeout in ms
--- @field hash? integer|fun(...): any Function that determines id from arguments to `fn`

--- @generic F: function
--- @param opts debounce_trailing|integer|fun():integer
--- @param fn F Function to debounce
--- @return F Debounced function.
M.debounce_trailing = function(opts, fn)
  local timeout --- @type (integer|fun():integer)?
  local hash --- @type (integer|fun(...): any)?

  if type(opts) == 'table' then
    timeout = opts.timeout
    hash = opts.hash
  else
    timeout = opts
  end

  if type(hash) == 'number' then
    local hash_i = hash
    --- @return any
    hash = function(...) return select(hash_i, ...) end
  elseif type(hash) ~= 'function' then
    hash = nil
  end

  if type(timeout) == 'number' then
    local ms_i = timeout
    timeout = function() return ms_i end
  end

  local running = {} --- @type table<any, uv.uv_timer_t?>

  return function(...)
    local id = hash and hash(...) or true
    local argv, argc = { ... }, select('#', ...)

    local timer = running[id]
    if not timer or timer:is_closing() then
      timer = assert(uv.new_timer())
      running[id] = timer
    end

    timer:start(timeout(), 0, function()
      timer:close()
      running[id] = nil
      fn(unpack(argv, 1, argc))
    end)
  end
end

--- @class throttle_async.Opts
--- @field hash? integer|fun(...): any Function that determines id from arguments to fn
--- @field schedule? boolean If true, always schedule next call if called while running

--- @generic T
--- @param opts throttle_async.Opts
--- @param fn async fun(...: T...) Function to throttle
--- @return async fun(...:T ...) # Throttled function.
M.throttle_async = function(opts, fn)
  local scheduled = {} --- @type table<any,boolean>
  local running = {} --- @type table<any,boolean>

  local hash = opts.hash
  local schedule = opts.schedule or false

  if type(hash) == 'number' then
    local hash_i = hash
    hash = function(...) return select(hash_i, ...) end
  elseif type(hash) ~= 'function' then
    hash = nil
  end

  --- @async
  return function(...)
    local id = hash and hash(...) or true
    if scheduled[id] then return end
    if not running[id] or schedule then scheduled[id] = true end
    if running[id] then return end
    while scheduled[id] do
      scheduled[id] = nil
      running[id] = true
      fn(...)
      running[id] = nil
    end
  end
end

return M
