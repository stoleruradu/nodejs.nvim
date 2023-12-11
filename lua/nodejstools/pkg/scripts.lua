local M = {};

local signs_group = 'PackageJsonSigns';
local entries = {};
local config = {
  output_layout = 'vsplit'
}

local dirname = function(str)
  if str:match(".-/.-") then
    local name = string.gsub(str, "(.*/)(.*)", "%1")
    return name
  else
    return ''
  end
end

local buf_json_decode = function(bufnr)
  local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false);
  local file = table.concat(lines);

  local ok, json = pcall(vim.json.decode, file);

  if ok then
    return json;
  end

  return {};
end

local get_scripts = function(bufnr)
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

  local parser = vim.treesitter.get_parser(bufnr, 'json');
  local tree = parser:parse()[1];
  local scripts = setmetatable({}, {
    __index = function(t, k)
      local script = {};

      function script:start(cwd)
        local api = vim.api
        local buf = api.nvim_create_buf(false, true);

        vim.cmd(config.output_layout);

        local win = vim.api.nvim_get_current_win();

        vim.api.nvim_win_set_buf(win, buf);

        local running = true;
        local job_id = vim.fn.termopen({ 'yarn', self.key }, {
          cwd = cwd,
          --on_stderr = send_output,
          on_exit = function()
            running = false;
          end
        });
        --
        -- allows quiting terminal by pressing q
        vim.bo[buf].buflisted = false

        vim.keymap.set('n', 'q', function()
          if not running then
            vim.cmd 'close';
            return;
          end

          vim.ui.select({ 'yes', 'no' }, {
            prompt = 'The execution has not finished yed, sure want to close it?',
            format_item = function(item)
              return item
            end,
          }, function(choice)
            if choice == 'yes' then
                vim.fn.jobstop(job_id);
            else
                return;
            end
          end)
        end, { buffer = buf, silent = true })
      end

      t[k] = script;

      return t[k];
    end
  });

  vim.fn.sign_unplace(signs_group, { buffer = bufnr });

  for id, node in query:iter_captures(tree:root(), bufnr, 0, -1) do
    local name = query.captures[id] -- name of the capture in the query

    if name == 'script.key' then
      local row = node:range() -- range of the capture
      local lnum = row + 1;
      local parent = node:parent();
      local child = node:child(1);

      scripts[parent:id()].key = vim.treesitter.get_node_text(child, bufnr);
      scripts[parent:id()].lnum = lnum;

      vim.fn.sign_place(0, signs_group, 'NpmToolSignStart', bufnr, { lnum = lnum })
    end

    if name == 'script.value' then
      local parent = node:parent();
      local child = node:child(1);

      scripts[parent:id()].value = vim.treesitter.get_node_text(child, bufnr);
    end
  end

  return scripts;
end

local load_entry = function(bufnr)
  local path = vim.api.nvim_buf_get_name(bufnr);

  if entries[path] then
    return entries[path];
  end

  local entry = {};

  function entry:reload()
    self.scripts = get_scripts(self.buf);
  end

  entry.buf = bufnr;
  entry.path = path;
  entry.cwd = dirname(path);
  entry.decoded = buf_json_decode(bufnr);

  if entry.decoded.engines and entry.decoded.engines.yarn then
    entry.runner = 'yarn';
  end

  entry.runner = entry.runner or 'npm';
  entry.scripts = get_scripts(bufnr);

  -- executes a npm script
  vim.keymap.set('n', '<leader>r', function()
    local cords = vim.api.nvim_win_get_cursor(0);
    local row = unpack(cords);

    for _, script in pairs(entry.scripts) do
      if script.lnum == row then
        script:start(entry.cwd);
      end
    end
  end, { silent = true, buffer = entry.buf })

  entries[path] = entry;

  return entry;
end

local attach = function(event)
  local entry = load_entry(event.buf);

  if event.event == 'BufWritePost' then
    entry:reload();
  end
end

local init_ui = function()
  local signs = { Start = ' ', Stop = '■ ', }

  vim.cmd 'highlight NpmToolSignGreen guifg=Green'

  for type, icon in pairs(signs) do
    local hl = 'NpmToolSign' .. type
    vim.fn.sign_define(hl, { text = icon, texthl = 'NpmToolSignGreen', numhl = hl })
  end
end

local init_autocmd = function()
  local function augroup(name)
    return vim.api.nvim_create_augroup('NodeJsTools' .. name, { clear = true })
  end

  vim.api.nvim_create_autocmd({ 'BufWinEnter', 'BufWritePost' }, {
    pattern = 'package.json',
    group = augroup('Scripts'),
    callback = attach,
  });
end

M.setup = function(opts)
  opts = opts or {};

  config.output_layout = opts.output_layout or config.output_layout;

  init_autocmd();
  init_ui();
end

return M;
