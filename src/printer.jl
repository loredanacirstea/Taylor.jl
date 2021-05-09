module printer

# import types

using FromFile
@from "types.jl" import types: TayNil, TayList, TayVector, TayString, TaySymbol, TayNumber, TayBoolean, TayFunc, TayHashMap, Atom

export pr_str

function pr_str(obj, print_readably=true)
    _r = print_readably
    if isa(obj, TayList)
        "($(join([pr_str(o, _r) for o=obj.list], " ")))"
    elseif isa(obj, Array)
        "($(join([pr_str(o, _r) for o=obj], " ")))"
    elseif isa(obj, TayVector)
        "[$(join([pr_str(o, _r) for o=obj.list], " "))]"
    elseif isa(obj, TayHashMap)
        "{$(join(["$(pr_str(o[1],_r)) $(pr_str(o[2],_r))" for o=obj.stringMap], " "))}"
    elseif isa(obj, TayString)
        if _r
            str = replace(replace(replace(obj.v.view,
                                          "\\" => "\\\\"),
                                  "\"" => "\\\""),
                          "\n" => "\\n")
            "\"$(str)\""
        else
            obj.v.view
        end
    elseif isa(obj, TaySymbol) || isa(obj, TayNumber) || isa(obj, TayBoolean)
        obj.v.view
    elseif isa(obj, AbstractString)
        if length(obj) > 0 && obj[1] == '\u029e'
            ":$(obj[3:end])"
        end
    elseif isa(obj, TayNil)
        "nil"
    elseif typeof(obj) == TayFunc
        "(fn* $(pr_str(obj.params,true)) $(pr_str(obj.ast,true)))"
    elseif typeof(obj) == Atom
        "(atom $(pr_str(obj.val,true)))"
    elseif typeof(obj) == Function
        "#<native function: $(string(obj))>"
    else
        string(obj)
    end
end

end
