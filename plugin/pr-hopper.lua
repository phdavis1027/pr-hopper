if vim.g.loaded_pr_hopper then
    return
end
vim.g.loaded_pr_hopper = true

require('pr-hopper').setup()
