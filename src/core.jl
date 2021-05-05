module core

# import types
# import reader
# using printer
# import readline_mod

import DataStructures: OrderedDict

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

TaySymbol = types.TaySymbol
ns = () -> OrderedDict{TaySymbol,Any}(
    TaySymbol("=") => (a,b) -> types.equal_Q(a, b),
    TaySymbol("throw") => (a) -> throw(types.TayException(a)),

    TaySymbol("nil?") => (a) -> a === nothing,
    TaySymbol("true?") => (a) -> a === true,
    TaySymbol("false?") => (a) -> a === false,
    TaySymbol("string?") => string_Q,
    TaySymbol("Symbol") => (a) -> types.TaySymbol(a.v.view),
    TaySymbol("Symbol?") => (a) -> typeof(a) === Symbol,
    TaySymbol("keyword") => (a) -> a[1] == '\u029e' ? a : "\u029e$(a)",
    TaySymbol("keyword?") => keyword_Q,
    TaySymbol("number?") => (a) -> isa(a, AbstractFloat) || isa(a, Int64),
    TaySymbol("fn?") => (a) -> isa(a, Function) || (isa(a, types.TayFunc) && !a.ismacro),
    TaySymbol("macro?") => (a) -> isa(a, types.TayFunc) && a.ismacro,

    TaySymbol("pr-str") => (a...) -> join(map((e)->pr_str(e, true),a)," "),
    TaySymbol("str") => (a...) -> types.TayString(join(map((e)->pr_str(e, false),a),"")),
    TaySymbol("prn") => (a...) -> println(join(map((e)->pr_str(e, true),a)," ")),
    TaySymbol("println") => (a...) -> println(join(map((e)->pr_str(e, false),a)," ")),
    TaySymbol("read-string") => (a) -> reader.read_str(a),
    # "readline") => readline_mod.do_readline,
    TaySymbol("slurp") => (a) -> readall(open(a)),

    TaySymbol("<") => <,
    TaySymbol("<=") => <=,
    TaySymbol(">") => >,
    TaySymbol(">=") => >=,
    TaySymbol("+") => +,
    TaySymbol("-") => -,
    TaySymbol("*") => *,
    TaySymbol("/") => div,
    TaySymbol("time-ms") => () -> round(Int, time()*1000),

    TaySymbol("list") => (a...) -> types.TayList([a...]),
    TaySymbol("list?") => (a) -> isa(a, types.TayList),
    TaySymbol("vector") => (a...) -> tuple(a...),
    TaySymbol("vector?") => (a) -> isa(a, Tuple),
    TaySymbol("hash-map") => types.hash_map,
    TaySymbol("map?") => (a) -> isa(a, Dict),
    TaySymbol("assoc") => (a, b...) -> merge(a, types.hash_map(b...)),
    TaySymbol("dissoc") => (a, b...) -> foldl((x,y) -> delete!(x,y),copy(a), b),
    TaySymbol("get") => (a,b) -> a === nothing ? nothing : get(a,b,nothing),
    TaySymbol("contains?") => haskey,
    TaySymbol("keys") => (a) -> types.TayList([keys(a)...]),
    TaySymbol("vals") => (a) -> types.TayList([values(a)...]),

    TaySymbol("sequential?") => types.sequential_Q,
    TaySymbol("cons") => (a,b) -> types.TayList([Any[a]; Any[b...]]),
    TaySymbol("concat") => (a...) -> types.TayList(concat(a...)),
    TaySymbol("vec") => (a) -> tuple(a...),
    TaySymbol("nth") => (a,b) -> b+1 > length(a) ? error("nth: index out of range") : a[b+1],
    TaySymbol("first") => (a) -> a === nothing || isempty(a) ? nothing : first(a),
    TaySymbol("rest") => (a) -> a === nothing ? types.TayList([]) : types.TayList([a[2:end]...]),
    TaySymbol("empty?") => isempty,
    TaySymbol("count") => (a) -> a == nothing ? 0 : length(a),
    TaySymbol("apply") => do_apply,
    TaySymbol("map") => do_map,

    TaySymbol("conj") => conj,
    TaySymbol("seq") => do_seq,

    TaySymbol("meta") => (a) -> isa(a,types.TayFunc) ? a.meta : nothing,
    TaySymbol("with-meta") => with_meta,
    TaySymbol("atom") => (a) -> types.Atom(a),
    TaySymbol("atom?") => (a) -> isa(a,types.Atom),
    TaySymbol("deref") => (a) -> a.val,
    TaySymbol("reset!") => (a,b) -> a.val = b,
    TaySymbol("swap!") => (a,b,c...) -> a.val = do_apply(b, a.val, c),
)

end
