local M = {}

function M.build(threads, include_resolved)
    local git_root = vim.fn.systemlist('git rev-parse --show-toplevel')[1]
    if vim.v.shell_error ~= 0 or not git_root then
        vim.notify('pr-hopper: not in a git repository', vim.log.levels.ERROR)
        return {}
    end

    local items = {}
    for _, thread in ipairs(threads) do
        if not include_resolved and thread.is_resolved then
            goto continue
        end
        if not thread.path or not thread.line then
            goto continue
        end

        local abs_path = git_root .. '/' .. thread.path
        local first_comment = thread.comments[1]
        if not first_comment then
            goto continue
        end

        local body_preview = first_comment.body:gsub('\r?\n', ' ')
        if #body_preview > 120 then
            body_preview = body_preview:sub(1, 117) .. '...'
        end

        local prefix = ''
        if thread.is_resolved then
            prefix = '[resolved] '
        elseif thread.is_outdated then
            prefix = '[outdated] '
        end

        table.insert(items, {
            filename = abs_path,
            lnum = thread.line,
            col = 1,
            text = string.format('%s@%s: %s', prefix, first_comment.author, body_preview),
            type = thread.is_resolved and 'I' or 'W',
        })

        ::continue::
    end

    table.sort(items, function(a, b)
        if a.filename == b.filename then
            return a.lnum < b.lnum
        end
        return a.filename < b.filename
    end)

    return items
end

function M.set(items, pr_number, include_resolved)
    local label = include_resolved
        and string.format('PR #%d comments (all)', pr_number)
        or string.format('PR #%d comments (unresolved)', pr_number)

    vim.fn.setqflist({}, 'r', { title = label, items = items })

    if #items == 0 then
        local kind = include_resolved and '' or 'unresolved '
        vim.notify(string.format('PR #%d: no %scomments found', pr_number, kind), vim.log.levels.INFO)
    else
        vim.notify(string.format('PR #%d: %d comments loaded', pr_number, #items), vim.log.levels.INFO)
        vim.cmd('copen')
    end
end

return M
