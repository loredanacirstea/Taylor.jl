module types

export TayType, TayException, TayNil, TaySymbol, TayFunc, TayString, TayBoolean, TayNumber, TayList, TayVector, TayHashMap, sequential_Q, equal_Q, hash_map, Atom, serialize, getIndex, getFuncNameByIndex

import Base.copy

using FromFile
@from "buffers.jl" import buffers: Uint8Array, BufferString, BufferNumber, BufferBoolean
@from "utils.jl" import utils: t_func, t_unknown, t_bytelike, t_array, t_boolean, t_hashmap, t_list, t_nil, t_number

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

struct TayNil
    instance::Nothing
    __type::Uint8Array

    function TayNil()
        new(nothing, t_nil())
    end
end
serialize(v::TayNil) = serialize(v)
function serialize(v::TayNil, options::Dict = Dict())
    v.__type
end

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

struct TayNumber
    v::BufferNumber
    __type::Uint8Array

    function TayNumber(value::Union{Number, BufferNumber})
        v = BufferNumber(value, 32)
        __type = t_number(32)
        new(v, __type)
    end
end
serialize(v::TayNumber) = serialize(v)
function serialize(v::TayNumber, options::Dict = Dict())
    Uint8Array(vcat(v.__type, v.v.a8));
end

struct TayBoolean
    v::BufferBoolean
    __type::Uint8Array

    function TayBoolean(value::Union{Bool, BufferBoolean})
        v = BufferBoolean(value)
        __type = t_boolean(v.a8[1] === 1)
        new(v, __type)
    end
end
serialize(v::TayBoolean) = serialize(v)
function serialize(v::TayBoolean, options::Dict = Dict())
    Uint8Array(vcat(v.__type, v.v.a8));
end

struct TayVector
    list::Vector{Any}
    type::Node
    __type::Uint8Array

    function TayVector(list::Vector{Any})
        __type = t_array(length(list))
        new(list, NodeVector, __type)
    end
end
serialize(v::TayVector) = serialize(v)
function serialize(v::TayVector, options::Dict = Dict())
    list = v.list
    options["level"] = get!(options, "level", 0) + 1
    function sv(x::Any)
        v = serialize(x, options)
        v[9:length(v)] # remove signature
    end
    bytes = vcat(
        v.__type,
        list[1].__type, # element signature
        mapreduce(sv, vcat, list),
    )
    Uint8Array(bytes)
end

struct TayHashMap
    stringMap::Dict{Any,Any}
    type::Node
    __type::Uint8Array

    function TayHashMap(list::Vector{Any})
        stringMap = Dict()
        len = length(list)
        if len % 2 != 0 error("unexpected hash length") end
        for i in 1:2:len
            stringMap[list[i]] = list[i + 1]
        end

        __type = t_hashmap(len, 0);
        new(list, NodeHashMap, __type)
    end
end
# serialize(v::TayHashMap) = serialize(v)
# function serialize(v::TayHashMap, options::Dict = Dict())
#     list = v.stringMap
#     bytes = vcat(
#         v.__type,
#         list[1].__type,
#         map(x -> range(serialize(x, Dict("level" => level + 1)), list),
#     )
#     println("--serialize TayHashMap: ", bytes)
#     Uint8Array(bytes)
# end

TayType = Union{TayException, TayNil, TayFunc, TaySymbol, TayString, TayNumber, TayBoolean, TayHashMap, TayBaseType, Any}
struct TayList
    list::Vector{TayType}
    type::Node
    __type::Uint8Array

    function TayList(list::Vector{TayType})
        __type = t_list(length(list), 0);
        new(list, NodeList, __type)
    end
end

serialize(v::TayList) = serialize(v, UInt64(0))
function serialize(tlist::TayList, options::Dict = Dict())::Uint8Array
    list = tlist.list
    bytes = Uint8Array([])
    level = get(options, "level", 0)
    if isa(list[1], TaySymbol) && !haskey(unknownMap, list[1].v.view)
        name = list[1].v.view
        if name == "let*" && isa(list[2], TayList)
            for (i, unknown) in enumerate(list[2].list)
                if i % 2 != 0 || !isa(unknown, TaySymbol) continue end
                unknownMap[unknown.v.view] = Dict("depth" => level, "index" => i / 2)
            end
        elseif name == "fn*" && isa(list[2], TayList)
            for (i, unknown) in enumerate(list[2].list)
                if !isa(unknown, TaySymbol) continue end
                unknownMap[unknown.v.view] = Dict("depth" => level, "index" => i)
            end
        end
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

function dict_to_vec(dict)
    vec = []
    for (k,v) in dict
        push!(vec, k)
        push!(vec, v)
    end
end

struct Atom
    val
end

end

