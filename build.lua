local nldecl = require 'nelua.plugins.nldecl'
local fs = require 'nelua.utils.fs'

function mergeTables(table1, table2)
    local result = {}
    table.move(table1, 1, #table1, 1, result)
    table.move(table2, 1, #table2, #result + 1, result)
    return result
end

if ccinfo.is_tcc then
   if ccinfo.is_windows then
      cflags "-D_WIN32_WINNT_VISTA"
      cflags "-DMAPVK_VSC_TO_VK"
      cflags "-DMAPVK_VK_TO_VSC"
      cflags "-D_WIN32_WINNT_WIN7"
   end
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
   nldecl.generate_bindings_file {
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

local linux_sources = {
    "glfw/src/linux_joystick.c",
    "glfw/src/posix_module.c",
    "glfw/src/posix_poll.c",
    "glfw/src/posix_thread.c",
    "glfw/src/posix_time.c",
    "glfw/src/xkb_unicode.c",
}

local linux_x11_sources = {
    "glfw/src/glx_context.c",
    "glfw/src/x11_init.c",
    "glfw/src/x11_monitor.c",
    "glfw/src/x11_window.c",
}

local linux_wl_sources = {
    "glfw/src/wl_init.c",
    "glfw/src/wl_monitor.c",
    "glfw/src/wl_window.c",
}

local sources = base_sources

local use_x11 = false
local use_wl = true

-- Generate Wayland Headers
function generate_wayland_protocol(protocol_file)
   local protocol_path = "glfw/deps/wayland/" .. protocol_file
   local out_dir = "wayland-headers/"
   local header_file = out_dir .. string.gsub(protocol_file, "%.xml$", "-client-protocol.h")
   local code_file = out_dir .. string.gsub(protocol_file, "%.xml$", "-client-protocol-code.h")
   if not fs.isfile(header_file) then
      local client_command = string.format("wayland-scanner client-header \"%s\" \"%s\"",
					   protocol_path,
					   header_file)
      os.execute(client_command)
   end
   if not fs.isfile(code_file) then
      local code_command = string.format("wayland-scanner private-code \"%s\" \"%s\"",
					 protocol_path,
					 code_file)
      os.execute(code_command)
   end
end

if ccinfo.is_linux then
   sources = mergeTables(sources, linux_sources)

   if use_x11 then
      sources = mergeTables(sources, linux_x11_sources)
      cflags "-D_GLFW_X11"
      cincdir "x11-headers"
   end

   if use_wl then
      sources = mergeTables(sources, linux_wl_sources)
      cflags "-D_GLFW_WAYLAND"
      cflags "-Wno-implicit-function-declaration"
      cflags "-Iwayland-headers"
      generate_wayland_protocol("wayland.xml")
      generate_wayland_protocol("viewporter.xml")
      generate_wayland_protocol("xdg-shell.xml")
      generate_wayland_protocol("idle-inhibit-unstable-v1.xml")
      generate_wayland_protocol("pointer-constraints-unstable-v1.xml")
      generate_wayland_protocol("relative-pointer-unstable-v1.xml")
      generate_wayland_protocol("fractional-scale-v1.xml")
      generate_wayland_protocol("xdg-activation-v1.xml")
      generate_wayland_protocol("xdg-decoration-unstable-v1.xml")
   end
end

if ccinfo.is_windows then
   sources = mergeTables(sources, windows_sources)
   cflags "-D_GLFW_WIN32"
   linklib "gdi32"
   linklib "opengl32"
   linklib "shell32"
   linklib "user32"
end

for _, src in ipairs(sources) do
   cfile(src)
end

-- Generate Bindings for GLFW
if not fs.isfile('glfw/init.nelua') then
   nldecl.generate_bindings_file {
      include_dirs = { 'glfw/include' },
      output_file = 'glfw/init.nelua',
      parse_includes = {'GLFW/glfw3.h'},
   }
end
--------------------------------------------------

-- Compiling NanoVG
--------------------------------------------------
linklib "m"
cdefine "_CRT_SECURE_NO_WARNINGS"
cdefine "NANOVG_GL3_IMPLEMENTATION"

cfile "nanovg/src/nanovg.c"
cincdir "nanovg/src"
cinclude "nanovg.h"
cinclude "nanovg_gl.h"
cinclude "nanovg_gl_utils.h"

-- Generate Bindings for NanoVG
if not fs.isfile('nanovg/init.nelua') then
   nldecl.generate_bindings_file {
      include_dirs = { 'nanovg/src', 'glad/include' },
      output_file = 'nanovg/init.nelua',
      parse_includes = {'nanovg.h', 'nanovg_gl.h' },
   }
end
--------------------------------------------------
