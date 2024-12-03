local configer =  require 'nelua.configer'.get()
local nldecl = require 'nelua.plugins.nldecl'
local fs = require 'nelua.utils.fs'
local executor = require 'nelua.utils.executor'
local console = require 'nelua.utils.console'

debug = false

function mergeTables(table1, table2)
    local result = {}
    table.move(table1, 1, #table1, 1, result)
    table.move(table2, 1, #table2, #result + 1, result)
    return result
end

function extract_calls(source_code, pattern)
    local glfw_functions = {}
    local unique_functions = {}
    for call in source_code:gmatch(pattern) do
        if not unique_functions[call] then
            table.insert(glfw_functions, call)
            unique_functions[call] = true
        end
    end
    return glfw_functions
end

if
   not configer.maximum_performance and
   not configer.release
then
   configer.cc = "tcc"
end

if configer.cc == "tcc" then
   cflags "-D_WIN32_WINNT_VISTA"
   cflags "-DMAPVK_VSC_TO_VK"
   cflags "-DMAPVK_VK_TO_VSC"
   cflags "-D_WIN32_WINNT_WIN7"
   cincdir "glfw/deps"
   cincdir "glfw/deps/mingw"
   cinclude "math.h"
end

-- Compile GLAD
--------------------------------------------------
cinclude "glad/glad.h"
cfile "glad/src/glad.c"
cincdir "glad/include"

-- generate bindings for glad
if not fs.isfile('glad/init.nelua') then
   nldecl.generate_bindings_file{
      include_dirs = { 'glad/include' },
      output_file = 'glad/init.nelua',
      parse_includes = {'glad/glad.h'},
   }
end
--------------------------------------------------

-- Compile GLFW
--------------------------------------------------
cincdir "glfw/src"
cincdir "glfw/include"
cinclude "GLFW/glfw3.h"

local base_sources = {
   "glfw/src/context.c",
   "glfw/src/egl_context.c",
   "glfw/src/init.c",
   "glfw/src/input.c",
   "glfw/src/monitor.c",
   "glfw/src/null_init.c",
   "glfw/src/null_joystick.c",
   "glfw/src/null_monitor.c",
   "glfw/src/null_window.c",
   "glfw/src/osmesa_context.c",
   "glfw/src/platform.c",
   "glfw/src/vulkan.c",
   "glfw/src/window.c",
}

local windows_sources = {
   "glfw/src/wgl_context.c",
   "glfw/src/win32_init.c",
   "glfw/src/win32_joystick.c",
   "glfw/src/win32_module.c",
   "glfw/src/win32_monitor.c",
   "glfw/src/win32_thread.c",
   "glfw/src/win32_time.c",
   "glfw/src/win32_window.c",
}

local sources = mergeTables(base_sources, windows_sources)

if debug then
   local opts = {   
      cfiles = sources,
      incdirs = { "glfw/src", "glfw/include", "math.h", "glfw/deps/mingw", "glfw/deps" },
      cflags = { "-fPIC", "-shared", "-D_GLFW_WIN32", "-D_WIN32_WINNT_VISTA" ,"-DMAPVK_VSC_TO_VK" ,"-DMAPVK_VK_TO_VSC" ,"-D_WIN32_WINNT_WIN7" },
      linklibs = { "gdi32" ,"opengl32" ,"shell32" ,"user32" },
      outdir = fs.join("glfw", "lib", "gcc"),
      outfile = "libglfw3.dll"
   }

   glfw_output = fs.join(opts.outdir, opts.outfile)

   if not fs.isdir(opts.outdir) then fs.makepath(opts.outdir) end
   if not fs.isfile(glfw_output) or configer.no_cache then
      local args = {}
      for _,src in ipairs(sources) do table.insert(args, src) end
      for _,incdir in ipairs(opts.incdirs) do table.insert(args, "-I"..incdir) end
      for _,cflag in ipairs(opts.cflags) do table.insert(args, cflag) end
      for _,linklib in ipairs(opts.linklibs) do table.insert(args, "-l"..linklib) end
      table.insert(args, "-o" .. glfw_output)

      local cmd = ""
      for _, arg in ipairs(args) do cmd = cmd .. " " .. arg end
      console.info("----- Compiling GLFW shared library")
      if configer.verbose then console.info(configer.cc .. cmd) end

      executor.exec(configer.cc, args)
   end
else
   for _, src in ipairs(sources) do
      cfile(src)
   end
   cflags "-D_GLFW_WIN32"
   linklib "gdi32"
   linklib "opengl32"
   linklib "shell32"
   linklib "user32"
end

-- Generate Bindings for GLFW
if not fs.isfile('glfw/init.nelua') then
   nldecl.generate_bindings_file{
      include_dirs = { 'glfw/include' },
      output_file = 'glfw/init.nelua',
      parse_includes = {'GLFW/glfw3.h'},
   }
end
--------------------------------------------------

-- Compiling NanoVG
--------------------------------------------------
cdefine "_CRT_SECURE_NO_WARNINGS"
cdefine "NANOVG_GL3_IMPLEMENTATION"

cfile "nanovg/src/nanovg.c"
cincdir "nanovg/src"
cinclude "nanovg.h"
cinclude "nanovg_gl.h"
cinclude "nanovg_gl_utils.h"

-- if debug then
--    local opts = {   
--       cfiles = { "nanovg/src/nanovg.c" },
--       incdirs = { "nanovg/src" },
--       cflags = { "-fPIC", "-shared", "-D_WIN32_WINNT_VISTA" ,"-DMAPVK_VSC_TO_VK" ,"-DMAPVK_VK_TO_VSC" ,"-D_WIN32_WINNT_WIN7", "-D_CRT_SECURE_NO_WARNINGS", "-DNANOVG_GL3_IMPLEMENTATION", "-DNANOVG_GL3" },
--       linklibs = { "gdi32" ,"opengl32" ,"shell32" ,"user32" },
--       outdir = fs.join("nanovg", "lib", "gcc"),
--       outfile = "libnanovg.dll"
--    }

--    nanovg_output = fs.join(opts.outdir, opts.outfile)

--    if not fs.isdir(opts.outdir) then fs.makepath(opts.outdir) end
--    if not fs.isfile(nanovg_output) or configer.no_cache then
--       local args = {}
--       for _,src in ipairs(opts.cfiles) do table.insert(args, src) end
--       for _,incdir in ipairs(opts.incdirs) do table.insert(args, "-I"..incdir) end
--       for _,cflag in ipairs(opts.cflags) do table.insert(args, cflag) end
--       for _,linklib in ipairs(opts.linklibs) do table.insert(args, "-l"..linklib) end
--       table.insert(args, "-o" .. nanovg_output)

--       local cmd = ""
--       for _, arg in ipairs(args) do cmd = cmd .. " " .. arg end
--       console.info("----- Compiling Nanovg shared library")
--       if configer.verbose then console.info(configer.cc .. cmd) end

--       executor.exec(configer.cc, args)
--    end
-- end

-- Generate Bindings for NanoVG
if not fs.isfile('nanovg/init.nelua') then
   nldecl.generate_bindings_file{
      include_dirs = { 'nanovg/src', 'glad/include' },
      output_file = 'nanovg/init.nelua',
      parse_includes = {'nanovg.h', 'nanovg_gl.h', 'nanovg_gl_utils.h' },
   }
end
--------------------------------------------------
