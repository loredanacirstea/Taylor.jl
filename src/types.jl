module types

export TayException, TayFunc, sequential_Q, equal_Q, hash_map, Atom

import Base.copy

using FromFile
@from "buffers.jl" import buffers: Uint8Array, BufferString

# TayType = TayException | TayFunc # | TaySymbol | TayString

@enum Node begin
    NodeList
    NodeNumber
    NodeString
    NodeNil
    NodeBoolean
    NodeSymbol
    NodeKeyword
    NodeVector
    NodeHashMap
    NodeFunction
    NodeAtom
end

struct TayException <: Exception
    tayval
end

struct TayBaseType
    __type::Uint8Array
end
function serialize(v::TayBaseType)
    Uint8Array([])
end

struct TaySymbol
    v::BufferString
    type::Node
    __type::Uint8Array

    function TaySymbol(name::Union{AbstractString, BufferString})
        value = BufferString(name)
        key = Symbol(value.view)
        get!(mapTaySymbol, key, new(value, NodeSymbol))
    end
end
# Dict{Symbol,TaySymbol}
mapTaySymbol = Dict()
function serialize(v::TaySymbol)
    Uint8Array([])
end

struct TayString
    v::BufferString
    type::Node
    __type::Uint8Array

    function TayString(name::Union{AbstractString, BufferString})
        __type = Uint8Array([])
        new(BufferString(name), NodeString, __type)
    end
end
function serialize(v::TayString)
    Uint8Array([])
end

mutable struct TayFunc
    fn::Function
    ast
    env
    params
    ismacro
    meta
end

# ismacro default to false
function TayFunc(fn, ast, env, params)
    TayFunc(fn, ast, env, params, false, nothing)
end

function copy(f::TayFunc)
    TayFunc(f.fn, f.ast, f.env, f.params, f.ismacro, f.meta)
end

function serialize(v::TayFunc)
    Uint8Array([])
end

function sequential_Q(obj)
    isa(obj, Array) || isa(obj, Tuple)
end

function equal_Q(a, b)
    ota = typeof(a)
    otb = typeof(b)
    if !(ota === otb || (sequential_Q(a) && sequential_Q(b)))
        return false
    end

    if sequential_Q(a)
        if length(a) !== length(b)
            return false
        end
        for (x, y) in zip(a,b)
            if !equal_Q(x, y)
                return false
            end
        end
        return true
    elseif isa(a,AbstractString)
        a == b
    elseif isa(a,Dict)
        if length(a) !== length(b)
          return false
        end
        for (k,v) in a
            if !equal_Q(v,b[k])
                return false
            end
        end
        return true
    else
        a === b
    end
end

function hash_map(lst...)
    hm = Dict()
    for i = 1:2:length(lst)
        hm[lst[i]] = lst[i+1]
    end
    hm
end

struct Atom
    val
end

end
