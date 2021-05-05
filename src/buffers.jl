module buffers

export BufferBase, BufferString, BufferNumber, BufferBoolean, Uint8Array, Uint16Array

using FromFile
@from "utils.jl" import utils: bitarr_to_int, int2bytes

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
            a8 = Uint8Array(codeunits(value))
        else
            view = String(value)
        end
        typeassert(a8, Uint8Array)
        new(a8, view)
    end
end

struct BufferNumber
    a8::Uint8Array
    view::Number

    function BufferNumber(value::Union{Number, Uint8Array, BufferNumber})
        if isa(value, BufferNumber) return value end
        a8 = value
        view = value
        if isa(value, Number)
            a8 = int2bytes(value)
        else
            view = bitarr_to_int(value)
        end
        typeassert(a8, Uint8Array)
        new(a8, view)
    end
end

struct BufferBoolean
    a8::Uint8Array
    view::AbstractString

    function BufferBoolean(value::Union{Bool, Uint8Array, BufferBoolean})
        if isa(value, BufferBoolean) return value end
        a8 = value
        view = value
        if isa(value, Bool)
            a8 = Uint8Array([value == true ? 1 : 0]);
        else
            view = value[1] == 1 ? "true" : "false"
        end
        typeassert(a8, Uint8Array)
        new(a8, view)
    end
end

end # module
