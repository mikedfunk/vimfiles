local api = vim.api
local vcmd = vim.cmd
local helpers = require('fsouza.lib.nvim_helpers')

local M = {}

local debouncers = {}

local clients = {}

-- stores result by bufnr & line (range.start.line)
local code_lenses = {}

local function group_by_line(codelenses)
  local by_line = {}
  for _, codelens in ipairs(codelenses) do
    local line_id = codelens.range.start.line
    local curr = by_line[line_id] or {}
    table.insert(curr, codelens)
    by_line[line_id] = curr
  end
  return by_line
end

local function remove_results(bufnr)
  code_lenses[bufnr] = nil
end

local function render_virtual_text(bufnr)
  local ns = api.nvim_create_namespace('fsouza__code_lens')
  api.nvim_buf_clear_namespace(bufnr, ns, 0, -1)

  local prefix = ' '
  for line, items in pairs(code_lenses[bufnr]) do
    local titles = {}
    for _, item in ipairs(items) do
      table.insert(titles, item.command.title)
    end
    local chunks = {
      {string.format('%s%s', prefix, table.concat(titles, ' | ')); 'LspCodeLensVirtualText'};
    }
    api.nvim_buf_set_virtual_text(bufnr, ns, line, chunks, {})
  end
end

local function codelenses_handler(_, _, codelenses, _, bufnr)
  if not codelenses then
    return
  end

  code_lenses[bufnr] = group_by_line(codelenses)
  render_virtual_text(bufnr)
end

local function codelenses(bufnr)
  if not clients[bufnr] then
    return
  end
  if bufnr == 0 then
    bufnr = api.nvim_get_current_buf()
  end
  local params = {textDocument = {uri = vim.uri_from_bufnr(bufnr)}}
  clients[bufnr].lsp_client.request('textDocument/codeLens', params, codelenses_handler, bufnr)
end

function M.codelens(bufnr)
  local debouncer_key = bufnr
  local debounced = debouncers[debouncer_key]
  if debounced == nil then
    local interval = vim.b.lsp_codelens_debouncing_ms or 50
    debounced = require('fsouza.lib.debounce').debounce(interval, vim.schedule_wrap(codelenses))
    debouncers[debouncer_key] = debounced
    api.nvim_buf_attach(bufnr, false, {
      on_detach = function()
        debounced.stop()
        debouncers[debouncer_key] = nil
      end;
    })
  end
  debounced.call(bufnr)
end

local function execute_codelenses(bufnr, items)
  if vim.tbl_isempty(items) then
    return
  end

  local client = clients[bufnr]
  if not client then
    return
  end

  local function run(codelens)
    client.lsp_client.request('workspace/executeCommand', codelens.command, function(err)
      if not err then
        vcmd([[checktime]])
      end
    end)
  end

  local function execute_item(selected)
    if not client.supports_command then
      return
    end
    if selected.command.command == '' then
      if not client.supports_resolve then
        return
      end

      client.lsp_client.request('codeLens/resolve', selected, function(_, _, result)
        if result then
          run(result)
        end
      end)
    else
      run(selected)
    end
  end

  if #items > 1 then
    local popup_lines = {}
    for _, item in ipairs(items) do
      if item.command then
        table.insert(popup_lines, item.command.title)
      end
    end
    require('fsouza.lib.popup_picker').open(popup_lines, function(index)
      execute_item(items[index])
    end)
  else
    execute_item(items[1])
  end
end

function M.execute()
  local winid = api.nvim_get_current_win()
  local bufnr = api.nvim_win_get_buf(winid)
  local cursor = api.nvim_win_get_cursor(winid)
  local line_id = cursor[1] - 1
  local buffer_results = code_lenses[bufnr]
  if not buffer_results then
    return
  end
  local line_codelenses = buffer_results[line_id]
  if not line_codelenses then
    return
  end
  execute_codelenses(bufnr, line_codelenses)
end

function M.on_attach(opts)
  local bufnr = opts.bufnr
  local client = opts.client
  clients[bufnr] = {
    lsp_client = client;
    supports_resolve = opts.can_resolve;
    supports_command = opts.supports_command;
  }
  vim.schedule(function()
    M.codelens(bufnr)
  end)

  local augroup_id = 'lsp_codelens_' .. bufnr
  helpers.augroup(augroup_id, {
    {
      events = {'InsertLeave'; 'BufWritePost'};
      targets = {string.format('<buffer=%d>', bufnr)};
      command = string.format([[lua require('fsouza.lsp.code_lens').codelens(%d)]], bufnr);
    };
  })

  vim.schedule(function()
    local hook_id = augroup_id
    require('fsouza.lsp.buf_diagnostic').register_hook(hook_id, function()
      M.codelens(bufnr)
    end)
    api.nvim_buf_attach(bufnr, false, {
      on_detach = function()
        helpers.augroup(augroup_id, {})
        require('fsouza.lsp.buf_diagnostic').unregister_hook(hook_id)
        remove_results(bufnr)
        clients[bufnr] = nil
      end;
    })
  end)

  if opts.mapping then
    helpers.create_mappings({
      n = {
        {
          lhs = opts.mapping;
          rhs = helpers.cmd_map([[lua require('fsouza.lsp.code_lens').execute()]]);
          {silent = true};
        };
      };
    }, bufnr)
  end
end

return M
