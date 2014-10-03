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

local M = {
  util={},
  version="CraftOS 1.63"
}

if ccapi_DebugKernel then
  print("cleaning up ccapi_DebugKernel - debug mode enabled")
  ccapi_DebugKernel = nil
  M.debug = true
end

local simplecopy
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
  simplecopy = function(inp, copies)
    local out, todo = {}, {}
    copies = copies or {}
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

-- Prepare a _G clone
M.prepareEnv = function(ccEnv, eventQueue)
  local select,type,error = select,type,error
  local setfenv,getfenv = setfenv,getfenv
  local cyield = coroutine.yield

  local luapath = package.path
  local dirsep = package.config:match("^([^\n]*)") -- 1st line
  local pathsep = package.config:match("^[^\n]*\n([^\n]*)") -- 2nd line

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

  ccEnv.getfenv = function(f)
    if getfenv(f) == getfenv(0) then
      return ccEnv
    elseif type(f) == "number" then
      return getfenv(f+1)
    else
      return getfenv(f)
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

  for x in luapath:gmatch("([^" .. pathsep .. "]+)") do
    local path = x
    path = path:gsub("?","ccapi"):gsub("ccapi.lua","kernel.lua")
    local f,e = loadfile(path)
    if M.debug then
      print(f,e)
    end
    if f then
      local s,e = pcall(f, M, path)
      if M.debug then
        print(s,e)
      end
      if s then
        break
      end
    end
  end

  setfenv(1,getfenv(0))
  return ccEnv, eventQueue
end

local ccEnv,eventQueue = simplecopy(_G),{}
M.prepareEnv(ccEnv, eventQueue)

function M.runCC(func, env, eventQueue, id)
  if env then
    setfenv(func, env)
    env, eventQueue = M.prepareEnv(env or simplecopy(_G), eventQueue or {})
  end
  if not eventQueue then eventQueue = {} end
  -- main loop
  while true do

  end
end

return M
