#!/usr/bin/env lua
-- -------------------------------------------------------------
-- scripts/disk-net-max.lua – Push per‑disk read/write stats into Eww
-- -------------------------------------------------------------

-- ------------------------------------------------------------------
-- Configuration – one entry per disk you want to monitor
-- should match what you put in the eww.yuck file.
-- ------------------------------------------------------------------
local disks = {
   { id = "1", mount = "/"},
   { id = "2", mount = "/backups"},
   { id = "3", mount = "/timeshift"},
}

local INTERVAL = 1.0          -- seconds between updates

-- ------------------------------------------------------------------
-- Auto detect Samples needed for Max value in a graph
-- ------------------------------------------------------------------
local f = io.popen("eww get graph_width")
local value = f:read("*a")
f:close()
SAMPLES = tonumber((value:gsub("%s+", "")) - 1) or 10 

-- ------------------------------------------------------------------
-- Auto‑detect the device name (e.g. sda, nvme0n1…) for each disk
-- ------------------------------------------------------------------
local devices = {}
for _, d in ipairs(disks) do
   local h = io.popen(
      "basename $(df " .. d.mount .. " --output=source | tail -n1 2>/dev/null)"
   )
   if h then
      devices[d.id] = h:read("*a"):gsub("%s+", "")   -- strip newline/space
      h:close()
   end
end

-- ------------------------------------------------------------------
-- History buffers – keep the last N samples for each disk
-- ------------------------------------------------------------------
local prev    = {}
local history = {}

for _, d in ipairs(disks) do
   prev[d.id] = {r=0, w=0}
   history["disk"..d.id.."_read"]  = {}
   history["disk"..d.id.."_write"] = {}
end

-- *** NEW: initialise the network history tables ***
history["net_down"] = {}
history["net_up"]   = {}

-- ------------------------------------------------------------------
-- Helper: read raw /proc/diskstats once
-- ------------------------------------------------------------------
local function get_raw()
   local f = io.open("/proc/diskstats", "r")
   if not f then return {} end
   local content = f:read("*all")
   f:close()

   local res = {}
   for _, d in ipairs(disks) do
      local dev = devices[d.id]
      if dev then
         -- fields 3 (reads), 7 (writes)
         local r, w = content:match(
            dev .. "%s+%d+%s+%d+%s+(%d+)%s+%d+%s+%d+%s+%d+%s+(%d+)"
         )
         res[d.id] = {r = tonumber(r) or 0, w = tonumber(w) or 0}
      end
   end
   return res
end

--  Read once and seed prev before the loop starts --
local current = get_raw()                -- first snapshot
for id, v in pairs(current) do           -- copy it into prev
    prev[id] = v
end

-- ------------------------------------------------------------------
-- Main loop – update Eww every INTERVAL seconds
-- ------------------------------------------------------------------
while true do
   local new_current = get_raw()
   local cmd     = ""

   -- ---- DISKS --------------------------------------------------------
   for _, d in ipairs(disks) do
      local id  = d.id
      local curr = new_current[id]

      if curr then                     -- only process if we actually have data
         local r_bytes = (curr.r - prev[id].r) * 512
         local w_bytes = (curr.w - prev[id].w) * 512

         prev[id] = curr

         table.insert(history["disk"..id.."_read"],  r_bytes)
         table.insert(history["disk"..id.."_write"], w_bytes)

         if #history["disk"..id.."_read"] > SAMPLES then
            table.remove(history["disk"..id.."_read"], 1)
            table.remove(history["disk"..id.."_write"], 1)
         end

         local rmax = 0; for _,v in ipairs(history["disk"..id.."_read"]) do if v>rmax then rmax=v end end
         local wmax = 0; for _,v in ipairs(history["disk"..id.."_write"]) do if v>wmax then wmax=v end end

         -- Publish the four metrics as separate globals:
         cmd = cmd .. string.format(" disk_read_cur_%s=%d", id, r_bytes)
         cmd = cmd .. string.format(" disk_write_cur_%s=%d", id, w_bytes)
         cmd = cmd .. string.format(" disk_read_max_%s=%d",  id, rmax)
         cmd = cmd .. string.format(" disk_write_max_%s=%d", id, wmax)

      else
         -- No data for this disk – just skip it (or set zeros if you prefer)
      end
   end

   -- ---- NETWORK -------------------------------------------------------
   local net_raw  = io.popen("eww get EWW_NET 2>/dev/null"):read("*a") or ""
   local net_down = tonumber(net_raw:match('NET_DOWN":(%d+)')) or 0
   local net_up   = tonumber(net_raw:match('NET_UP":(%d+)'))   or 0

   -- Add to history and compute max (same logic as before)
   table.insert(history["net_down"], net_down)
   table.insert(history["net_up"],   net_up)

   if #history["net_down"] > SAMPLES then
      table.remove(history["net_down"], 1)
      table.remove(history["net_up"],   1)
   end

   local net_down_max = 0; for _,v in ipairs(history["net_down"]) do if v>net_down_max then net_down_max=v end end
   local net_up_max   = 0; for _,v in ipairs(history["net_up"])   do if v>net_up_max   then net_up_max=v end end

   cmd = cmd .. string.format(" net_down_cur=%d net_down_max=%d net_up_cur=%d net_up_max=%d",
                               net_down, net_down_max, net_up, net_up_max)

   -- ---- Run the eww update ------------------------------------------------
   if #cmd > 0 then
      local full_cmd = "eww update" .. string.gsub(cmd, "%s+", " ")
      os.execute(full_cmd)
   end

   os.execute("sleep " .. INTERVAL)
end

