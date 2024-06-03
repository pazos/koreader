-- parse "metadata.calibre" files
local lj = require("lunajson")

local array_fields = {
    authors = true,
    tags = true,
    series = true,
}

local required_fields = {
    authors = true,
    last_modified = true,
    lpath = true,
    series = true,
    series_index = true,
    size = true,
    tags = true,
    title = true,
    uuid = true,
}

local field
local t = {}
local function append(v)
    -- Some fields *may* be arrays, so check whether we ran through startarray first or not
    if t[field] then
        table.insert(t[field], v)
    else
        t[field] = v
        field = nil
    end
end

local depth = 0
local result = {}
local sax = {
    startobject = function()
        depth = depth + 1
    end,
    endobject = function()
        if depth == 1 then
            table.insert(result, t)
            t = {}
        end
        depth = depth - 1
    end,
    startarray = function()
        if array_fields[field] then
            t[field] = {}
        end
    end,
    endarray = function()
        if field then
            field = nil
        end
    end,
    key = function(s)
        if required_fields[s] then
            field = s
        end
    end,
    string = function(s)
        if field then
            append(s)
        end
    end,
    number = function(n)
        if field then
            append(n)
        end
    end,
    boolean = function(b)
        if field then
            append(b)
        end
    end,
}

local parser = {}
function parser.parseFile(file)
    result = {}
    local p = lj.newfileparser(file, sax)
    p.run()
    field = nil
    return result
end

return parser
