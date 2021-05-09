module utils

export t_func, t_unknown, t_bytelike, t_array, t_boolean, t_hashmap, t_list, t_nil, t_number, bytelikeInfo, functionInfo, unknownInfo, numberInfo, booleanInfo, nilInfo, listInfo, arrayInfo, hashmapInfo, int2bytes, bitarr_to_int

Uint8Array = Vector{UInt8}

function int2bin(v::Number, pad::Number)::Uint8Array
    reverse(digits(v, base = 2, pad = pad))
end

function int2bin(v::Number)::Uint8Array
    reverse(digits(v, base = 2))
end

function make_bitvector(v::Vector{UInt8})
    mapreduce(x -> int2bin(x, 8), vcat, v)
end

function bitarr_to_int(arr, val = 0)::UInt64
    v = 2^(length(arr)-1)
    for i in eachindex(arr)
        val += v*arr[i]
        v >>= 1
    end
    return val
end

function int2bytes(v::Number, pad::Number)::Uint8Array
    r = reinterpret(UInt8, [v])
    diff = pad - length(r)
    if diff > 0 r = vcat(r, fill(0, diff)) end
    r
end

function int2bytes(v::Number)::Uint8Array
    reinterpret(UInt8, [v])
end

function diffnextmultiple(v::Number, m::Number)
    r = v % m
    r == 0 ? 0 : (m - r)
end
# little endian
function bytes2int(x::Uint8Array)
    nm = diffnextmultiple(length(x), 8)
    x = vcat(x, fill(0, nm))
    r = reinterpret(UInt64, Uint8Array(x))
    r[1] # !
end

function bit2u8Array(arr::BitArray)::Uint8Array
    newarr::Uint8Array = []
    len = UInt64(length(arr) / 8) - 1
    for index in 0:len
        start = index * 8 + 1
        stop = start + 7
        newval = bitarr_to_int(arr[start:stop])
        newarr = vcat(newarr, [newval])
    end
    newarr
end

function bytes2bint(x::Array{UInt8,1})
    hex = bytes2hex(x)
    return parse(BigInt, hex, base=16)
end

rootids = Dict([
    ("bytelike", BitArray([0, 1, 0, 0]))
    ("bytes", BitArray([0, 1]))
    ("number", BitArray([0, 0, 0, 1]))
    ("listlike", BitArray([0, 0, 1, 0]))
    ("function", BitArray([0, 0, 1, 1]))
    ("choicelike", BitArray([0, 1, 0, 1]))
    ("mapping", BitArray([0, 1, 1, 1]))
    ("other", BitArray([1, 0, 0, 0]))
    ("special", BitArray([0, 0, 0, 0]))

    ("array", BitArray([0, 0, 1, 0]))
    ("list", BitArray([0, 0, 0, 1]))

    ("bytes", BitArray([0, 1]))
    ("string", BitArray([1, 0]))

    ("unknown", BitArray([0, 1, 0]))

    ("complex", BitArray([0, 1]))
    ("real", BitArray([1, 0]))
    ("rational", BitArray([0, 0, 1]))
    ("abstract-irrational", BitArray([0, 1, 0]))
    ("abstract-float", BitArray([0, 1, 1]))
    ("integer", BitArray([1, 0, 0]))
    ("float", BitArray([0, 0, 1]))
    ("bigfloat", BitArray([0, 1, 0]))
    ("bool", BitArray([0, 0, 1]))
    ("unsigned", BitArray([0, 0, 1]))
    ("signed", BitArray([0, 1, 0]))
])

function getid(key::String)
    get(rootids, key, BitArray([]))
end

# 0100 xx xxxxxxxxxxxxxxxxxxxxxxxxxx     xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx   byte-like(4), type(2), encoding(26), length(32)
function t_bytelike(length, btype = "string", encoding = 0)
    bitv = BitArray([
        getid("bytelike")
        getid(btype)
        int2bin(encoding, 26)
        int2bin(length, 32)
    ])
    # println("t_bytelike ", bitv)
    bit2u8Array(bitv)
end

function bytelikeInfo(arr::Vector{UInt8})
    headb = make_bitvector(arr[1:4])
    if headb[1:4] != getid("bytelike") return [false] end
    length = bytes2int(reverse(arr[5:8])) # be -> le
    type = bitarr_to_int(headb[5:6])
    encoding = bitarr_to_int(headb[6:8])
    [true, length, type, encoding]
end

# 0011 0 100 xxxx xxxxxxxxxxxxxx xxxxxx  xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx                (4) pure(1), solidity(3), (4), body_length(14), arity(6), 4b signature
function t_func(length, arity, id, pure = true)
    bitv = BitArray([
        getid("function")
        pure ? BitArray([0]) : BitArray([1])
        BitArray([0, 0, 0, 0, 0, 0, 0])
        int2bin(length, 14)
        int2bin(arity, 6)
        int2bin(id, 32)
    ])
    # println("function ", bitv)
    bit2u8Array(bitv)
end

function functionInfo(arr::Vector{UInt8})
    headb = make_bitvector(arr[1:4])
    if headb[1:4] != getid("function") return [false] end
    bodylen = bitarr_to_int(headb[13:26])
    arity = bitarr_to_int(headb[27:32])
    index = bytes2int(reverse(arr[5:8])) # be -> le
    [true, arity, bodylen, index]
end

# 0000 010 xxxxxxxxxxxxxxxxxxx xxxxxx    xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx                variable/unknown(3), depth(25) + index(32)
function t_unknown(depth, index)
    bitv = BitArray([
        getid("special")
        getid("unknown")
        int2bin(depth, 25)
        int2bin(index, 32)
    ])
    # println("t_unknown ", bitv)
    bit2u8Array(bitv)
end

function unknownInfo(arr::Vector{UInt8})
    bitv = make_bitvector(arr)
    utype = BitArray([
        getid("special")
        getid("unknown")
    ])
    if bitv[1:7] != utype return [false] end
    depth = bitarr_to_int(bitv[7:32])
    index = bitarr_to_int(bitv[33:64])
    [true, depth, index]
end

function t_hashmap(arity, id)
    bitv = BitArray([
        getid("listlike")
        [1]
        getid("mapping")
        repeat([0], 17)
        int2bin(arity, 6)
        int2bin(id, 32)
    ])
    # println("t_hashmap ", bitv)
    bit2u8Array(bitv)
end

function hashmapInfo(arr::Vector{UInt8})
    bitv = make_bitvector(arr)
    utype = BitArray([
        getid("listlike")
        [1]
        getid("mapping")
    ])
    if bitv[1:9] != utype return [false] end
    arity = bitarr_to_int(bitv[27:32])
    id = bitarr_to_int(bitv[33:64])
    [true, arity, id]
end

function t_list(arity, id)
    bitv = BitArray([
        getid("listlike")
        [1]
        getid("list")
        repeat([0], 17)
        int2bin(arity, 6)
        int2bin(id, 32)
    ])
    # println("t_list ", bitv)
    bit2u8Array(bitv)
end

function listInfo(arr::Vector{UInt8})
    bitv = make_bitvector(arr)
    utype = BitArray([
        getid("listlike")
        [1]
        getid("list")
    ])
    if bitv[1:9] != utype return [false] end
    arity = bitarr_to_int(bitv[27:32])
    id = bitarr_to_int(bitv[33:64])
    [true, arity, id]
end

function t_nil()
    Uint8Array([0, 0, 0, 0, 0, 0, 0, 0])
end

function nilInfo(arr::Vector{UInt8})
    [sum(arr) == 0]
end

# 0001 xx xxxxxxxx  xxxxxxxxxxxxxxxx     xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx    number(4), reality(2), rationality(3), sign(3), (2) + size(16) + 0 (?)
# 0001 10 100 010 10 00 xxxxxxxxxxxxxxxx    xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx                real(2), integer(3), signed(3), int(2) + size(16) + 0 (?)
function t_number(size::Number)
    bitv = BitArray([
        getid("number")
        getid("real")
        getid("integer")
        getid("signed")
        [1, 0, 0, 0]
        int2bin(size, 16)
        repeat([0], 32)
    ])
    # println("t_number ", bitv)
    bit2u8Array(bitv)
end

function numberInfo(arr::Vector{UInt8})
    headb = make_bitvector(arr[1:4])
    if headb[1:4] != getid("number") return [false] end
    size = bitarr_to_int(headb[17:32])
    [true, size]
end

function t_boolean(value::Number)
    bitv = BitArray([
        getid("number")
        getid("real")
        getid("integer")
        getid("bool")
        repeat([0], 20)
        int2bin(value, 32)
    ])
    # println("t_boolean ", bitv)
    bit2u8Array(bitv)
end

function booleanInfo(arr::Vector{UInt8})
    bitv = make_bitvector(arr)
    btype = BitArray([
        getid("number")
        getid("real")
        getid("integer")
        getid("bool")
    ])
    if bitv[1:12] != btype return [false] end
    [true]
end

# 0010 0 0010 xxxxxxxxxxxxxxxxx xxxxxx   xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx                  homog(1), array id(4), (23), length(32)
function t_array(length::Number)
    bitv = BitArray([
        getid("listlike")
        [0]
        getid("array")
        repeat([0], 23)
        int2bin(length, 32)
    ])
    # println("t_array ", bitv)
    bit2u8Array(bitv)
end

function arrayInfo(arr::Vector{UInt8})
    headb = make_bitvector(arr)
    if headb[1:9] != vcat(getid("listlike"), [0], getid("array")) return [false] end
    len = bitarr_to_int(headb[33:64])
    [true, len]
end

end # module
