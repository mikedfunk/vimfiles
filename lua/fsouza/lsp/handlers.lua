local M = {}

local api = vim.api
local lsp = vim.lsp

local function fzf_symbol_callback(_, _, result, _, bufnr)
  if not result or vim.tbl_isempty(result) then
    return
  end

  local items = lsp.util.symbols_to_items(result, bufnr)
  require('fsouza.lsp.fzf').send(items, 'Symbols')
end

local function popup_callback(err, method, result)
  vim.lsp.handlers[method](err, method, result)
  for _, winid in ipairs(api.nvim_list_wins()) do
    if pcall(api.nvim_win_get_var, winid, method) then
      require('fsouza.color').set_popup_winid(winid)
    end
  end
end

M['textDocument/documentSymbol'] = fzf_symbol_callback

M['workspace/symbol'] = fzf_symbol_callback

local function fzf_location_callback(_, _, result)
  if result == nil or vim.tbl_isempty(result) then
    return nil
  end

  if vim.tbl_islist(result) then
    if #result > 1 then
      local items = lsp.util.locations_to_items(result)
      require('fsouza.lsp.fzf').send(items, 'Locations')
    else
      lsp.util.jump_to_location(result[1])
    end
  else
    lsp.util.jump_to_location(result)
  end
end

M['textDocument/declaration'] = fzf_location_callback
M['textDocument/definition'] = fzf_location_callback
M['textDocument/typeDefinition'] = fzf_location_callback
M['textDocument/implementation'] = fzf_location_callback

M['textDocument/references'] = function(_, _, result)
  if not result then
    return
  end
  local items = lsp.util.locations_to_items(result)
  require('fsouza.lsp.fzf').send(items, 'References')
end

M['textDocument/documentHighlight'] = function(_, _, result, _)
  if not result then
    return
  end
  local bufnr = api.nvim_get_current_buf()
  lsp.util.buf_clear_references(bufnr)
  lsp.util.buf_highlight_references(bufnr, result)
end

M['textDocument/codeAction'] = function(_, _, actions)
  if not actions or vim.tbl_isempty(actions) then
    return
  end
  require('fsouza.lsp.code_action').handle_actions(actions)
end

M['textDocument/hover'] = popup_callback

M['textDocument/signatureHelp'] = popup_callback

M['textDocument/publishDiagnostics'] = function(err, method, result, client_id)
  require('fsouza.lsp.buf_diagnostic').publish_diagnostics(err, method, result, client_id)
end

return M
