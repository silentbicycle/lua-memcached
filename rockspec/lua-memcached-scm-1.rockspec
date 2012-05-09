package = "lua-memcached"
version = "scm-1"
source = {
   url = "git://github.com/silentbycicle/lua-memcached.git",
   branch = "master"
}
description = {
   summary = "A Lua client for memcached, with optional non-blocking mode",
   homepage = "http://github.com/silentbycicle/lua-memcached",
   license = "MIT/X11"
}
dependencies = {
   "lua >= 5.1",
   "luasocket >= 2.0"
}
build = {
   type = "builtin",
   modules = {
      memcached = "memcached.lua"
   }
}
