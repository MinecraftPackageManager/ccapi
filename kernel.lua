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