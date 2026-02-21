local M = {}

---@param x any
---@return integer
M.asinteger = function(x)
  local nx = tonumber(x)
  assert(nx == math.floor(nx))
  return nx
end

return M
