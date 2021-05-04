#!/usr/bin/env julia

using Test, Taylor
# import Taylor: EVAL, READ, REP, serialize, repl_env

# EVAL, PRINT, READ, REP, repl_env

init()

function run(line::String, print::Bool = true)
    result = ""
    op = print ? REP : x -> EVAL(READ(x), repl_env)
    try
        # result = REP(line)
        result = op(line)
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
    stype = utils.t_bytelike(UInt64(7), "string", UInt8(0))
    # println(stype)
    @test stype == [72, 0, 0, 0, 0, 0, 0, 7]
    stype2 = utils.bytelikeInfo(stype)
    # println(stype2)
    @test stype2 == [true, 7, 2, 0]
end

@testset "taylor serialize" begin
    expr = "(str (str \"astring\") \" astring2\" )"
    ast = READ(expr)
    @test run(expr, false).v.view == "astring astring2"

    @test serialize(ast) == [48, 0, 7, 194, 0, 0, 0, 15, 72, 0, 0, 0, 0, 0, 0, 7, 97, 115, 116, 114, 105, 110, 103, 72, 0, 0, 0, 0, 0, 0, 8, 97, 115, 116, 114, 105, 110, 103, 50]

    # deserialize(serialize(ast)) == ast
    return

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
