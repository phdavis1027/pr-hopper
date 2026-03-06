local M = {}

local ns = vim.api.nvim_create_namespace('pr_hopper')

local sign_defined = false
local function define_signs()
    if sign_defined then return end
    sign_defined = true
    vim.fn.sign_define('PRHopperComment', { text = '', texthl = 'DiagnosticWarn' })
    vim.fn.sign_define('PRHopperResolved', { text = '', texthl = 'DiagnosticOk' })
    vim.fn.sign_define('PRHopperOutdated', { text = '', texthl = 'DiagnosticInfo' })
end

function M.clear()
    for _, buf in ipairs(vim.api.nvim_list_bufs()) do
        if vim.api.nvim_buf_is_valid(buf) then
            vim.api.nvim_buf_clear_namespace(buf, ns, 0, -1)
        end
    end
    vim.fn.sign_unplace('PRHopperGroup')
end

local function place_on_buf(buf, file_threads, config)
    local line_count = vim.api.nvim_buf_line_count(buf)

    for _, thread in ipairs(file_threads) do
        local line = thread.line
        if line > line_count then goto skip end

        if config.signs then
            local sign_name = 'PRHopperComment'
            if thread.is_resolved then
                sign_name = 'PRHopperResolved'
            elseif thread.is_outdated then
                sign_name = 'PRHopperOutdated'
            end
            vim.fn.sign_place(0, 'PRHopperGroup', sign_name, buf, {
                lnum = line,
                priority = config.sign_priority,
            })
        end

        if config.virtual_text then
            local first = thread.comments[1]
            if first then
                local preview = first.body:gsub('\r?\n', ' ')
                local max = config.virtual_text_max_len
                if #preview > max then
                    preview = preview:sub(1, max - 3) .. '...'
                end
                local hl = 'DiagnosticVirtualTextWarn'
                if thread.is_resolved then
                    hl = 'DiagnosticVirtualTextOk'
                elseif thread.is_outdated then
                    hl = 'DiagnosticVirtualTextInfo'
                end
                pcall(vim.api.nvim_buf_set_extmark, buf, ns, line - 1, 0, {
                    virt_text = { { string.format('  %s: %s', first.author, preview), hl } },
                    virt_text_pos = 'eol',
                })
            end
        end

        ::skip::
    end
end

function M.place(threads, include_resolved, config)
    M.clear()
    define_signs()

    local git_root = vim.fn.systemlist('git rev-parse --show-toplevel')[1]
    if vim.v.shell_error ~= 0 or not git_root then return end

    local by_file = {}
    for _, thread in ipairs(threads) do
        if not include_resolved and thread.is_resolved then goto cont end
        if not thread.path or not thread.line then goto cont end
        local abs_path = git_root .. '/' .. thread.path
        if not by_file[abs_path] then
            by_file[abs_path] = {}
        end
        table.insert(by_file[abs_path], thread)
        ::cont::
    end

    for _, buf in ipairs(vim.api.nvim_list_bufs()) do
        if not vim.api.nvim_buf_is_loaded(buf) then goto next_buf end
        local file_threads = by_file[vim.api.nvim_buf_get_name(buf)]
        if file_threads then
            place_on_buf(buf, file_threads, config)
        end
        ::next_buf::
    end

    vim.api.nvim_create_autocmd('BufRead', {
        group = vim.api.nvim_create_augroup('PRHopperBufRead', { clear = true }),
        callback = function(ev)
            local file_threads = by_file[ev.file]
            if not file_threads then return end
            vim.schedule(function()
                place_on_buf(ev.buf, file_threads, config)
            end)
        end,
    })
end

return M
