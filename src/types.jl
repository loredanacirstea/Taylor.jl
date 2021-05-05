module types

export TayType, TayException, TayFunc, TayString, TayList, sequential_Q, equal_Q, hash_map, Atom, serialize, getIndex

import Base.copy

using FromFile
@from "buffers.jl" import buffers: Uint8Array, BufferString
@from "utils.jl" import utils: t_func, t_unknown, t_bytelike

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

# TayType = Union{TayException, TayFunc, TaySymbol, TayString, TayList}

countf = 0;
unknownMap = Dict()
fmap = Dict()
fmap_r = Dict()

function getIndex(name::AbstractString)
    global countf += 1;
    fmap[name] = countf;
    fmap_r[countf] = name;
    return countf;
end
getFuncNameByIndex = (index) -> fmap_r[index]


struct TayException <: Exception
    tayval
end

struct TayBaseType
    __type::Uint8Array
end
serialize(v::TayBaseType) = x -> Uint8Array([])

# Dict{Symbol,TaySymbol}
mapTaySymbol = Dict()
struct TaySymbol
    v::BufferString
    type::Node
    __type::Uint8Array

    function TaySymbol(name::Union{AbstractString, BufferString})
        v = BufferString(name)
        key = Symbol(v.view)
        __type = t_bytelike(length(v.a8), "string", 200)
        get!(mapTaySymbol, key, new(v, NodeSymbol, __type))
    end
end

function serialize(v::TaySymbol, options::Dict = Dict())::Uint8Array
    if haskey(options, "arity") && haskey(options, "length")
        index = haskey(fmap, v.v.view) ? fmap[v.v.view] : getIndex(v.v.view)
        t_func(get(options, "length", 0), get(options, "arity", 0), index)
    elseif haskey(unknownMap, v.v.view)
        t_unknown(unknownMap[this.v.view].depth, unknownMap[this.v.view].index)
    else
        Uint8Array(vcat(v.__type, v.v.a8))
    end
end

struct TayString
    v::BufferString
    type::Node
    __type::Uint8Array

    function TayString(name::Union{AbstractString, BufferString})
        v = BufferString(name)
        __type = t_bytelike(length(v.a8), "string", 0)
        new(v, NodeString, __type)
    end
end
serialize(v::TayString) = serialize(v)
function serialize(v::TayString, options::Dict = Dict())
    Uint8Array(vcat(v.__type, v.v.a8));
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

serialize(v::TayFunc) = serialize(v)
function serialize(v::TayFunc, options::Dict = Dict())
    Uint8Array([])
end

TayType = Union{TayException, TayFunc, TaySymbol, TayString, TayBaseType,Any}
struct TayList
    list::Vector{TayType}
    type::Node
    __type::Uint8Array

    function TayList(list::Vector{TayType})
        __type = Uint8Array([])
        new(list, NodeList, __type)
    end
end
serialize(v::TayList) = serialize(v, UInt64(0))
function serialize(tlist::TayList, options::Dict = Dict())::Uint8Array
    list = tlist.list
    bytes = Uint8Array([])
    level = get(options, "level", 0)
    if isa(list[1], TaySymbol) && !haskey(unknownMap, list[1].v.view)
        bytes = map(x -> serialize(x, Dict("level" => level + 1)), list[2:length(list)])
        if length(bytes) > 0 bytes = reduce(vcat, bytes) end
        bytes = vcat(
            serialize(list[1], Dict("arity" => length(list) - 1, "length" => length(bytes))),
            bytes
        )
    else
        bytes = vcat(
            tlist.__type,
            map(x -> serialize(x, Dict("level" => level + 1)), list),
        )
    end
    Uint8Array(bytes)
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

