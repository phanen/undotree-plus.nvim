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
local group0 = api.nvim_create_augroup('nvim.undotree', { clear = false })

local render_diff
local new_text_changed = function(buf)
  return api.nvim_create_autocmd(
    'TextChanged',
    { group = group, buffer = buf, callback = render_diff }
  )
end

local destroy = vim.F.nil_wrap(function()
  api.nvim_win_close(u.undo.diff_win, true)
  api.nvim_clear_autocmds({ group = group0 })
  api.nvim_clear_autocmds({ group = group })
end)

local on_text_changed
render_diff = vim.schedule_wrap(function()
  if not api.nvim_buf_is_valid(ut_buf) then return destroy() end
  local buf = u.undo.buf_from_title(api.nvim_buf_get_name(ut_buf))
  -- -- :tabnew file, undotree, :bd!
  if not api.nvim_buf_is_loaded(buf) then return destroy() end
  -- only create on new buf
  on_text_changed = on_text_changed or new_text_changed(buf)
  local ut_win = assert(vim.b[buf].nvim_undotree)
  local line = api.nvim_win_call(ut_win, api.nvim_get_current_line)
  u.undo.render_diff(buf, u.asinteger(line:match('%d+')))
end)

local hijack = api.nvim_get_autocmds({ group = group0, buffer = ut_buf, event = 'CursorMoved' })[1]
api.nvim_clear_autocmds({ group = group0, buffer = ut_buf, event = 'CursorMoved' })
api.nvim_create_autocmd('CursorMoved', {
  group = group,
  buffer = ut_buf,
  callback = function(ev)
    render_diff()
    vim.schedule(function()
      local buf = u.undo.buf_from_title(api.nvim_buf_get_name(ut_buf))
      if api.nvim_buf_is_loaded(buf) then hijack.callback(ev) end
    end)
  end,
})

api.nvim_create_autocmd('BufEnter', {
  group = group,
  callback = vim.schedule_wrap(function(ev)
    if not api.nvim_buf_is_valid(ut_buf) then return destroy() end
    local buf = u.undo.buf_from_title(api.nvim_buf_get_name(ut_buf))
    if
      ev.buf == ut_buf
      or ev.buf == buf
      or not api.nvim_buf_is_valid(ev.buf)
      or not api.nvim_buf_is_valid(buf)
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

api.nvim_create_autocmd({ 'WinClosed', 'BufWinLeave' }, {
  buffer = ut_buf,
  once = true,
  callback = destroy,
})
