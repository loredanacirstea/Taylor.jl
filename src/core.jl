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
    isa(obj,TayString) && (length(obj.v.a8) > 0 && obj.v.view[1] == '\u029e')
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
    args = concat(all_args[1:end-1], all_args[end].list)
    fn(args...)
end

function do_map(a,b)
    # map and convert to array/list
    if isa(a,TayFunc)
        collect(map(a.fn,b.list))
    else
        collect(map(a,b.list))
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
    if isa(obj,TayVector)
        length(obj.list) > 0 ? TayList(obj.list) : TayNilInstance
    elseif isa(obj,TayString)
        length(obj.v.a8) > 0 ? TayList([TayString(string(c)) for c=obj.v.view]) : TayNilInstance
    elseif is_nil(obj)
        TayNilInstance
    elseif isa(obj,Array)
        length(obj) > 0 ? obj : TayNilInstance
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
    TaySymbol("=") => (a,b) -> TayBoolean(equal_Q(a, b)),
    TaySymbol("throw") => (a) -> throw(TayException(a)),

    TaySymbol("nil?") => (a) -> isa(a, TayNil),
    TaySymbol("true?") => (a) -> TayBoolean(a.v.a8[1] == 1),
    TaySymbol("false?") => (a) -> TayBoolean(a.v.a8[1] == 0),
    TaySymbol("string?") => (a) -> TayBoolean(string_Q(a)),
    TaySymbol("symbol") => (a) -> TaySymbol(a.v.view),
    TaySymbol("symbol?") => (a) -> TayBoolean(isa(a, TaySymbol)),
    TaySymbol("keyword") => (a) -> isa(a, TayString) && a.v.view[1] == '\u029e' ? a : TayString("\u029e$(a)"),
    TaySymbol("keyword?") => (a) -> TayBoolean(keyword_Q(a)),
    TaySymbol("number?") => (a) -> TayBoolean(isa(a, AbstractFloat) || isa(a, TayNumber)),
    TaySymbol("fn?") => (a) -> TayBoolean(isa(a, Function) || (isa(a, TayFunc) && !a.ismacro)),
    TaySymbol("macro?") => (a) -> TayBoolean(isa(a, TayFunc) && a.ismacro),

    TaySymbol("pr-str") => (a...) -> TayString(join(map((e)->pr_str(e, true),a)," ")),
    TaySymbol("str") => (a...) -> TayString(join(map((e)->pr_str(e, false),a),"")),
    TaySymbol("prn") => (a...) -> println(join(map((e)->pr_str(e, true),a)," ")),
    TaySymbol("println") => (a...) -> println(join(map((e)->pr_str(e, false),a)," ")),
    TaySymbol("read-string") => (a) -> reader.read_str(a),
    # "readline") => readline_mod.do_readline,
    TaySymbol("slurp") => (a) -> readall(open(a)),

    TaySymbol("<") => (a, b) -> TayBoolean(a.v._temp < b.v._temp),
    TaySymbol("<=") => (a, b) -> TayBoolean(a.v._temp <= b.v._temp),
    TaySymbol(">") => (a, b) -> TayBoolean(a.v._temp > b.v._temp),
    TaySymbol(">=") => (a, b) -> TayBoolean(a.v._temp >= b.v._temp),
    TaySymbol("+") => (a, b) -> TayNumber(a.v._temp + b.v._temp),
    TaySymbol("-") => (a, b) -> TayNumber(a.v._temp - b.v._temp),
    TaySymbol("*") => (a, b) -> TayNumber(a.v._temp * b.v._temp),
    TaySymbol("/") => (a, b) -> TayNumber(div(a.v._temp, b.v._temp)),
    TaySymbol("time-ms") => () -> TayNumber(round(Int, time()*1000)),

    TaySymbol("list") => (a...) -> TayList([a...]),
    TaySymbol("list?") => (a) -> TayBoolean(isa(a, TayList)),
    TaySymbol("vector") => (a...) -> TayVector(collect(a)),
    TaySymbol("vector?") => (a) -> TayBoolean(isa(a, TayVector)),
    TaySymbol("hash-map") => (a...) -> TayHashMap(collect(a)),
    TaySymbol("map?") => (a) -> TayBoolean(isa(a, TayHashMap)),
    TaySymbol("assoc") => (a, b...) -> hash_map_assoc(a, collect(b)),
    TaySymbol("dissoc") => (a, b...) -> hash_map_dissoc(a, collect(b)),
    TaySymbol("get") => hash_map_get,
    TaySymbol("contains?") => hash_map_has,
    TaySymbol("keys") => (a) -> TayList([keys(a.stringMap)...]),
    TaySymbol("vals") => (a) -> TayList([values(a.stringMap)...]),

    TaySymbol("sequential?") => sequential_Q,
    TaySymbol("cons") => (a,b) -> TayList([Any[a]; Any[b.list...]]),
    TaySymbol("concat") => (a...) -> TayList(vcat([i.list for i in a]...)),
    TaySymbol("vec") => (a) -> TayVector(a.list),
    TaySymbol("nth") => (a,b) -> b.v._temp+1 > length(a.list) ? error("nth: index out of range") : a.list[b.v._temp+1],
    TaySymbol("first") => (a) -> is_nil(a) || isempty(a.list) ? TayNilInstance : first(a.list),
    TaySymbol("rest") => (a) -> is_nil(a) ? TayList([]) : TayList([a.list[2:end]...]),
    TaySymbol("empty?") => (a) -> sequential_Q(a) ? TayBoolean(isempty(a.list)) : TayBoolean(false),
    TaySymbol("count") => (a) -> is_nil(a) ? 0 : length(a.list),
    TaySymbol("apply") => do_apply,
    TaySymbol("map") => do_map,

    TaySymbol("conj") => conj,
    TaySymbol("seq") => do_seq,

    TaySymbol("meta") => (a) -> isa(a,TayFunc) ? a.meta : TayNilInstance,
    TaySymbol("with-meta") => with_meta,
    TaySymbol("atom") => (a) -> Atom(a),
    TaySymbol("atom?") => (a) -> TayBoolean(isa(a,Atom)),
    TaySymbol("deref") => (a) -> a.val,
    TaySymbol("reset!") => (a,b) -> a.val = b,
    TaySymbol("swap!") => (a,b,c...) -> a.val = do_apply(b, a.val, c),
)

end
