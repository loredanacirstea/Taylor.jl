module env

export Env, env_set, env_find, env_get

using FromFile
@from "types.jl" import types: TaySymbol, TayType, TayList

struct Env
    outer::Any
    data::Dict{TaySymbol,Any}
end

function Env()
    Env(nothing, Dict())
end

function Env(outer)
    Env(outer, Dict())
end

function Env(outer, binds, exprs)
    e = Env(outer, Dict())
    for i=1:length(binds)
        if binds[i].v.view == "&"
            # e.data[binds[i+1]] = TayList(exprs[i:end])
            env_set(e, binds[i+1], TayList(exprs[i:end]))
            break
        else
            # e.data[binds[i]] = exprs[i]
            env_set(e, binds[i], exprs[i])
        end
    end
    e
end


function env_set(env::Env, k::TaySymbol, v)
    env.data[k] = v
end

function env_find(env::Env, k::TaySymbol)
    if haskey(env.data, k)
        env
    elseif env.outer != nothing
        env_find(env.outer, k)
    else
        nothing
    end
end

function env_get(env::Env, k::TaySymbol)
    e = env_find(env, k)
    if e != nothing
        e.data[k]
    else
        error("'$(k.v.view)' not found")
    end
end

end
