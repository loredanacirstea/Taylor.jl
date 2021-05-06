module buffers

export BufferBase, BufferString, BufferNumber, BufferBoolean, Uint8Array, Uint16Array

using FromFile
@from "utils.jl" import utils: int2bytes, bytes2int

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
    view::AbstractString
    _temp::Number

    function BufferNumber(value::Union{Number, Uint8Array, BufferNumber}, size::Number = 32)
        if isa(value, BufferNumber) return value end
        a8 = value
        _temp = value
        if isa(value, Number)
            a8 = int2bytes(value, size)
            view = string(value)
        else
            _temp = bytes2int(value)
            view = string(_temp)
        end
        typeassert(a8, Uint8Array)
        new(a8, view, _temp)
    end
end

struct BufferBoolean
    a8::Uint8Array
    view::AbstractString

    function BufferBoolean(value::Union{Bool, Uint8Array, BufferBoolean})
        if isa(value, BufferBoolean) return value end
        a8 = value
        if isa(value, Bool)
            a8 = Uint8Array([value == true ? 1 : 0]);
        end
        typeassert(a8, Uint8Array)
        view = a8[1] == 1 ? "true" : "false"
        new(a8, view)
    end
end

end # module
