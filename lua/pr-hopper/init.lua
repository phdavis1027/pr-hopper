local M = {}

M._config = {
    signs = true,
    virtual_text = true,
    virtual_text_max_len = 80,
    sign_priority = 20,
}

function M.setup(opts)
    M._config = vim.tbl_deep_extend('force', M._config, opts or {})

    vim.api.nvim_create_user_command('PRComments', function(cmd)
        local pr_number = tonumber(cmd.args)
        if not pr_number then
            vim.notify('Usage: PRComments <pr_number>', vim.log.levels.ERROR)
            return
        end
        require('pr-hopper.gh').fetch_threads(pr_number, function(threads)
            vim.schedule(function()
                local items = require('pr-hopper.qflist').build(threads, false)
                require('pr-hopper.qflist').set(items, pr_number, false)
                if M._config.signs or M._config.virtual_text then
                    require('pr-hopper.signs').place(threads, false, M._config)
                end
            end)
        end)
    end, { nargs = 1, desc = 'Load unresolved PR comments into quickfix list' })

    vim.api.nvim_create_user_command('PRCommentsAll', function(cmd)
        local pr_number = tonumber(cmd.args)
        if not pr_number then
            vim.notify('Usage: PRCommentsAll <pr_number>', vim.log.levels.ERROR)
            return
        end
        require('pr-hopper.gh').fetch_threads(pr_number, function(threads)
            vim.schedule(function()
                local items = require('pr-hopper.qflist').build(threads, true)
                require('pr-hopper.qflist').set(items, pr_number, true)
                if M._config.signs or M._config.virtual_text then
                    require('pr-hopper.signs').place(threads, true, M._config)
                end
            end)
        end)
    end, { nargs = 1, desc = 'Load all PR comments into quickfix list (including resolved)' })

    vim.api.nvim_create_user_command('PRCommentsClear', function()
        require('pr-hopper.signs').clear()
        vim.fn.setqflist({}, 'r')
        vim.notify('PR comments cleared', vim.log.levels.INFO)
    end, { desc = 'Clear PR comment signs and quickfix list' })
end

return M
