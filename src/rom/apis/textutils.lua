--[[
    This file is part of CCAPI.
    Copyright (C) 2014  MCPM Team and Contributors

    CCAPI is free software: you can redistribute it and/or modify
    it under the terms of the GNU Lesser General Public License as published by
    the Free Software Foundation, either version 3 of the License, or
    (at your option) any later version.

    CCAPI is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU Lesser General Public License for more details.

    You should have received a copy of the GNU Lesser General Public License
    along with CCAPI.  If not, see <http://www.gnu.org/licenses/>.
  ]]

local serpent
do -- START Serpent
  --[[
  Serpent source is released under the MIT License
  
  Copyright (c) 2011-2013 Paul Kulchenko (paul@kulchenko.com)
  Copyright (c) 2014 MCPM Team and Contributors
  
  Permission is hereby granted, free of charge, to any person obtaining a copy
  of this software and associated documentation files (the "Software"), to deal
  in the Software without restriction, including without limitation the rights
  to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
  copies of the Software, and to permit persons to whom the Software is
  furnished to do so, subject to the following conditions:
  
  The above copyright notice and this permission notice shall be included in
  all copies or substantial portions of the Software.
  
  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
  IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
  FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
  AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
  LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
  OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
  THE SOFTWARE.
  ]]
  local n, v = "serpent", 0.272 -- (C) 2012-13 Paul Kulchenko, 2014 MCPM Team and Contributors; MIT License
  local c, d = "Paul Kulchenko, MCPM Team and Contributors", "Lua serializer and pretty printer"

  local snum = {
    [tostring(1/0)]='1/0 --[[math.huge]]',
    [tostring(-1/0)]='-1/0 --[[-math.huge]]',
    [tostring(0/0)]='0/0'
  }
  local badtype = {
    thread = true,
    userdata = true,
    cdata = true
  }
  local keyword, globals, G = {}, {}, (_G or _ENV)

  for _,k in ipairs({'and', 'break', 'do', 'else', 'elseif', 'end', 'false',
      'for', 'function', 'goto', 'if', 'in', 'local', 'nil', 'not', 'or', 'repeat',
      'return', 'then', 'true', 'until', 'while'}) do
    keyword[k] = true
  end
  for k,v in pairs(G) do
    globals[v] = k
  end -- build func to name mapping
  for _,g in ipairs({'coroutine', 'debug', 'io', 'math', 'string', 'table', 'os'}) do
    for k,v in pairs(G[g] or {}) do
      globals[v] = g..'.'..k
    end
  end

  local function s(t, opts)
    local name, indent, fatal, maxnum = opts.name, opts.indent, opts.fatal, opts.maxnum
    local sparse, custom, huge, selfreturn = opts.sparse, opts.custom, not opts.nohuge, not opts.noreturn
    local space, maxl = (opts.compact and '' or ' '), (opts.maxlevel or math.huge)
    local iname, comm = '_'..(name or ''), opts.comment and (tonumber(opts.comment) or math.huge)
    local seen, sref, syms, symn = {}, {'local '..iname..'={}'}, {}, 0

    local function gensym(val)
      return '_'..(tostring(tostring(val)):gsub("[^%w]",""):gsub("(%d%w+)",
          -- tostring(val) is needed because __tostring may return a non-string value
          function(s)
            if not syms[s] then
              symn = symn+1;
              syms[s] = symn
            end
            return syms[s]
          end))
    end
    local function safestr(s)
      return type(s) == "number" and (huge and snum[tostring(s)] or s)
      or type(s) ~= "string" and tostring(s) -- escape NEWLINE/010 and EOF/026
      or ("%q"):format(s):gsub("\010","n"):gsub("\026","\\026")
    end
    local function comment(s,l)
      return comm and (l or 0) < comm and ' --[['..tostring(s)..']]' or ''
    end
    local function globerr(s,l)
      return globals[s] and globals[s]..comment(s,l) or not fatal
      and safestr(select(2, pcall(tostring, s))) or error("Can't serialize "..tostring(s))
    end
    local function safename(path, name) -- generates foo.bar, foo[3], or foo['b a r']
      local n = name == nil and '' or name
      local plain = type(n) == "string" and n:match("^[%l%u_][%w_]*$") and not keyword[n]
      local safe = plain and n or '['..safestr(n)..']'
      return (path or '')..(plain and path and '.' or '')..safe, safe
    end
    local alphanumsort = type(opts.sortkeys) == 'function' and opts.sortkeys or function(k, o, n) -- k=keys, o=originaltable, n=padding
      local maxn, to = tonumber(n) or 12, {number = 'a', string = 'b'}
      local function padnum(d)
        return ("%0"..maxn.."d"):format(d)
      end
      table.sort(k, function(a,b)
          -- sort numeric keys first: k[key] is not nil for numerical keys
          return (k[a] ~= nil and 0 or to[type(a)] or 'z')..(tostring(a):gsub("%d+",padnum))
          < (k[b] ~= nil and 0 or to[type(b)] or 'z')..(tostring(b):gsub("%d+",padnum))
        end)
    end
    local function val2str(t, name, indent, insref, path, plainindex, level)
      local ttype, level, mt = type(t), (level or 0), getmetatable(t)
      local spath, sname = safename(path, name)
      local tag = plainindex and
      ((type(name) == "number") and '' or name..space..'='..space) or
      (name ~= nil and sname..space..'='..space or '')
      if seen[t] then -- already seen this element
        sref[#sref+1] = spath..space..'='..space..seen[t]
        return tag..'nil'..comment('ref', level)
      end
      if type(mt) == 'table' and (mt.__serialize or mt.__tostring) then -- knows how to serialize itself
        seen[t] = insref or spath
        if mt.__serialize then
          t = mt.__serialize(t)
        else
          t = tostring(t)
        end
        ttype = type(t)
      end -- new value falls through to be serialized
      if ttype == "table" then
        if level >= maxl then
          return tag..'{}'..comment('max', level)
        end
        seen[t] = insref or spath
        if next(t) == nil then
          return tag..'{}'..comment(t, level)
        end -- table empty
        local maxn, o, out = math.min(#t, maxnum or #t), {}, {}
        for key = 1, maxn do
          o[key] = key
        end
        if not maxnum or #o < maxnum then
          local n = #o -- n = n + 1; o[n] is much faster than o[#o+1] on large tables
          for key in pairs(t) do
            if o[key] ~= key then
              n = n + 1;
              o[n] = key
            end
          end
        end
        if maxnum and #o > maxnum then
          o[maxnum+1] = nil
        end
        if opts.sortkeys and #o > maxn then
          alphanumsort(o, t, opts.sortkeys)
        end
        local sparse = sparse and #o > maxn -- disable sparsness if only numeric keys (shorter output)
        for n, key in ipairs(o) do
          local value, ktype, plainindex = t[key], type(key), n <= maxn and not sparse
          if opts.valignore and opts.valignore[value] -- skip ignored values; do nothing
          or opts.keyallow and not opts.keyallow[key]
          or opts.valtypeignore and opts.valtypeignore[type(value)] -- skipping ignored value types
          or sparse and value == nil then -- skipping nils; do nothing
          elseif ktype == 'table' or ktype == 'function' or badtype[ktype] then
            if not seen[key] and not globals[key] then
              sref[#sref+1] = 'placeholder'
              local sname = safename(iname, gensym(key)) -- iname is table for local variables
              sref[#sref] = val2str(key,sname,indent,sname,iname,true)
            end
            sref[#sref+1] = 'placeholder'
            local path = seen[t]..'['..(seen[key] or globals[key] or gensym(key))..']'
            sref[#sref] = path..space..'='..space..(seen[value] or val2str(value,nil,indent,path))
          else
            out[#out+1] = val2str(value,key,indent,insref,seen[t],plainindex,level+1)
          end
        end
        local prefix = string.rep(indent or '', level)
        local head = indent and '{\n'..prefix..indent or '{'
        local body = table.concat(out, ','..(indent and '\n'..prefix..indent or space))
        local tail = indent and "\n"..prefix..'}' or '}'
        return (custom and custom(tag,head,body,tail) or tag..head..body..tail)..comment(t, level)
      elseif badtype[ttype] then
        seen[t] = insref or spath
        return tag..globerr(t, level)
      elseif ttype == 'function' then
        seen[t] = insref or spath
        local ok, res = pcall(string.dump, t)
        local func = ok and ((opts.nocode and "function() --[[..skipped..]] end" or
            "((loadstring or load)("..safestr(res)..",'@serialized'))")..comment(t, level))
        return tag..(func or globerr(t, level))
      else
        return tag..safestr(t)
      end -- handle all other types
    end
    local sepr = indent and "\n" or ";"..space
    local body = val2str(t, name, indent) -- this call also populates sref
    local tail = #sref>1 and table.concat(sref, sepr)..sepr or ''
    local warn = opts.comment and #sref>1 and space.."--[[incomplete output with shared/self-references skipped]]" or ''
    -- self-calling anonymous function :P
    -- AKA CC compat
    return not name and body..warn or ((selfreturn and "return" or "").."(function() local "..body..sepr..tail.."return "..name..sepr.."end)()")
  end

  local function deserialize(data, opts)
    local env = G
    local nocall = false
    if not opts or opts.safe ~= false then
      nocall = true
      env = setmetatable({}, {
          __index = function(t,k)
            return t
          end,
          __call = function(t,...)
            if nocall then
              error("cannot call functions")
            end -- else do nothing
          end
        })
    end
    local f, res = (loadstring or load)('return '..data, nil, nil, env)
    if not f then
      f, res = (loadstring or load)(data, nil, nil, env)
    end
    if not f then
      return f, res
    end
    if setfenv then
      setfenv(f, env)
    end
    local function stuff(...)
      nocall = false
      return ...
    end
    return stuff(pcall(f))
  end

  local function merge(a, b)
    if b then
      for k,v in pairs(b) do
        a[k] = v
      end
    end
    return a;
  end
  -- [[
  serpent = {
    _NAME = n, _COPYRIGHT = c, _DESCRIPTION = d, _VERSION = v, serialize = s,
    load = deserialize,
    dump = function(a, opts) return s(a, merge({name = '_', compact = true, sparse = true}, opts)) end,
    line = function(a, opts) return s(a, merge({sortkeys = true, comment = true}, opts)) end,
    block = function(a, opts) return s(a, merge({indent = '  ', sortkeys = true, comment = true}, opts)) end
  } --]]

end -- END serpent

serialize = function(t)
  return serpent.serialize(t,{
      indent = '  ',
      sortkeys = true,
      comment = true,
      nocode = true,
      name = 't',
      noreturn = true
    })
end

unserialize = function(s)
  return serpent.load(s,{
      safe = true -- to emulate CC behaviour
    })
end

-- http://lua-users.org/wiki/StringRecipes
urlEncode = function(str)
  if (str) then
    str = string.gsub (str, "\n", "\r\n")
    str = string.gsub (str, "([^%w %-%_%.%~])",
      function (c) return string.format ("%%%02X", string.byte(c)) end)
    str = string.gsub (str, " ", "+")
  end
  return str
end