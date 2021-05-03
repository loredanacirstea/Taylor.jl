module buffers

# export BufferBase, BufferString, BufferBoolean
export BufferBase, BufferString

Uint8Array = Vector{UInt8}
Uint16Array = Vector{UInt16}

@enum EnumName begin
    value1
    value2
end

struct BufferBase
    a8::Uint8Array
end

struct BufferString
    a8::Uint8Array
    view::String

    function BufferString(value::Union{AbstractString, Uint8Array, BufferString})
        if isa(value, BufferString) return value end
        a8 = value
        view = value
        if isa(value, AbstractString)
            a8 = Uint8Array(codeunits("astring"))
        else
            view = String(value)
        end
        typeassert(a8, Uint8Array)
        new(a8, view)
    end
end

function u8ToString(v::Uint8Array)
    v
end

function u8FromString(v::AbstractString)
    # codepoint.(v)
    for c in v
        println(c)
    end
end


end # module
