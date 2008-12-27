--
-- Premake 4.x build configuration script
-- 

if (_ACTION == "vs2002" or _ACTION == "vs2003") then
	error(
		"\nBecause of compiler limitations, Visual Studio 2002 and 2003 aren't able to\n" ..
		"build this version of Premake. Use the free Visual Studio Express instead.", 0)
end


--
-- Define the project files.
--

	solution "Premake4"
		configurations { "Release", "Debug" }
	
	project "Premake4"
		targetname  "premake4"
		language    "C"
		kind        "ConsoleApp"
		flags       { "No64BitChecks", "ExtraWarnings", "FatalWarnings" }	
		includedirs { "src/host/lua-5.1.2/src" }

		files 
		{
			"src/**.h", "src/**.c", "src/**.lua", "src/**.tmpl",
			"tests/**.lua"
		}

		excludes
		{
			"src/premake.lua",
			"src/host/lua-5.1.2/src/lua.c",
			"src/host/lua-5.1.2/src/luac.c",
			"src/host/lua-5.1.2/src/print.c",
			"src/host/lua-5.1.2/**.lua",
			"src/host/lua-5.1.2/etc/*.c"
		}
			
		configuration "Debug"
			targetdir   "bin/debug"
			defines     "_DEBUG"
			flags       { "Symbols" }
			
		configuration "Release"
			targetdir   "bin/release"
			defines     "NDEBUG"
			flags       { "OptimizeSize" }

		configuration "vs*"
			defines     { "_CRT_SECURE_NO_WARNINGS" }




--
-- Define a "to" option to control where the files get generated. It is easiest,
-- when I develop, to put the project files in the root project directory. But
-- when deploying I want one directory per supported tool.
--

	newoption {
		trigger = "to",
		value   = "path",
		description = "Set the output location for the generated files"
	}



--
-- "Compile" action compiles scripts to bytecode and embeds into a static
-- data buffer in src/host/bytecode.c.
--

	local function dumpfile(out, fname)
		local func = loadfile(fname)			
		local dump = string.dump(func)
		local len = string.len(dump)
		out:write("\t\"")
		for i=1,len do
			out:write(string.format("\\%03o", string.byte(dump, i)))
		end
		out:write("\",\n")
		return len
	end

	local function dumptmpl(out, fname)
		local f = io.open(fname)
		local tmpl = f:read("*a")
		f:close()

		local name = path.getbasename(fname)
		local dump = "_TEMPLATES."..name.."=premake.loadtemplatestring('"..name.."',[["..tmpl.."]])"
		local len = string.len(dump)
		out:write("\t\"")
		for i=1,len do
			out:write(string.format("\\%03o", string.byte(dump, i)))
		end
		out:write("\",\n")
		return len
	end				
	
	local function docompile()
		local sizes = { }

		scripts, templates, actions = dofile("src/_manifest.lua")
		table.insert(scripts, "_premake_main.lua")
		
		local out = io.open("src/host/bytecode.c", "w+b")
		out:write("/* Precompiled bytecodes for built-in Premake scripts */\n")
		out:write("/* To regenerate this file, run `premake --compile` (Premake 3.x) */\n\n")

		out:write("const char* builtin_bytecode[] = {\n")
		
		for i,fn in ipairs(scripts) do
			print(fn)
			s = dumpfile(out, "src/"..fn)
			table.insert(sizes, s)
		end

		for i,fn in ipairs(templates) do
			print(fn)
			s = dumptmpl(out, "src/"..fn)
			table.insert(sizes, s)
		end
		
		for i,fn in ipairs(actions) do
			print(fn)
			s = dumpfile(out, "src/"..fn)
			table.insert(sizes, s)
		end
		
		out:write("};\n\n");
		out:write("int builtin_sizes[] = {\n")

		for i,v in ipairs(sizes) do
			out:write("\t"..v..",\n")
		end

		out:write("\t0\n};\n");		
		out:close()
	end


	premake.actions["compile"] = {
		description = "Compile scripts to bytecode and embed in bytecode.c",
		execute     = docompile,
	}
