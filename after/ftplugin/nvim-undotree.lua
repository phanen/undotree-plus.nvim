local api = vim.api
local u = {
  undo = require('undotree-plus'),
  --- @param x any
  --- @return integer
  asinteger = function(x)
    local nx = assert(tonumber(x))
    assert(nx == math.floor(nx))
    return nx
  end,
}

local ut_buf = api.nvim_get_current_buf()
local group = api.nvim_create_augroup('my.nvim.undotree', {})

local render_diff
local new_text_changed = function(buf)
  return api.nvim_create_autocmd(
    'TextChanged',
    { group = group, buffer = buf, callback = render_diff }
  )
end

local on_text_changed
render_diff = vim.schedule_wrap(function()
  if not api.nvim_buf_is_valid(ut_buf) then return end
  local buf = u.undo.buf_from_title(api.nvim_buf_get_name(ut_buf))
  -- only create on new buf
  on_text_changed = on_text_changed or new_text_changed(buf)
  local ut_win = assert(vim.b[buf].nvim_undotree)
  local line = api.nvim_win_call(ut_win, api.nvim_get_current_line)
  u.undo.render_diff(buf, u.asinteger(line:match('%d+')))
end)

api.nvim_create_autocmd('CursorMoved', {
  group = group,
  buffer = ut_buf,
  callback = render_diff,
})

api.nvim_create_autocmd('BufEnter', {
  group = group,
  callback = vim.schedule_wrap(function(ev)
    if not api.nvim_buf_is_valid(ut_buf) then return true end
    local buf = u.undo.buf_from_title(api.nvim_buf_get_name(ut_buf))
    if
      not api.nvim_buf_is_valid(ev.buf)
      or ev.buf == ut_buf
      or ev.buf == buf
      or vim.bo[ev.buf].bt ~= ''
    then
      return
    end
    u.undo.open({ buf = ut_buf, win = vim.b[buf].nvim_undotree })
    vim.b[buf].nvim_undotree = nil
    pcall(api.nvim_del_autocmd, on_text_changed)
    on_text_changed = new_text_changed(ev.buf)
    render_diff()
  end),
})

local destroy = vim.F.nil_wrap(function()
  api.nvim_win_close(u.undo.diff_win, true)
  api.nvim_del_augroup_by_id(group)
end)

api.nvim_create_autocmd({ 'WinClosed', 'BufWinLeave' }, {
  buffer = ut_buf,
  once = true,
  callback = destroy,
})
