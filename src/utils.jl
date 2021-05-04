module utils

export t_func, t_unknown, t_bytelike, bytelikeInfo

function make_bitvector(v::Vector{UInt8})
    mapreduce(x -> reverse(digits(x, base = 2, pad = 8)), vcat, v)
end

function bitarr_to_int(arr, val = 0)::UInt8
    v = 2^(length(arr)-1)
    for i in eachindex(arr)
        val += v*arr[i]
        v >>= 1
    end
    return val
end

function bit2u8Array(arr::BitArray)
    newarr::Vector{UInt8} = []
    len = UInt64(length(arr) / 8) - 1
    for index in 0:len
        start = index * 8 + 1
        stop = start + 7
        newval = bitarr_to_int(arr[start:stop])
        newarr = vcat(newarr, [newval])
    end
    newarr
end

function bytes2int(x::Array{UInt8,1})
    hex = bytes2hex(x)
    return parse(UInt64, hex, base=16)
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
])

function getid(key::String)
    get(rootids, key, BitArray([]))
end


# 0100 xx xxxxxxxxxxxxxxxxxxxxxxxxxx     xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx   byte-like(4), type(2), encoding(26), length(32)
function t_bytelike(length::UInt64, btype::String = "string", encoding::UInt8 = 0)
    bitv = BitArray([
        getid("bytelike")
        getid(btype)
        reverse(digits(encoding, base = 2, pad = 26))
        reverse(digits(length, base = 2, pad = 32))
    ])
    # println("t_bytelike ", bitv)
    bit2u8Array(bitv)
end

function bytelikeInfo(arr::Vector{UInt8})
    headb = make_bitvector(arr[1:4])
    if headb[1:4] != getid("bytelike") return [false] end
    length = bytes2int(arr[5:8])
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
        reverse(digits(length, base = 2, pad = 14))
        reverse(digits(arity, base = 2, pad = 6))
        reverse(digits(id, base = 2, pad = 32))
    ])
    # println("function ", bitv)
    bit2u8Array(bitv)
end

# 0000 010 xxxxxxxxxxxxxxxxxxx xxxxxx    xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx                variable/unknown(3), depth(25) + index(32)
function t_unknown(depth, index)
    bitv = BitArray([
        getid("special")
        getid("unknown")
        reverse(digits(depth, base = 2, pad = 25))
        reverse(digits(index, base = 2, pad = 32))
    ])
    # println("t_unknown ", bitv)
    bit2u8Array(bitv)
end


end # module
