local M = {}

local helpers = require('lib/nvim_helpers')
local api = vim.api
local lsp = vim.lsp
local fmt_clients = {}

function M.register_client(client, bufnr)
  for _, filetype in pairs(client.config.filetypes) do
    fmt_clients[filetype] = client
  end
  print(vim.inspect(client))

  api.nvim_command([[autocmd BufWritePre <buffer> lua require('lc/formatting').auto_fmt()]])
  api.nvim_buf_set_keymap(bufnr, 'n', '<localleader>f',
                          helpers.cmd_map('lua require("lc/formatting").fmt()'), {silent = true})
end

local formatting_params = function(bufnr)
  local sts = api.nvim_buf_get_option(bufnr, 'softtabstop')
  options = {
    tabSize = (sts > 0 and sts) or (sts < 0 and api.nvim_buf_get_option(bufnr, 'shiftwidth')) or
      api.nvim_buf_get_option(bufnr, 'tabstop');
    insertSpaces = api.nvim_buf_get_option(bufnr, 'expandtab')
  }
  return {textDocument = {uri = vim.uri_from_bufnr(bufnr)}; options = options}
end

local fmt = function(bufnr, cb)
  local client = fmt_clients[vim.bo.filetype]
  if not client then
    error(string.format('cannot format %s files, no lsp client registered', vim.bo.filetype))
  end

  local _, req_id = client.request('textDocument/formatting', formatting_params(bufnr), cb, bufnr)
  return req_id, function()
    client.cancel_request(req_id)
  end
end

function M.fmt()
  fmt(api.nvim_get_current_buf(), nil)
end

function M.fmt_sync(timeout_ms)
  local bufnr = api.nvim_get_current_buf()
  local result
  local err
  local _, cancel = fmt(bufnr, function(err_, _, result_, _)
    result = result_
    err = err_
  end)

  vim.wait(timeout_ms or 200, function()
    return result ~= nil
  end, 10)

  if err then
    error(err)
  end
  if not result then
    cancel()
    return
  end
  lsp.util.apply_text_edits(result, bufnr)
end

function M.auto_fmt()
  local g = vim.g.LC_autoformat
  local b = vim.b.LC_autoformat
  local timeout_ms = vim.b.LC_autoformat_timeout_ms or 500

  if g ~= false and b ~= false then
    M.fmt_sync(timeout_ms)
  end
end

return M