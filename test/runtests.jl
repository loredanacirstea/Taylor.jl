#!/usr/bin/env julia

using Test, Taylor
# import Taylor: EVAL, READ, REP, serialize, repl_env

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
    @test stype == [72, 0, 0, 0, 0, 0, 0, 7]
    stype2 = utils.bytelikeInfo(stype)
    @test stype2 == [true, 7, 2, 0]
end

@testset "taylor serialize" begin
    expr = "(str (str \"astring\") \" astring2\" )"
    ast = READ(expr)

    @test serialize(ast) == [48, 0, 10, 2, 0, 0, 0, 15, 48, 0, 3, 193, 0, 0, 0, 15, 72, 0, 0, 0, 0, 0, 0, 7, 97, 115, 116, 114, 105, 110, 103, 72, 0, 0, 0, 0, 0, 0, 9, 32, 97, 115, 116, 114, 105, 110, 103, 50]

    result = run(expr, false)
    @test result.__type == [72, 0, 0, 0, 0, 0, 0, 16]
    @test result.v.view == "astring astring2"
    @test result.v.a8 == [97, 115, 116, 114, 105, 110, 103, 32, 97, 115, 116, 114, 105, 110, 103, 50]
    @test serialize(result) == [
        72, 0, 0, 0, 0, 0, 0, 16,
        97, 115, 116, 114, 105, 110, 103, 32, 97, 115, 116, 114, 105, 110, 103, 50
    ]

    # deserialize(serialize(ast)) == ast
end

# @testset "taylor serialize" begin
#     expr = """
#         (def! d-number (fn* (value)
#             {
#                 "type" "number"
#                 "value" (if (number? value)
#                     value
#                     (apply str
#                         (map
#                             (fn* (char) (string-utf8-fromCharCode char))
#                             value
#                         )
#                     )
#                 )
#             }
#         ))
#     """
#     ast = READ(expr)
#     println(ast)
# end
