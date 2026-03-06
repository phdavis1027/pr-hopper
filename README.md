# pr-hopper

Quickfix list + signs companion for [gh.nvim](https://github.com/ldelossa/gh.nvim).

gh.nvim handles PR workflows — opening PRs, viewing diffs, reading/replying/resolving threads. pr-hopper fills two gaps:

1. **Quickfix list integration** — load all PR comments into `:copen` and navigate with `]q`/`[q`
2. **Signs + virtual text in source buffers** — see comments in your actual files, not just gh.nvim's diff splits

Uses `gh api graphql` independently (no coupling to gh.nvim state) to fetch review threads.

## Install

lazy.nvim:

```lua
{
    'phdavis1027/pr-hopper',
    config = function()
        require('pr-hopper').setup({
            signs = true,              -- gutter signs on commented lines
            virtual_text = true,       -- EOL comment preview
            virtual_text_max_len = 80, -- truncate preview after N chars
            sign_priority = 20,
        })
    end,
    cmd = { 'PRComments', 'PRCommentsAll', 'PRCommentsClear' },
}
```

## Requirements

- Neovim 0.9+
- [gh CLI](https://cli.github.com/) authenticated

## Usage

| Command | Description |
|---|---|
| `:PRComments {number}` | Fetch unresolved comments for PR into quickfix list |
| `:PRCommentsAll {number}` | Fetch all comments (including resolved) |
| `:PRCommentsClear` | Clear signs, virtual text, and quickfix list |

```
:PRComments 42       " load unresolved comments from PR #42
]q / [q              " jump between comments
:PRCommentsAll 42    " include resolved comments
:PRCommentsClear     " clean up
```

### Signs

| Sign | Meaning |
|---|---|
| Yellow `` | Unresolved comment |
| Green `` | Resolved comment |
| Blue `` | Outdated comment |
