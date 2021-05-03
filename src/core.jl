module core

# import types
# import reader
# using printer
# import readline_mod

using FromFile
@from "types.jl" import types
@from "reader.jl" import reader
@from "printer.jl" using printer

export ns

function string_Q(obj)
    isa(obj,types.TayString)
end

function keyword_Q(obj)
    isa(obj,AbstractString) && (length(obj) > 0 && obj[1] == '\u029e')
end

function concat(args...)
    res = []
    for a=args
        res = [res; Any[a...]]
    end
    res
end

function do_apply(f, all_args...)
    fn = isa(f,types.TayFunc) ? f.fn : f
    args = concat(all_args[1:end-1], all_args[end])
    fn(args...)
end

function do_map(a,b)
    # map and convert to array/list
    if isa(a,types.TayFunc)
        collect(map(a.fn,b))
    else
        collect(map(a,b))
    end
end

function conj(seq, args...)
    if isa(seq,Array)
        concat(reverse(args), seq)
    else
        tuple(concat(seq, args)...)
    end
end

function do_seq(obj)
    if isa(obj,Array)
        length(obj) > 0 ? obj : nothing
    elseif isa(obj,Tuple)
        length(obj) > 0 ? Any[obj...] : nothing
    elseif isa(obj,types.TayString)
        length(obj) > 0 ? [string(c) for c=obj.v.view] : nothing
    elseif obj == nothing
        nothing
    else
        error("seq: called on non-sequence")
    end
end


function with_meta(obj, meta)
    new_obj = types.copy(obj)
    new_obj.meta = meta
    new_obj
end

ns = Dict{Any,Any}(
    Symbol("=") => (a,b) -> types.equal_Q(a, b),
    :throw => (a) -> throw(types.TayException(a)),

    Symbol("nil?") => (a) -> a === nothing,
    Symbol("true?") => (a) -> a === true,
    Symbol("false?") => (a) -> a === false,
    Symbol("string?") => string_Q,
    Symbol("Symbol") => (a) -> Symbol(a),
    Symbol("Symbol?") => (a) -> typeof(a) === Symbol,
    Symbol("keyword") => (a) -> a[1] == '\u029e' ? a : "\u029e$(a)",
    Symbol("keyword?") => keyword_Q,
    Symbol("number?") => (a) -> isa(a, AbstractFloat) || isa(a, Int64),
    Symbol("fn?") => (a) -> isa(a, Function) || (isa(a, types.TayFunc) && !a.ismacro),
    Symbol("macro?") => (a) -> isa(a, types.TayFunc) && a.ismacro,

    Symbol("pr-str") => (a...) -> join(map((e)->pr_str(e, true),a)," "),
    :str => (a...) -> join(map((e)->pr_str(e, false),a),""),
    :prn => (a...) -> println(join(map((e)->pr_str(e, true),a)," ")),
    :println => (a...) -> println(join(map((e)->pr_str(e, false),a)," ")),
    Symbol("read-string") => (a) -> reader.read_str(a),
    # :readline => readline_mod.do_readline,
    :slurp => (a) -> readall(open(a)),

    :< => <,
    :<= => <=,
    :> => >,
    :>= => >=,
    :+ => +,
    :- => -,
    Symbol("*") => *,
    :/ => div,
    Symbol("time-ms") => () -> round(Int, time()*1000),

    :list => (a...) -> Any[a...],
    Symbol("list?") => (a) -> isa(a, Array),
    :vector => (a...) -> tuple(a...),
    Symbol("vector?") => (a) -> isa(a, Tuple),
    Symbol("hash-map") => types.hash_map,
    Symbol("map?") => (a) -> isa(a, Dict),
    :assoc => (a, b...) -> merge(a, types.hash_map(b...)),
    :dissoc => (a, b...) -> foldl((x,y) -> delete!(x,y),copy(a), b),
    :get => (a,b) -> a === nothing ? nothing : get(a,b,nothing),
    Symbol("contains?") => haskey,
    :keys => (a) -> [keys(a)...],
    :vals => (a) -> [values(a)...],

    Symbol("sequential?") => types.sequential_Q,
    :cons => (a,b) -> [Any[a]; Any[b...]],
    :concat => concat,
    :vec => (a) -> tuple(a...),
    :nth => (a,b) -> b+1 > length(a) ? error("nth: index out of range") : a[b+1],
    :first => (a) -> a === nothing || isempty(a) ? nothing : first(a),
    :rest => (a) -> a === nothing ? Any[] : Any[a[2:end]...],
    Symbol("empty?") => isempty,
    :count => (a) -> a == nothing ? 0 : length(a),
    :apply => do_apply,
    :map => do_map,

    :conj => conj,
    :seq => do_seq,

    :meta => (a) -> isa(a,types.TayFunc) ? a.meta : nothing,
    Symbol("with-meta") => with_meta,
    :atom => (a) -> types.Atom(a),
    Symbol("atom?") => (a) -> isa(a,types.Atom),
    :deref => (a) -> a.val,
    :reset! => (a,b) -> a.val = b,
    :swap! => (a,b,c...) -> a.val = do_apply(b, a.val, c),
    )

end
