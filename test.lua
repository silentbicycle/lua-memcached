require "memcached"
require "socket"
require "lunatest"

pcall(require, "luacov")

local test_async = true

local def_ct = 0
if test_async then
   dh = function()
           def_ct = def_ct + 1
        end
end

function setup()
   m = assert(memcached.connect("localhost", 11211, dh),
              "Is the server running?")
   assert_true(m:flush_all(), "Flush failed")
end


function teardown()
   m:quit()
   if m:is_async() then
      --print(string.format("-- Deferred %d times", def_ct))
   end
   def_ct = 0
end


function test_version()
   assert_match("^VERSION", m:version())
end


function test_get_unavailable()
   local v = m:get("foo")
   assert_nil(v, "Shouldn't be defined yet")
end


function test_set()
   local ok, res = m:set("foo", "bar")
   assert_true(ok, res)
   assert_true(res == "STORED")
end


function test_set_get()
   local ok, res = m:set("foo", "bar")
   assert_true(ok, res)
   local val = m:get("foo")
   assert_true(val == "bar")
end


function test_set_get_multi()
   assert_true(m:set("foo", "bar"))
   assert_true(m:set("bar", "baz"))

   local val = m:get {"foo", "bar" }
   assert_true(val.foo)
   assert_true(val.bar)
   assert_true(val.foo.data == "bar")
   assert_true(val.bar.data == "baz")
end


function test_set_gets_multi_flags()
   assert_true(m:set("foo", "bar", nil, 31))
   assert_true(m:set("bar", "baz", nil, 87))

   local val = m:gets {"foo", "bar" }
   assert_true(val.foo)
   assert_true(val.foo.data == "bar")
   assert_true(val.foo.flags == 31)
   assert_true(val.foo.cas)

   assert_true(val.bar)
   assert_true(val.bar.data == "baz")
   assert_true(val.bar.flags == 87)
   assert_true(val.bar.cas)
end


function test_set_get_large()
   local big = ("a"):rep(500 * 1024)    -- 500kb of 'a's.
   local ok, err = m:set("foo", big)
   local v, err = m:get("foo")
   assert_true(big == m:get("foo"), err)
end


function test_set_gets()
   local ok, res = m:set("foo", "bar")
   assert_true(ok, res)
   local v, flags, cas = m:gets("foo")
   assert_true(v == "bar", v)
end


function test_set_get_flag()
   local ok, res = m:set("foo", "bar", nil, 41)
   assert_true(ok, res)
   local v, flag = m:get("foo")
   assert_true(v == "bar", v)
   assert_true(flag == 41, flag)
end


local function sleep(secs)
   if dh then
      local now = socket.gettime
      local t = now()
      while now() - t < 2 do dh() end
   else
      socket.select(nil, nil, 2)
   end
end


function test_set_get_expire()
   local ok, res = m:set("foo", "bar", 1)
   assert_true(ok, res)
   local v, flag = m:get("foo")
   assert_true(v == "bar")

   print "\nSleeping for two seconds (key should expire)"
   sleep(2)

   local v, flag = m:get("foo")
   assert_nil(v, "Should have expired")
end


function test_stats()
   local stats = m:stats()
   assert_true(stats, stats)
   assert_true(stats.version, "No version field in stats table.")
   --for k,v in pairs(stats) do print(k,v) end
end


function test_incr()
   assert_true(m:set("foo", 10))
   assert_equal("10", (m:get("foo")))
   assert_equal(51, m:incr("foo", 41))
   assert_equal("51", m:get("foo"))
end


function test_incr_decr()
   assert_true(m:set("foo", 10))
   assert_equal(110, m:incr("foo", 100))
   assert_true(m:incr("foo", 15, true))
   assert_equal(112, m:decr("foo", 13))
   local res, err = m:get("foo")
   assert_equal(112, tonumber(res))
end


function test_add()
   local ok, res = m:add("foo", "bar")
   assert_true(ok, res)
   assert_equal("bar", m:get("foo"))
   ok, res = m:add("foo", "blah")
   assert_false(ok)
   assert_equal("NOT_STORED", res)
end


function test_replace()
   local ok, res = m:add("foo", "bar")
   assert_true(ok, res)
   assert_equal("bar", m:get("foo"))

   ok, res = m:replace("bar", "blah")
   assert_false(ok)
   assert_equal("NOT_STORED", res)

   ok, res = m:replace("foo", "blah")
   assert_true(ok)
   assert_equal("blah", m:get("foo"))
end


function test_append()
   local ok, res = m:add("foo", "bar")
   assert_true(ok, res)
   assert_equal("bar", m:get("foo"))

   ok, res = m:append("foo", "baz")
   assert_equal("barbaz", m:get("foo"))
end


function test_prepend()
   local ok, res = m:add("foo", "bar")
   assert_true(ok, res)
   assert_equal("bar", m:get("foo"))

   ok, res = m:prepend("foo", "foo")
   assert_equal("foobar", m:get("foo"))
end


function test_cas()
   local ok, res = m:add("foo", "bar")
   local val, flags, cas = m:gets("foo")

   ok, res = m:cas("foo", "blaff", cas)
   assert_true(ok, res)
   assert_equal("STORED", res)
end


function test_cas_altered()
   local ok, res = m:add("foo", "bar")
   local val, flags, cas = m:gets("foo")

   --change it since last CAS id
   m:replace("foo", "mutation")

   ok, res = m:cas("foo", "blaff", cas)
   assert_false(ok)
   assert_match("EXISTS", res)
end


function test_delete()
   local ok, res = m:add("foo", "bar")
   assert_equal("bar", m:gets("foo"))

   m:delete("foo")
   assert_nil(m:get("foo"))
end

lunatest.run(true)
