function fsouza#lc#LC_attached(enable_autoformat)
	if get(g:, 'LC_enable_mappings', 1) != 0 && get(b:, 'LC_enable_mappings', 1) != 0
		nmap <silent> <buffer> <localleader>gd <cmd>lua vim.lsp.buf.definition()<CR>
		nmap <silent> <buffer> <localleader>gy <cmd>lua vim.lsp.buf.declaration()<CR>
		nmap <silent> <buffer> <localleader>gi <cmd>lua vim.lsp.buf.implementation()<CR>
		nmap <silent> <buffer> <localleader>r <cmd>lua vim.lsp.buf.rename()<CR>
		nmap <silent> <buffer> <localleader>i <cmd>lua vim.lsp.buf.hover()<CR>
		nmap <silent> <buffer> <localleader>s <cmd>lua vim.lsp.buf.document_highlight()<CR>
		nmap <silent> <buffer> <localleader>T <cmd>lua vim.lsp.buf.workspace_symbol()<CR>
		nmap <silent> <buffer> <localleader>t <cmd>lua vim.lsp.buf.document_symbol()<CR>
		nmap <silent> <buffer> <localleader>q <cmd>lua vim.lsp.buf.references()<CR>
		nmap <silent> <buffer> <localleader>cc <cmd>lua vim.lsp.buf.code_action()<CR>
		nmap <silent> <buffer> <localleader>d <cmd>lua require('lc').show_line_diagnostics()<CR>
		nmap <silent> <buffer> <localleader>f <cmd>lua vim.lsp.buf.formatting()<CR>
		nmap <silent> <buffer> <c-k> <cmd>lua vim.lsp.buf.signature_help()<CR>
		imap <silent> <buffer> <c-k> <cmd>lua vim.lsp.buf.signature_help()<CR>

		if a:enable_autoformat
			autocmd BufWritePre <buffer> call s:lc_autoformat()
		end
	endif
endfunction

let s:actions = {
			\ 'ctrl-t': 'tabedit',
			\ 'ctrl-x': 'split',
			\ 'ctrl-v': 'vsplit',
			\ }

function s:handle_lsp_line(lines)
	if len(a:lines) < 2
		return
	endif

	let match = matchlist(a:lines[1], '\v^([^:]+):(\d+):(\d+)')[1:3]
	if empty(match) || empty(match[0])
		return
	endif

	let filename = match[0]
	let lnum = match[1]
	let cnum = match[2]
	let action = get(s:actions, a:lines[0], 'edit')

	execute action filename
	call cursor(lnum, cnum)
	normal! zz
endfunction

function fsouza#lc#Fzf(items)
	call fzf#run(fzf#wrap(fzf#vim#with_preview({
				\ 'source': a:items,
				\ 'sink*': function('s:handle_lsp_line'),
				\ 'options': '--expect=ctrl-t,ctrl-x,ctrl-v',
				\ })))
endfunction

function s:lc_autoformat()
	if get(g:, 'LC_autoformat', 1) != 0 && get(b:, 'LC_autoformat', 1) != 0
		lua require('lc').formatting_sync({timeout_ms=500})
	endif
endfunction
