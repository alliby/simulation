function rPrint(table, indent, depth)
    -- Default parameters
    indent = indent or ""
    depth = depth or 2
    
    -- Check if max depth reached
    if depth <= 0 then
        print(indent .. "[Max depth reached]")
        return
    end
    
    -- Iterate through all keys in the table
    for key, value in pairs(table) do
        -- Handle different types of values
        if type(value) == "table" then
            -- If value is another table, print the key and recursively print its contents
            print(indent .. tostring(key) .. " (table):")
            rPrint(value, indent .. "  ", depth - 1)
        else
            -- Print primitive values directly
            print(indent .. tostring(key) .. ": " .. tostring(value))
        end
    end
end

function metaPrint(table)
   for k, v in pairs(getmetatable(table)) do
      print(tostring(k) .. " : " .. tostring(v))
   end
end
