local M = {};

local function augroup(name)
  return vim.api.nvim_create_augroup('NpmTool' .. name, { clear = true })
end

M.setup = function()
  local signs = { Start = ' ', Stop = '■ ', }

  vim.cmd 'highlight NpmToolSignGreen guifg=Green'

  for type, icon in pairs(signs) do
    local hl = 'NpmToolSign' .. type
    vim.fn.sign_define(hl, { text = icon, texthl = 'NpmToolSignGreen', numhl = hl })
  end

  vim.api.nvim_create_autocmd({ 'BufWinEnter', 'BufWritePost' }, {
    pattern = 'package.json',
    group = augroup('Runner'),
    callback = function(event)
      local query = vim.treesitter.query.parse('json', [[
        (object
          (pair
            (string
              (string_content) @key (#eq? @key "scripts")
            )
            (object
              (pair
                key: (string) @script.key
                value: (string) @script.value
              ) @scripts.pair
            ) @scripts.object
          )
        )
      ]]);

      vim.fn.sign_unplace('NpmToolSigns');

      local namespace = 'NpmToolSigns';

      local parser = vim.treesitter.get_parser(event.buf, 'json');
      local tree = parser:parse()[1];

      local storage = {};

      for id, node in query:iter_captures(tree:root(), event.buf, 0, -1) do
        local name = query.captures[id] -- name of the capture in the query

        if name == 'script.key' then
          local lnum = node:range() -- range of the capture
          local parent = node:parent();
          local child = node:child(1);

          storage[parent:id()] = storage[parent:id()] or {};
          storage[parent:id()].key = vim.treesitter.get_node_text(child, event.buf);
          storage[parent:id()].lnum = lnum;

          vim.schedule(function()
            vim.fn.sign_place(0, namespace, 'NpmToolSignStart', event.buf, { lnum = lnum + 1 })
          end);
        end

        if name == 'script.value' then
          local parent = node:parent();
          local child = node:child(1);

          storage[parent:id()] = storage[parent:id()] or {};
          storage[parent:id()].value = vim.treesitter.get_node_text(child, event.buf);
        end
      end
    end
  });
end

M.setup();

return M;
