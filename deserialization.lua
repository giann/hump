#!/usr/local/bin/lua

package.path = package.path .. ";./lib/?.lua"
Class = require "hump.class"
Serpent = require "hump.serpent"

L = Class{}

function L:lFn()
    print("L specific function", self.uuid)
end

instance = L()

print("Before dump")
for k, v in pairs(instance) do
    print(k, v)
end
print()

ser = loadstring(Serpent.dump(instance))()

print("After loadstring")
for k, v in pairs(instance) do
    print(k, v)
end
print()

Class.deserialize(ser)

print("After deserialize")
for k, v in pairs(ser) do
    print(k, v)
end
print("", "Metatable:")
for k, v in pairs(getmetatable(ser)) do
    print("", k, v)
end
print()

ser:lFn()

print("ser is instance of L", Class.instanceOf(ser, L), getmetatable(ser) == L)