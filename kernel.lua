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

local M, path = ...

if not M then print("Use ccapi") return end

print("Loading CCAPI kernel!")

if M.debug then
  local debugstring = [[
  
    CCAPI Version: ${CC};
    Lua Version: ${LUA};
    -- TODO add more info
    ]]
  print((debugstring:gsub(
        "${(.-)}",
        {
          LUA = _VERSION,
          CC = M.version,
        }
      )))
end