local M = {};

local function get_scripts(pkg_json)
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

  local parser = vim.treesitter.get_parser(pkg_json, 'json');
  local tree = parser:parse()[1];
  local storage = {};

  for id, node in query:iter_captures(tree:root(), pkg_json, 0, -1) do
    local name = query.captures[id] -- name of the capture in the query

    if name == 'script.key' then
      local lnum = node:range() -- range of the capture
      local parent = node:parent();
      local child = node:child(1);

      storage[parent:id()] = storage[parent:id()] or {};
      storage[parent:id()].key = vim.treesitter.get_node_text(child, pkg_json);
      storage[parent:id()].lnum = lnum;
    end

    if name == 'script.value' then
      local parent = node:parent();
      local child = node:child(1);

      storage[parent:id()] = storage[parent:id()] or {};
      storage[parent:id()].value = vim.treesitter.get_node_text(child, pkg_json);
    end
  end

  return storage;
end


local function sign_placeall(group, opts)
  vim.fn.sign_unplace(group, { buffer = opts.buffer });
  for _, script in pairs(get_scripts(opts.buffer)) do
    vim.schedule(function()
      vim.fn.sign_place(0, group, 'NpmToolSignStart', opts.buffer, { lnum = script.lnum + 1 })
    end);
  end
end

function M.setup()
  local signs = { Start = ' ', Stop = '■ ', }
  local signs_group = 'PackageJsonSigns';

  vim.cmd 'highlight NpmToolSignGreen guifg=Green'

  for type, icon in pairs(signs) do
    local hl = 'NpmToolSign' .. type
    vim.fn.sign_define(hl, { text = icon, texthl = 'NpmToolSignGreen', numhl = hl })
  end

  local function augroup(name)
    return vim.api.nvim_create_augroup('NodeJsTools' .. name, { clear = true })
  end

  vim.api.nvim_create_autocmd({ 'BufWinEnter', 'BufWritePost' }, {
    pattern = 'package.json',
    group = augroup('ScriptRunner'),
    callback = function(event)
      sign_placeall(signs_group, { buffer = event.buf });
    end
  });
end

return M;
