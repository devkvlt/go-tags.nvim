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

local M = {}

function M.go_tags(...)
  if not pcall(require, 'nvim-treesitter') then
    vim.notify('go-tags.nvim requires the nvim-treesitter plugin. Please install it.', vim.log.levels.ERROR)
    return
  end

  if vim.fn.executable('gomodifytags') ~= 1 then
    vim.notify(
      'go-tags.nvim requires the gomodifytags executable. Please install it by running `go install github.com/fatih/gomodifytags@latest` and make sure it is in your PATH.',
      vim.log.levels.ERROR
    )
    return
  end

  local node = require('nvim-treesitter.ts_utils').get_node_at_cursor()
  if node == nil then
    return
  end

  while node ~= nil and node:type() ~= 'type_spec' do
    node = node:parent()
  end
  if node == nil then
    return
  end

  local range = node:start() + 1 .. ',' .. node:end_() + 1

  local result = vim
    .system(
      { 'gomodifytags', '-file', vim.fn.expand('%'), '-line', range, '-format', 'json', '-modified', ... },
      { text = true, stdin = archive() }
    )
    :wait()

  -- TODO: Handle errors.
  local decoded = vim.json.decode(result.stdout)

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
