--!The Automatic Cross-platform Build Tool
-- 
-- XMake is free software; you can redistribute it and/or modify
-- it under the terms of the GNU Lesser General Public License as published by
-- the Free Software Foundation; either version 2.1 of the License, or
-- (at your option) any later version.
-- 
-- XMake is distributed in the hope that it will be useful,
-- but WITHOUT ANY WARRANTY; without even the implied warranty of
-- MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
-- GNU Lesser General Public License for more details.
-- 
-- You should have received a copy of the GNU Lesser General Public License
-- along with XMake; 
-- If not, see <a href="http://www.gnu.org/licenses/"> http://www.gnu.org/licenses/</a>
-- 
-- Copyright (C) 2009 - 2015, ruki All rights reserved.
--
-- @author      ruki
-- @file        compiler.lua
--

-- define module: compiler
local compiler = compiler or {}

-- load modules
local path      = require("base/path")
local utils     = require("base/utils")
local table     = require("base/table")
local string    = require("base/string")
local config    = require("base/config")
local tools     = require("tools/tools")

-- map gcc flags to the given compiler flags
function compiler._mapflags(module, flags)

    -- check
    assert(module and flags)

    -- need not map flags? return it directly
    if not module.mapflag then
        return flags
    end

    -- map flags
    local flags_mapped = {}
    for _, flag in pairs(flags) do
        -- map it
        local flag_mapped = module.flag_map(flag)
        if flag_mapped then
            table.insert(flags_mapped, flag_mapped)
        end
    end

    -- ok?
    return flag_mapped
end

-- get the compiler name from the source file type
function compiler._name(srcfile)

    -- get the source file type
    local filetype = path.extension(srcfile)
    if not filetype then
        return nil
    end

    -- get the lower file type
    filetype = filetype:lower()

    -- get the compiler name
    local name = nil
    if filetype == ".c" then name = "cc"
    elseif filetype == ".cpp" or filetype == ".cc" then name = "cxx"
    elseif filetype == ".m" then name = "mm"
    elseif filetype == ".mm" then name = "mxx"
    elseif filetype == ".s" or filetype == ".asm" then name = "as"
    end
    
    -- ok
    return name
end
    
-- get the compiler from the given source file
function compiler.get(srcfile)

    -- get the compiler name
    local name = compiler._name(srcfile)
    if not name then
        return 
    end

    -- get compiler from the source file type
    local module = tools.get(name)
    if module then 
        
        -- invalid compiler
        if not module.command_compile then
            return 
        end

        -- save name 
        module._NAME = name 
    end

    -- ok?
    return module
end

-- make the compile command
function compiler.make(module, target, srcfile, objfile)

    -- check
    assert(module and target)

    -- the compiler name
    local name = module._NAME
    assert(name)

    -- the flag names
    local flag_names = nil
    if name == "cc"         then flag_names = { "cxflags", "cflags"      }
    elseif name == "cxx"    then flag_names = { "cxflags", "cxxflags"    }
    elseif name == "mm"     then flag_names = { "mxflags", "mflags"      } 
    elseif name == "mxx"    then flag_names = { "mxflags", "mxxflags"    }
    elseif name == "as"     then flag_names = { "asflags"                }
        -- error
        utils.error("unknown compiler: %s", name)
        return 
    end

    -- get the common flags from the current compiler 
    local flags = {}
    for _, flag_name in ipairs(flag_names) do
        table.join2(flags, module[flag_name])
    end

    -- get the target flags from the current project
    for _, flag_name in ipairs(flag_names) do
        table.join2(flags, compiler._mapflags(module, utils.wrap(target[flag_name])))
    end

    -- get the includedirs flags from the current project
    if module._make_includedir then
        local includedirs = utils.wrap(target.includedirs)
        for _, includedir in ipairs(includedirs) do
            table.join2(flags, module.flag_includedir(includedir))
        end
    end

    -- get the defines flags from the current project
    if module._make_define then
        local defines = utils.wrap(target.defines)
        for _, define in ipairs(defines) do
            table.join2(flags, module.flag_define(define))
        end
    end

    -- get the config flags
    for _, flag_name in ipairs(flag_names) do
        table.join2(flags, compiler._mapflags(module, utils.wrap(config.get(flag_name))))
    end

    -- make the compile command
    return module.command_compile(srcfile, objfile, table.concat(flags, " "):trim())
end

-- return module: compiler
return compiler
