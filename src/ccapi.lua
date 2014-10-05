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

local lfs = require("lfs")

local modname = ...

local M = {
  util={},
  ccversion="CraftOS 1.63",
  version="CCAPI 0.0.0",
}

if ccapi_DebugKernel then
  print("cleaning up ccapi_DebugKernel - debug mode enabled")
  ccapi_DebugKernel = nil
  M.debug = true
end

do
  local type,rawset,next = type,rawset,next
  local function check(obj, todo, copies)
    if copies[obj] ~= nil then
      return copies[obj]
    elseif type(obj) == "table" then
      local t = {}
      todo[obj] = t
      copies[obj] = t
      return t
    end
    return obj
  end
  M.simplecopy = function(inp)
    local out, todo = {}, {}
    local copies = {}
    todo[inp], copies[inp] = out, out

    -- we can't use pairs() here because we modify todo
    while next(todo) do
      local i, o = next(todo)
      todo[i] = nil
      for k, v in next, i do
        rawset(o, check(k, todo, copies), check(v, todo, copies))
      end
    end
    return out
  end
end

do
  local strmatch, strrep = string.match, string.rep
  function M.util.getline(str, lno)
    if lno == 0 then
      return strmatch(str, "^([^\n]*)")
    end
    return strmatch(str, "^" .. strrep("[^\n]*\n", lno) .. "([^\n]*)")
  end
end

-- Prepare basic env
M.prepareEnv = function(ccEnv, eventQueue)
  local select,type,error = select,type,error
  local setfenv,getfenv = setfenv,getfenv
  local cyield = coroutine.yield

  local luapath = package.path
  local pc = {} -- pc = "package config"
  -- ds = "directory separator"
  -- ps = "path separator"
  -- np = "name point"
  -- ed = "executable directory"
  -- im = "ignore mark"
  pc.ds,pc.ps,pc.np,pc.ed,pc.im = package.config:match("^([^\n]*)\n([^\n]*)\n([^\n]*)\n([^\n]*)\n([^\n]*)")


  -- make it so every new function has ccEnv as the env
  setfenv(1,ccEnv)

  -- setup eventQueue
  eventQueue.count = 0
  eventQueue.current = 1
  function eventQueue:push(evt,...)
    local newcount = self.count + 1
    self[newcount] = {n=select('#',...), evt, ...}
    self.count = newcount
  end
  function eventQueue:pop()
    if self.count < self.current then
      return nil
    else
      local current = self.current
      self.current = current + 1
      return self[current]
    end
  end

  if not ccEnv.os then
    ccEnv.os = {}
  end

  ccEnv.os.pullEventRaw = cyield

  ccEnv.os.queueEvent = function(evt,...)
    if evt == nil then error("Expected string") end -- todo test this
    eventQueue:push(evt,...)
  end

  do
    -- No I'm not gonna take 5 parameters like a fucking PEASANT!
    -- TAKE THAT, COMPUTERCRAFT!
    local function parseEvent(evt, ...)
      if evt == "terminate" then
        error("Terminated")
      end
      return evt, ...
    end
    ccEnv.os.pullEvent = function(_evt)
      return parseEvent(cyield(_evt))
    end
  end

  setfenv(1,getfenv(0))

  return ccEnv, eventQueue,function()
    setfenv(1,ccEnv)

    -- TODO properly
    for x in luapath:gmatch("([^" .. pc.ps .. "]+)") do
      local path = x:gsub("%" .. pc.np, (modname:gsub("%.", pc.ds))):gsub("^%./", assert(lfs.currentdir()):gsub("%%","%%%%") .. "/")
      local f,e = io.open(path,"r")
      if f then
        f:close()
        local p1, p2 = path:match("(.*)" .. pc.ds .. "(.*)$")
        path = p1 .. p2:gsub(modname:match("%.?([^%.]*)$"),"kernel")
        local f,e = loadfile(path)
        if f then
          local s,e = pcall(f, M, path)
          if s then
            break
          end
          if M.debug and (e or not s) then
            print(s,e)
          end
        end
        if M.debug and (e or not f) then
          print(f,e)
        end
      end
      if M.debug and (e or not f) then
        print(f,e)
      end
    end

    setfenv(1,getfenv(0))
  end
end

function M.runCC(func, env, eventQueue, id)
  local env, eventQueue, loadkernel = M.prepareEnv(env or M.simplecopy(_G), eventQueue or {})
  -- main loop
  while true do
    -- TODO
  end
end

return M
