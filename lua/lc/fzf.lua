local fun = require('fun')

local M = {}

local vcmd = vim.cmd
local lsp = vim.lsp
local nvim_input = vim.api.nvim_input
local vfn = vim.fn
local helpers = require('lib.nvim_helpers')

local fzf_actions = {['ctrl-t'] = 'tabedit'; ['ctrl-x'] = 'split'; ['ctrl-v'] = 'vsplit'}

local lines_to_qf_list = function(lines)
  return fun.iter(lines):map(function(line)
    local _, _, filename, lnum, col, text = string.find(line, [[([^:]+):(%d+):(%d+):(.*)]])
    return {filename = filename; lnum = lnum; col = col; text = text}
  end):filter(function(item)
    return item.filename
  end):totable()
end

local handle_lsp_lines = function(lines)
  if #lines < 2 then
    return
  end

  local first_line = table.remove(lines, 1)
  local action = fzf_actions[first_line] or 'edit'
  local qf_list = lines_to_qf_list(lines)
  if #qf_list < 1 then
    return
  end

  if #qf_list == 1 then
    local item = qf_list[1]
    vcmd(string.format('%s %s', action, item.filename))
    vfn.cursor(item.lnum, item.col)
    nvim_input('zvzz')
  else
    lsp.util.set_qflist(qf_list)
    vcmd('copen')
    vcmd('wincmd p')
    vcmd('cc')
  end
end

local format_items = function(items)
  local prefix = vfn.getcwd() .. '/'
  return fun.iter(items):map(function(item)
    return string.format('%s:%d:%d:%s',
                         helpers.ensure_path_relative_to_prefix(prefix, item.filename), item.lnum,
                         item.col, item.text)
  end):totable()
end

function M.send(items, prompt)
  require('plugin.fuzzy').ensure_fzf()
  prompt = prompt .. '：'
  local opts = {
    source = format_items(items);
    options = {
      '--expect';
      'ctrl-t,ctrl-x,ctrl-v';
      '--multi';
      '--bind';
      'ctrl-q:select-all';
      '--preview-window';
      '+{2}-5';
      '--delimiter';
      ':';
      '--prompt';
      prompt;
    };
  }
  opts = vfn['fzf#wrap'](vfn['fzf#vim#with_preview'](opts))
  opts['sink*'] = handle_lsp_lines
  vfn['fzf#run'](opts)
end

return M
