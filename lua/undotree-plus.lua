---START INJECT undo.lua

local api, fn = vim.api, vim.fn
local M = {}

---@param buf integer
---@param n integer
---@return string[]
function M.get_context(buf, n)
  if n < 0 then return {} end

  local result = {}
  local tmp_file = fn.stdpath('cache') .. '/atone-undo'
  local tmp_undo = tmp_file .. '.undo'
  local tmpbuf = fn.bufadd(tmp_file)
  vim.bo[tmpbuf].swapfile = false
  fn.writefile(api.nvim_buf_get_lines(buf, 0, -1, false), tmp_file)
  fn.bufload(tmpbuf)
  api.nvim_buf_call(buf, function() vim.cmd('silent wundo! ' .. tmp_undo) end)
  vim._with(
    { buf = tmpbuf, noautocmd = true, go = { eventignore = 'all' } },
    vim.F.nil_wrap(function()
      vim.cmd('noautocmd silent rundo ' .. tmp_undo)
      vim.cmd('noautocmd silent undo ' .. n)
      result = api.nvim_buf_get_lines(tmpbuf, 0, -1, false)
    end)
  )
  api.nvim_buf_delete(tmpbuf, { force = true })
  return result
end

---@param ctx1 string[]
---@param ctx2 string[]
---@return string[]
function M.get_diff(ctx1, ctx2)
  ---@diagnostic disable-next-line: deprecated
  local diff = vim.text.diff or vim.diff
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

M.render_gitsigns = pcall(require, 'gitsigns')
    and require('gitsigns.async').create(3, function(buf, a, b)
      local hunks = require('gitsigns.diff_int').run_diff(a, b, true)
      require('gitsigns.async').schedule()
      local ff = vim.bo[buf].fileformat
      local hunk_to_linespec = function(h) return require('gitsigns.hunks').linespec_for_hunk(h, ff) end
      local linespec = {}
      for _, hunk in ipairs(hunks) do
        vim.list_extend(linespec, hunk_to_linespec(hunk))
      end
      local opts = vim.deepcopy(require('gitsigns.config').config.preview_config)
      local curbuf = api.nvim_get_current_buf()
      if true then
        opts.relative = 'tabline'
        opts.col = opts.col + 30
      elseif vim.b[curbuf].nvim_is_undotree then
        opts.col = opts.col + 20
      end
      pcall(api.nvim_win_close, M.diff_win, true)
      M.diff_win = require('gitsigns.popup').create(linespec, opts, 'hunk')
      if api.nvim_win_get_config(M.diff_win).height > 10 then
        api.nvim_win_set_config(M.diff_win, 10)
      end
    end)
  or nil

---@param buf integer
---@param n integer
function M.render_diff(buf, n)
  local before_ctx = M.get_context(buf, n - 1)
  local cur_ctx = M.get_context(buf, n)
  ---@diagnostic disable-next-line: incomplete-signature-doc, param-type-mismatch
  if true and M.render_gitsigns then return M.render_gitsigns(buf, before_ctx, cur_ctx) end
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

M.undotree_title = function(buf) return 'undotree://' .. tostring(buf) end

M.buf_from_title = function(title) return tonumber(title:match('undotree://(%d+)')) end

function M.open(opts)
  opts = opts or {}
  pcall(vim.cmd.packadd, 'nvim.undotree')
  require('undotree').open({
    command = 'topleft 30vnew',
    title = M.undotree_title,
    bufnr = opts.buf,
    winid = opts.win,
  })
end

return M
