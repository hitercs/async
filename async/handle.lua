-- c lib / bindings for libuv
local uv = require 'luv'

-- make handle out of uv client
local function handle(client)
   local h = {}
   h.ondata = function(cb)
      client.ondata = function(self,data)
         if cb then cb(data) end
      end
      uv.read_start(client)
   end
   h.onend = function(cb)
      client.onend = function(self)
         if cb then cb() end
      end
   end
   h.onclose = function(cb)
      client.onclose = function(self)
         if cb then cb() end
      end
   end
   h.write = function(data,cb)
      uv.write(client, data, cb)
   end
   h.close = function(cb)
      uv.shutdown(client, function()
         uv.close(client)
         if cb then cb() end
      end)
   end
   -- convenience function to split a stream,
   -- and call a callback each time a full split is found
   h.onsplitdata = function(limit,cb)
      require 'pl' -- TODO: replace this dep, only useful for split()
      local fullpacket = {}
      h.ondata(function(chunk)
         local chunks = stringx.split(chunk,limit)
         for i,chunk in ipairs(chunks) do
            table.insert(fullpacket,chunk)
            if i < #chunks then
               local req = table.concat(fullpacket)
               fullpacket = {}
               cb(req)
            end
         end
      end)
   end
   -- provide a synchronous read:
   h.read = function()
      local data
      local co = coroutine.running()
      if not co then
         print('read() can only be used within a fiber(function() client.read() end) context')
         return nil
      end
      h.ondata(function(d)
         data = d
         coroutine.resume(co)
      end)
      coroutine.yield()
      return data
   end

   return h
end

-- handle
return handle
