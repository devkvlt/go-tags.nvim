-- https://github.com/fatih/vim-go/blob/feef9b31507f8e942bcd21f9e1f22d587c83c72d/autoload/go/util.vim#L455
local function get_lines()
  local buf = vim.api.nvim_buf_get_lines(0, 0, -1, false)
  if vim.o.encoding ~= 'utf-8' then
    for i, line in ipairs(buf) do
      buf[i] = vim.fn.iconv(line, vim.o.encoding, 'utf-8')
    end
  end
  if vim.bo.fileformat == 'dos' then
    for i, line in ipairs(buf) do
      buf[i] = line .. '\r'
    end
  end
  return buf
end

-- https://github.com/fatih/vim-go/blob/feef9b31507f8e942bcd21f9e1f22d587c83c72d/autoload/go/util.vim#L475
local function archive()
  local lines = get_lines()
  local buffer = table.concat(lines, '\n')
  local file_path = vim.fn.expand('%:p:gs?\\?/?')
  return file_path .. '\n' .. #buffer .. '\n' .. buffer
end

local function notify(msg)
  vim.notify(msg, vim.log.levels.ERROR, { title = 'go-tags.nvim' })
end

local M = {}

function M.go_tags(...)
  if not pcall(require, 'nvim-treesitter') then
    notify('nvim-treesitter not found.')
    return
  end

  if vim.fn.executable('gomodifytags') ~= 1 then
    notify('gomodifytags executable not found.')
    return
  end

  local node = require('nvim-treesitter.ts_utils').get_node_at_cursor()
  if node == nil then
    notify('Failed to get node at cursor.')
    return
  end

  while node ~= nil and node:type() ~= 'type_declaration' do
    node = node:parent()
  end

  if node == nil then
    notify('Failed to retrieve struct node.')
    return
  end

  local range = node:start() + 1 .. ',' .. node:end_() + 1

  local file_path = vim.fn.expand('%:p:gs?\\?/?')
  local result = vim
    .system(
      { 'gomodifytags', '-file', file_path, '-line', range, '-format', 'json', '-modified', ... },
      { text = true, stdin = archive() }
    )
    :wait()

  if result.code ~= 0 then
    notify('gomodifytags failed:\n' .. result.stdout .. result.stderr)
    return
  end

  if result.stdout == '' then
    notify('gomodifytags returned nothing.')
    return
  end

  local decoded = vim.json.decode(result.stdout)

  if not decoded or not decoded.start or not decoded['end'] or not decoded.lines then
    notify('gomodifytags returned a malformed JSON.')
    return
  end

  vim.api.nvim_buf_set_lines(0, decoded.start - 1, decoded['end'], false, decoded.lines)
end

M.setup = function(config)
  for cmd, flags in pairs(config.commands) do
    vim.api.nvim_create_user_command(cmd, function()
      M.go_tags(unpack(flags))
    end, { bang = false })
  end
end

return M
