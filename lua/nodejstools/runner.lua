local M = {};

local store = {};

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
      storage[parent:id()].lnum = lnum + 1;
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

  local scripts = get_scripts(opts.buffer);
  local path = vim.api.nvim_buf_get_name(opts.buffer);

  for _, script in pairs(scripts) do
    vim.fn.sign_place(0, group, 'NpmToolSignStart', opts.buffer, { lnum = script.lnum })
  end

  store[path] = scripts;
end

local scroll_end = function(target_win)
  local buf = vim.api.nvim_win_get_buf(target_win);
  local target_line = vim.tbl_count(vim.api.nvim_buf_get_lines(buf, 0, -1, true))

  vim.api.nvim_win_set_cursor(target_win, { target_line, 0 })
end

local function setup_buff()
  local buf = vim.api.nvim_create_buf(false, false)

  vim.api.nvim_buf_set_option(buf, "buftype", "nofile")
  vim.api.nvim_buf_set_option(buf, "swapfile", false)
  vim.api.nvim_buf_set_option(buf, "buflisted", false)
  vim.api.nvim_buf_set_option(buf, "filetype", "bash")

  return buf;
end

local function run_cmd(script, cwd)
  local out_buf = setup_buff();
  local original_win = vim.api.nvim_get_current_win();

  vim.cmd("split");

  local out_win = vim.api.nvim_get_current_win();

  vim.api.nvim_win_set_buf(out_win, out_buf);
  vim.api.nvim_set_current_win(original_win)

  local cmd = 'yarn ' .. script;

  local exited = false;

  local id = vim.fn.jobstart(cmd, {
    cwd = cwd,
    stdout_buffered = false,
    on_stdout = function(_, data)
      if data then
        vim.api.nvim_buf_set_lines(out_buf, -2, -1, false, data);
        scroll_end(out_win);
      end
    end,
    on_stderr = function(_, data)
      if data then
        vim.api.nvim_buf_set_lines(out_buf, -2, -1, false, data);
        scroll_end(out_win);
      end
    end,
    on_exit = function()
      exited = true;
      vim.api.nvim_buf_set_lines(out_buf, -1, -1, false, { 'Process exited, press ^C to close this window' });
      scroll_end(out_win);
    end
  });

  vim.keymap.set('', '<C-c>', function()
    if exited then
      vim.api.nvim_win_close(0, true);
      return;
    end

    vim.fn.jobstop(id);
  end, { silent = true, buffer = out_buf })
end

local dirname = function(str)
  if str:match(".-/.-") then
    local name = string.gsub(str, "(.*/)(.*)", "%1")
    return name
  else
    return ''
  end
end

local run_script = function()
  local file = vim.api.nvim_buf_get_name(0);
  local scripts = store[file];

  if not scripts then
    return;
  end

  local cwd = dirname(file);

  local cords = vim.api.nvim_win_get_cursor(0);
  local row = unpack(cords);

  for _, script in pairs(scripts) do
    if script.lnum == row then
      run_cmd(script.key, cwd);
    end
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
      vim.keymap.set('n', '<leader>e', function()
        run_script()
      end, { silent = true, buffer = event.buf })

      vim.schedule(function()
        sign_placeall(signs_group, { buffer = event.buf });
      end)
    end
  });

  vim.api.nvim_create_user_command('NodeJsRunScript', function()
    run_script();
  end, {})
end

return M;
