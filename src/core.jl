module core

# import types
# import reader
# using printer
# import readline_mod

import DataStructures: OrderedDict

using FromFile
@from "types.jl" using types
@from "reader.jl" import reader
@from "printer.jl" using printer

export ns

function string_Q(obj)
    isa(obj,TayString)
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
    fn = isa(f,TayFunc) ? f.fn : f
    args = concat(all_args[1:end-1], all_args[end])
    fn(args...)
end

function do_map(a,b)
    # map and convert to array/list
    if isa(a,TayFunc)
        collect(map(a.fn,b))
    else
        collect(map(a,b))
    end
end

function conj(seq, args...)
    if isa(seq,TayList)
        TayList(concat(reverse(args), seq.list))
    else
        TayVector(concat(seq.list, args))
    end
end

function do_seq(obj)
    if isa(obj,Array)
        length(obj) > 0 ? obj : nothing
    elseif isa(obj,TayVector)
        length(obj) > 0 ? Any[obj...] : nothing
    elseif isa(obj,TayString)
        length(obj) > 0 ? [string(c) for c=obj.v.view] : nothing
    elseif obj == nothing
        nothing
    else
        error("seq: called on non-sequence")
    end
end


function with_meta(obj, meta)
    new_obj = copy(obj) # copy
    new_obj.meta = meta
    new_obj
end

ns = () -> OrderedDict{TaySymbol,Any}(
    TaySymbol("=") => (a,b) -> TayBool(equal_Q(a, b)),
    TaySymbol("throw") => (a) -> throw(TayException(a)),

    TaySymbol("nil?") => (a) -> a === nothing,
    TaySymbol("true?") => (a) -> TayBool(a.v.a8[1] === 1),
    TaySymbol("false?") => (a) -> TayBool(a.v.a8[1] === 0),
    TaySymbol("string?") => (a) -> TayBool(string_Q(a)),
    TaySymbol("Symbol") => (a) -> TaySymbol(a.v.view),
    TaySymbol("Symbol?") => (a) -> TayBool(typeof(a) === Symbol),
    TaySymbol("keyword") => (a) -> a[1] == '\u029e' ? a : "\u029e$(a)",
    TaySymbol("keyword?") => (a) -> TayBool(keyword_Q(a)),
    TaySymbol("number?") => (a) -> TayBool(isa(a, AbstractFloat) || isa(a, TayNumber)),
    TaySymbol("fn?") => (a) -> TayBool(isa(a, Function) || (isa(a, TayFunc) && !a.ismacro)),
    TaySymbol("macro?") => (a) -> TayBool(isa(a, TayFunc) && a.ismacro),

    TaySymbol("pr-str") => (a...) -> join(map((e)->pr_str(e, true),a)," "),
    TaySymbol("str") => (a...) -> TayString(join(map((e)->pr_str(e, false),a),"")),
    TaySymbol("prn") => (a...) -> println(join(map((e)->pr_str(e, true),a)," ")),
    TaySymbol("println") => (a...) -> println(join(map((e)->pr_str(e, false),a)," ")),
    TaySymbol("read-string") => (a) -> reader.read_str(a),
    # "readline") => readline_mod.do_readline,
    TaySymbol("slurp") => (a) -> readall(open(a)),

    TaySymbol("<") => (a, b) -> TayBool(a.v.view < b.v.view),
    TaySymbol("<=") => (a, b) -> TayBool(a.v.view <= b.v.view),
    TaySymbol(">") => (a, b) -> TayBool(a.v.view > b.v.view),
    TaySymbol(">=") => (a, b) -> TayBool(a.v.view >= b.v.view),
    TaySymbol("+") => (a, b) -> a.v._temp + b.v._temp,
    TaySymbol("-") => (a, b) -> a.v._temp - b.v._temp,
    TaySymbol("*") => (a, b) -> a.v._temp * b.v._temp,
    TaySymbol("/") => (a, b) -> div(a.v._temp, b.v._temp),
    TaySymbol("time-ms") => () -> round(Int, time()*1000),

    TaySymbol("list") => (a...) -> TayList(vcat(map(x -> x.list, a))),
    TaySymbol("list?") => (a) -> TayBool(isa(a, TayList)),
    TaySymbol("vector") => (a...) -> TayVector(vcat(map(x -> x.list, a))),
    TaySymbol("vector?") => (a) -> TayBool(isa(a, TayVector)),
    TaySymbol("hash-map") => (a...) -> TayHashMap(a),
    TaySymbol("map?") => (a) -> TayBool(isa(a, TayHashMap)),
    TaySymbol("assoc") => (a, b...) -> merge(a, TayHashMap(b...)),
    TaySymbol("dissoc") => (a, b...) -> foldl((x,y) -> delete!(x,y),copy(a), b),
    TaySymbol("get") => (a,b) -> a === nothing ? nothing : get(a,b,nothing),
    TaySymbol("contains?") => haskey,
    TaySymbol("keys") => (a) -> TayList([keys(a)...]),
    TaySymbol("vals") => (a) -> TayList([values(a)...]),

    TaySymbol("sequential?") => sequential_Q,
    TaySymbol("cons") => (a,b) -> TayList([Any[a]; Any[b...]]),
    TaySymbol("concat") => (a...) -> TayList(concat(a...)),
    TaySymbol("vec") => (a) -> TayVector(a.list),
    TaySymbol("nth") => (a,b) -> b+1 > length(a) ? error("nth: index out of range") : a[b+1],
    TaySymbol("first") => (a) -> a === nothing || isempty(a) ? nothing : first(a),
    TaySymbol("rest") => (a) -> a === nothing ? TayList([]) : TayList([a[2:end]...]),
    TaySymbol("empty?") => (a) -> TayBool(isempty(a)),
    TaySymbol("count") => (a) -> a == nothing ? 0 : length(a),
    TaySymbol("apply") => do_apply,
    TaySymbol("map") => do_map,

    TaySymbol("conj") => conj,
    TaySymbol("seq") => do_seq,

    TaySymbol("meta") => (a) -> isa(a,TayFunc) ? a.meta : nothing,
    TaySymbol("with-meta") => with_meta,
    TaySymbol("atom") => (a) -> Atom(a),
    TaySymbol("atom?") => (a) -> TayBool(isa(a,Atom)),
    TaySymbol("deref") => (a) -> a.val,
    TaySymbol("reset!") => (a,b) -> a.val = b,
    TaySymbol("swap!") => (a,b,c...) -> a.val = do_apply(b, a.val, c),
)

end
