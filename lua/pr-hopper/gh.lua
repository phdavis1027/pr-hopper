local M = {}

local QUERY = [[
query($owner: String!, $name: String!, $pr_number: Int!, $cursor: String) {
  repository(owner: $owner, name: $name) {
    pullRequest(number: $pr_number) {
      reviewThreads(first: 100, after: $cursor) {
        pageInfo { endCursor hasNextPage }
        edges {
          node {
            id
            isResolved
            isOutdated
            line
            originalLine
            originalStartLine
            startLine
            path
            diffSide
            comments(first: 100) {
              edges {
                node {
                  author { login }
                  body
                  createdAt
                  url
                }
              }
            }
          }
        }
      }
    }
  }
}
]]

local function get_repo_info()
    local result = vim.system(
        { 'gh', 'repo', 'view', '--json', 'owner,name' },
        { text = true }
    ):wait()
    if result.code ~= 0 then
        return nil, nil
    end
    local data = vim.json.decode(result.stdout)
    return data.owner.login, data.name
end

local function run_query(owner, name, pr_number, cursor, callback)
    local args = {
        'gh', 'api', 'graphql',
        '-F', 'owner=' .. owner,
        '-F', 'name=' .. name,
        '-F', 'pr_number=' .. pr_number,
        '-f', 'query=' .. QUERY,
    }
    if cursor then
        table.insert(args, '-F')
        table.insert(args, 'cursor=' .. cursor)
    end
    return vim.system(args, { text = true }, callback)
end

local function parse_threads(data)
    local threads = {}
    local edges = data.data.repository.pullRequest.reviewThreads.edges
    for _, edge in ipairs(edges) do
        local node = edge.node
        local comments = {}
        for _, c_edge in ipairs(node.comments.edges) do
            local c = c_edge.node
            table.insert(comments, {
                author = c.author and c.author.login or 'unknown',
                body = c.body,
                created_at = c.createdAt,
                url = c.url,
            })
        end

        local line = node.line
        if line == vim.NIL or line == nil then
            line = node.originalLine
        end
        if line == vim.NIL then
            line = nil
        end

        table.insert(threads, {
            id = node.id,
            is_resolved = node.isResolved,
            is_outdated = node.isOutdated,
            line = line,
            start_line = (node.startLine ~= vim.NIL and node.startLine) or nil,
            original_line = (node.originalLine ~= vim.NIL and node.originalLine) or nil,
            path = node.path,
            diff_side = node.diffSide,
            comments = comments,
        })
    end
    return threads
end

function M.fetch_threads(pr_number, callback)
    local owner, name = get_repo_info()
    if not owner then
        vim.notify('pr-hopper: could not determine repo owner/name', vim.log.levels.ERROR)
        return
    end

    local all_threads = {}

    local function paginate(cursor)
        run_query(owner, name, pr_number, cursor, vim.schedule_wrap(function(result)
            if result.code ~= 0 then
                vim.notify('pr-hopper: GraphQL query failed: ' .. (result.stderr or ''), vim.log.levels.ERROR)
                return
            end

            local ok, data = pcall(vim.json.decode, result.stdout)
            if not ok then
                vim.notify('pr-hopper: failed to parse JSON', vim.log.levels.ERROR)
                return
            end

            if data.errors then
                vim.notify('pr-hopper: ' .. data.errors[1].message, vim.log.levels.ERROR)
                return
            end

            local threads = parse_threads(data)
            for _, t in ipairs(threads) do
                table.insert(all_threads, t)
            end

            local page_info = data.data.repository.pullRequest.reviewThreads.pageInfo
            if page_info.hasNextPage then
                paginate(page_info.endCursor)
            else
                callback(all_threads)
            end
        end))
    end

    paginate(nil)
end

return M
