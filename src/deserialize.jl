module serialization

export deserialize

using FromFile
@from "buffers.jl" using buffers
@from "utils.jl" using utils
@from "types.jl" using types

function _deserialize(inidata::Uint8Array)
    typesig = inidata[1:8]
    bytecode = inidata[9:length(inidata)]
    println("--- typesig ", typesig)

    info = bytelikeInfo(typesig)
    if info[1] == true
        (len, type, encoding) = info[2:4]
        println("--- bytelikeInfo ", info)
        result = bytecode[1:len]
        bytecode = bytecode[len:length(bytecode)]
        if type == 2
            # if encoding == 100 result = TayKeyword(result) end
            if encoding == 200
                return [TaySymbol(BufferString(result)), bytecode]
            else
                return [TayString(BufferString(Uint8Array(result))), bytecode]
            end
        end
        error("Only bytelike string is supported")
    end

    info = booleanInfo(typesig)
    if info[1] == true
        println("--- booleanInfo ", info)
        result = TayBoolean(BufferBoolean(bytecode[1:1]))
        bytecode = bytecode[2:length(bytecode)]
        return [result, bytecode]
    end

    info = numberInfo(typesig)
    if info[1] == true
        println("--- numberInfo ", info)
        (len, value) = info[2:3]
        len = len / 8
        result = TayNumber(value)
        bytecode = bytecode[len:length(bytecode)]
        return [result, bytecode]
    end

    info = unknownInfo(typesig)
    if info[1] == true
        println("--- unknownInfo ", info)
        (depth, index) = info[2:3]
        result = TaySymbol(BufferString("x"*depth*"_"*index))
        return [result, bytecode]
    end

    info = nilInfo(typesig)
    if info[1] == true
        println("--- nilInfo ", info)
        result = TayNil.instance
        return [result, bytecode]
    end

    info = listInfo(typesig)
    if info[1] == true
        println("--- listInfo ", info)
        arity = info[2]
        result = []
        for i in range(1, arity, step = 1)
            _result = _deserialize(bytecode)
            bytecode = _result[2]
            push!(result, _result[1])
        end
        result = TayList(result)
        return [result, bytecode]
    end

    info = arrayInfo(typesig)
    if info[1] == true
        println("--- arrayInfo ", info)
        len = info[2]
        elemSig = bytecode[1:8]
        bytecode = bytecode[8:length(bytecode)]
        result = []
        for i in range(1, len, step = 1)
            elem = vcat(elemSig, bytecode)
            _result = _deserialize(elem)
            bytecode = _result[2]
            push!(result, _result[1])
        end
        result = TayVector(result)
        return [result, bytecode]
    end

    info = hashmapInfo(typesig)
    if info[1] == true
        println("--- hashmapInfo ", info)
        len = info[2]
        result = []
        for i in range(1, len, step = 1)
            _result = _deserialize(bytecode)
            bytecode = _result[2]
            push!(result, _result[1])
        end
        result = TayHashMap(result)
        return [result, bytecode]
    end

    info = functionInfo(typesig)
    if info[1] == true
        println("--- functionInfo ", info)
        (arity, bodylen, index) = info[2:4]
        name = getFuncNameByIndex(index)
        body = bytecode[1:bodylen]
        result::Vector{TayType} = [
            TaySymbol(BufferString(name)),
        ]
        for i in range(1, arity, step = 1)
            println("--- functionInfo i ", i)
            _result = _deserialize(body)
            body = _result[2]
            push!(result, _result[1])
            println("--- arg ",  _result[1])
        end
        bytecode = bytecode[(bodylen + 1):length(bytecode)]
        res = TayList(result)
        return [res, bytecode]
    end

    error("decode type not supported: ") # typesig, inidata
end

function deserialize(inidata::Uint8Array)
    result = _deserialize(inidata)
    result[1]
end

end # module
