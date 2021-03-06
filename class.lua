--[[
Copyright (c) 2010-2013 Matthias Richter

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in
all copies or substantial portions of the Software.

Except as contained in this notice, the name(s) of the above copyright holders
shall not be used in advertising or otherwise to promote the sale, use or
other dealings in this Software without prior written authorization.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
THE SOFTWARE.
]]--

local uuid = require "hump.uuid"

-- Must always be the same for serialization/deserialization to work
-- Don't alter math.randomseed before you created all your classes
uuid.randomseed(1)

local function include_helper(to, from, seen)
	if from == nil then
		return to
	elseif type(from) ~= 'table' then
		return from
	elseif seen[from] then
		return seen[from]
	end

	seen[from] = to
	for k,v in pairs(from) do
		k = include_helper({}, k, seen) -- keys might also be tables
		if to[k] == nil then
			to[k] = include_helper({}, v, seen)
		end
	end
	return to
end

-- deeply copies `other' into `class'. keys in `other' that are already
-- defined in `class' are omitted
local function include(class, other)
	return include_helper(class, other, {})
end

-- returns a deep copy of `other'
local function clone(other)
	return setmetatable(include({}, other), getmetatable(other))
end

local function new(class)
	-- mixins
	class = class or {}  -- class can be nil
	local inc = class.__includes or {}
	if getmetatable(inc) then inc = {inc} end

	for _, other in ipairs(inc) do
		if type(other) == "string" then
			other = _G[other]
		end
		include(class, other)
	end

	-- class implementation
    class.__uuid      = uuid()
	class.__index     = class
	class.init        = class.init    or class[1] or function() end
	class.include     = class.include or include
	class.clone       = class.clone   or clone
    class.__serialize = function(value)
        value.__deserialize = function(instance)
            -- Used global class if already defined to enable __index comparisons
            -- and avoid multiple definition of the same class in memory
            -- For this to work, the seed must not be altered before all the classes
            -- have been created
            instance.__class = _G.__classes[instance.__class.__uuid] or instance.__class

            setmetatable(instance, instance.__class)

            -- Can be called once
            instance.__deserialize = nil
            instance.__class = nil
        end

        -- Copy class from metatable for serialization
        -- TODO after the serialization, we're left with thoses __class
        value.__class = value.__index

        return value
    end

    -- Register class in class registry
    _G.__classes = _G.__classes or {}
    _G.__classes[class.__uuid] = class

	-- constructor call
	return setmetatable(class, {__call = function(c, ...)
		local o = setmetatable({}, c)
		o:init(...)

		o.uuid = uuid()

		return o
	end})
end

local function deserialize(instance, deserialized)
    assert(type(instance) == "table", "deserialize first parameter must be a table")

    deserialized = deserialized or {}

    if instance.uuid then
        deserialized[instance.uuid] = instance
    end

    if instance.__deserialize then
        instance:__deserialize()
    end

    for k, v in pairs(instance) do
        local v = instance[k]

        if type(v) == "table" then
            if v.__deserialize then
                v:__deserialize()
            end

            if not v.uuid or not deserialized[v.uuid] then
                deserialize(v, deserialized)
            end
        end
    end

    return instance
end

local function instanceOf(a, b)
    if a then

        if #a == 0 then
            if a.__index ~= b.__index then
                return instanceOf(a.__index.__includes, b)
            end

            return true
        else
            for i = 1, #a do
                local inc = a[i]

                if inc.__index == b.__index or instanceOf(inc.__index.__includes, b) then
                    return true
                end
            end
        end
    end

    return false
end

local function assign(object, options)
    options = options or {}
    for k, v in pairs(options) do
        object[k] = v
    end
end

local function shallowCopy(orig)
    local orig_type = type(orig)
    local copy
    if orig_type == 'table' then
        copy = {}
        for orig_key, orig_value in pairs(orig) do
            copy[orig_key] = orig_value
        end
    else -- number, string, boolean, etc
        copy = orig
    end
    return copy
end

-- interface for cross class-system compatibility (see https://github.com/bartbes/Class-Commons).
if class_commons ~= false and not common then
	common = {}
	function common.class(name, prototype, parent)
		return new{__includes = {prototype, parent}}
	end
	function common.instance(class, ...)
		return class(...)
	end
end


-- the module
return setmetatable({
        new         = new,
        include     = include,
        clone       = clone,
        instanceOf  = instanceOf,
        assign      = assign,
        shallowCopy = shallowCopy,
        deserialize = deserialize
    },
	{
        __call = function(_,...)
            return new(...)
        end
    }
)
