#!/usr/bin/env julia

using Test, Taylor

# EVAL, PRINT, READ, REP, repl_env

function run(line::String)
    result = ""
    try
        result = REP(line)
        println(result)
    catch e
        if isa(e, ErrorException)
            println("Error: $(e.msg)")
        else
            println("Error: $(string(e))")
        end
        # TODO: show at least part of stack
        if !isa(e, StackOverflowError)
            bt = catch_backtrace()
            Base.show_backtrace(stderr, bt)
        end
        println()
    end
    result
end

line = """
(+ 3 4)
"""

@testset "taylor 1" begin
    # Write your own tests here.
    @test run(line) == "7"
end

@testset "taylor 2" begin
    arr::Vector{UInt8} = [97, 115, 116, 114, 105, 110, 103]
    @test codeunits("astring") == arr
    println(codeunits("astring"))
    @test String(arr) == "astring"
end

# function make_bitvector(v::Vector{UInt8})
#     siz = sizeof(v)
#     bv = falses(siz<<3)
#     unsafe_copy!(reinterpret(Ptr{UInt8}, pointer(bv.chunks)), pointer(v), siz)
#     bv
# end

# function make_bitvector(zs::Vector{UInt8})
#     b = BitVector()
#     for z in zs
#         append!(b, [z & (0x1<<n) != 0 for n in 0:7])
#     end
#     b
# end

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
    ("string", BitArray([1, 0]))
])

function getid(key::String)
    get(rootids, key, BitArray([]))
end

# 0100 xx xxxxxxxxxxxxxxxxxxxxxxxxxx     xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx   byte-like(4), type(2), encoding(26), length(32)
function bytelike(length::UInt64, btype::String = "string", encoding::UInt8 = 0)
    bitv = BitArray([
        getid("bytelike")
        getid(btype)
        reverse(digits(encoding, base = 2, pad = 26))
        reverse(digits(length, base = 2, pad = 32))
    ])
    println(bitv)
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

# function _deserialize(inidata::Vector{UInt8})
#     typesig = inidata[1:8]
#     bytecode = inidata[9:]
#     if isBytelike(typesig)
#         len = bytelikeInfo(typesig)
#         result =
#         bytecode = bytecode[len:]
#         return [result, bytecode]
#     end

# end

# function deserialize(inidata::Vector{UInt8})
#     result = _deserialize(inidata)
#     result[0]
# end


@testset "taylor 3" begin
    arr::Vector{UInt8} = [97, 115, 116, 114, 105, 110, 103]
    stype = bytelike(UInt64(7), "string", UInt8(0))
    # println(stype)
    @test stype == [72, 0, 0, 0, 0, 0, 0, 7]
    stype2 = bytelikeInfo(stype)
    # println(stype2)
    @test stype2 == [true, 7, 2, 0]
end

@testset "taylor serialize" begin
    ast = READ("(str \"astring\")")
    println(ast)

    println(READ("""
    (def! d-number (fn* (value)
    {
        "type" "number"
        "value" (if (number? value)
            value
            (apply str
                (map
                    (fn* (char) (string-utf8-fromCharCode char))
                    value
                )
            )
        )
    }
))
    """))
end

# @testset "taylor string" begin
#     # Write your own tests here.
#     strType = run("\"astring\"")
#     println(strType)
#     @test strType.v.view == "astring"
#     @test strType.v.a8 == new Uint8Array([97, 115, 116, 114, 105, 110, 103])
#     # @test strType.type == 2
#     # @test strType.__type == new Uint8Array([72, 0, 0, 0, 0, 0, 0, 7])
#     # @test strType.serialize() == new Uint8Array([
#     #     72, 0, 0, 0, 0, 0, 0, 7,
#     #     97, 115, 116, 114, 105, 110, 103
#     # ])
# end
