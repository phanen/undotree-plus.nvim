local u = {
  debounce = require('undotree-plus.debounce'),
}
---START INJECT undo.lua

local api, fn, uv = vim.api, vim.fn, vim.uv
local M = {}

local asinteger = tonumber ---@type fun(x: any): integer

---@module 'gitsigns.async'?
local async = vim.F.npcall(require, 'gitsigns.async')

---@param buf integer
---@param n integer
---@return string[]
M.get_context = function(buf, n)
  if n < 0 then return {} end
  local undo = os.tmpname()
  api.nvim_buf_call(buf, function() vim.cmd('noautocmd silent wundo! ' .. undo) end)
  local tmpbuf = api.nvim_create_buf(false, true)
  api.nvim_buf_set_lines(tmpbuf, 0, -1, false, api.nvim_buf_get_lines(buf, 0, -1, false))
  vim._with(
    { buf = tmpbuf, noautocmd = true, go = { eventignore = 'all' } },
    vim.F.nil_wrap(function()
      vim.cmd('noautocmd silent rundo ' .. undo)
      vim.cmd('noautocmd silent undo ' .. n)
    end)
  )
  local result = api.nvim_buf_get_lines(tmpbuf, 0, -1, false)
  api.nvim_buf_delete(tmpbuf, { force = true })
  os.remove(undo)
  return result
end

---@param ctx1 string[]
---@param ctx2 string[]
---@return string[]
M.get_diff = function(ctx1, ctx2)
  local diff = vim.text and vim.text.diff or vim.diff ---@diagnostic disable-line: deprecated
  local result = diff(table.concat(ctx1, '\n') .. '\n', table.concat(ctx2, '\n') .. '\n', {
    ctxlen = 3,
    ignore_cr_at_eol = true,
    ignore_whitespace_change_at_eol = true,
  })
  ---@diagnostic disable-next-line: param-type-mismatch
  return vim.split(result, '\n')
end

M.diff_win = nil ---@type integer
M.diff_buf = nil ---@type integer

---@async
M.get_hunks = function(buf, n)
  local a = M.get_context(buf, n - 1)
  local b = M.get_context(buf, n)
  return require('gitsigns.diff_int').run_diff(a, b, true)
end

local render_gitsigns = function(...)
  async
    .run(function(buf, n)
      local hunks = M.get_hunks(buf, n)
      async.schedule()
      local ff = vim.bo[buf].fileformat
      local hunk_to_linespec = function(h) return require('gitsigns.hunks').linespec_for_hunk(h, ff) end
      local linespec = {}
      for _, hunk in ipairs(hunks) do
        vim.list_extend(linespec, hunk_to_linespec(hunk))
      end
      local opts = vim.deepcopy(require('gitsigns.config').config.preview_config)
      local col = assert(opts.col)
      local curbuf = api.nvim_get_current_buf()
      if true then
        opts.relative = 'tabline'
        opts.col = col + 30
      elseif vim.b[curbuf].nvim_is_undotree then
        opts.col = col + 20
      end
      if
        false
        and M.diff_win
        and M.diff_buf
        and api.nvim_win_is_valid(M.diff_win)
        and api.nvim_buf_is_valid(M.diff_buf)
      then
        require('gitsigns.popup').update(M.diff_win, M.diff_buf, linespec, opts)
        if api.nvim__redraw then api.nvim__redraw({ win = M.diff_win, flush = true }) end
      else
        pcall(api.nvim_win_close, M.diff_win, true)
        M.diff_win = require('gitsigns.popup').create(linespec, opts)
        api.nvim_clear_autocmds({
          event = { 'CursorMoved', 'WinScrolled' },
          group = api.nvim_create_augroup('gitsigns_popup', { clear = false }),
        })
      end
      M.diff_buf = api.nvim_win_get_buf(M.diff_win)
      local config = api.nvim_win_get_config(M.diff_win)
      local max_width, max_height = vim.o.columns - 30 - 2, 10
      api.nvim_win_set_config(
        M.diff_win,
        { width = math.min(config.width, max_width), height = math.min(config.height, max_height) }
      )
      if config.height > max_height then
        local lang = vim.treesitter.language.get_lang(vim.bo[buf].filetype)
        if lang and vim.treesitter.language.add(lang) then
          vim.treesitter.start(M.diff_buf, lang)
        end
      end
    end, ...)
    :raise_on_error()
end

M.render_gitsigns = async and render_gitsigns or nil

---@param buf integer
---@param n integer
local render_diff = function(buf, n)
  ---@diagnostic disable-next-line: incomplete-signature-doc, param-type-mismatch
  if true and async then return M.render_gitsigns(buf, n) end
  local before_ctx = M.get_context(buf, n - 1)
  local cur_ctx = M.get_context(buf, n)
  local diff = M.get_diff(before_ctx, cur_ctx)
  M.diff_buf = M.diff_buf and api.nvim_buf_is_valid(M.diff_buf) and M.diff_buf
    or api.nvim_create_buf(false, true)
  if vim.bo[M.diff_buf].syntax ~= 'diff' then vim.bo[M.diff_buf].syntax = 'diff' end
  api.nvim_buf_set_lines(M.diff_buf, 0, -1, true, diff)
  M.diff_win = M.diff_win and api.nvim_win_is_valid(M.diff_win) and M.diff_win
    or api.nvim_open_win(M.diff_buf, false, {
      row = 0,
      col = 30 + 1, -- undotree width
      height = 8,
      width = 30 * 2,
      style = 'minimal',
      relative = 'tabline',
    })
end

M.render_diff =
  u.debounce.debounce_trailing(150, u.debounce.throttle_by_id(2, vim.schedule_wrap(render_diff)))

M.undotree_title = function(buf) return 'undotree://' .. tostring(buf) end

---@return integer
M.buf_from_title = function(title) return asinteger(title:match('undotree://(%d+)')) end

---@param buf integer
local delete_alt_buf = function(buf)
  local alt = api.nvim_buf_call(buf, function() return fn.bufnr('#') end)
  if alt ~= buf and alt ~= -1 then pcall(api.nvim_buf_delete, alt, { force = true }) end
end

---@param buf? integer
local clear_alt_buf = function(buf)
  buf = buf or vim._resolve_bufnr(buf)
  local tmpbuf = api.nvim_create_buf(false, true)
  api.nvim_buf_call(buf, function() fn.setreg('#', tmpbuf) end)
  api.nvim_buf_delete(tmpbuf, { force = true })
end

---@param buf integer
---@param name string
M.buf_rename = function(buf, name)
  vim._with({ noautocmd = true }, function()
    api.nvim_buf_set_name(buf, name)
    delete_alt_buf(buf)
  end)
end

M.open = function(opts)
  opts = opts or {}
  pcall(vim.cmd.packadd, 'nvim.undotree')
  local create = not opts.buf
  if create then
    vim.cmd('topleft 30vnew')
    clear_alt_buf()
    opts.buf = api.nvim_get_current_buf()
    opts.win = api.nvim_get_current_win()
    vim.cmd.wincmd('w')
  end
  M.buf_rename(opts.buf, M.undotree_title(api.nvim_get_current_buf()))
  require('undotree').open({ title = M.undotree_title, bufnr = opts.buf, winid = opts.win })
  if create then vim.cmd.wincmd('w') end
end

return M
