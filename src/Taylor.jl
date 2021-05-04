module Taylor

push!(LOAD_PATH, pwd(), "/usr/share/julia/base")

using FromFile
@from "utils.jl" import utils
@from "types.jl" import types: TaySymbol, TayType, TayList, TayException, TayFunc, TayString, TayList, serialize
@from "reader.jl" import reader
@from "printer.jl" import printer
@from "env.jl" using env
@from "core.jl" import core

export EVAL, PRINT, READ, REP, repl_env, init, serialize, utils

# READ
function READ(str)
    reader.read_str(str)
end

function starts_with(lst::Vector{TayType}, sym::AbstractString)::Bool
    if length(lst) == 2
        a0 = lst[1]
        if a0.type == NodeSymbol && a0.v.view === "splice-unquote"
            return true
        end
    end
    false
end

# EVAL
function quasiquote_loop(elt::TayType, acc::TayList)
    if isa(elt, TayList) && starts_with(elt.list, "splice-unquote")
        acc = TayList([TaySymbol("concat"), elt[2], acc])
    else
        acc = TayList([TaySymbol("cons"), quasiquote(elt), acc])
    end
    acc
end

function quasiquote_foldr(elts::Vector{TayType})::TayList
    acc = TayList([])
    for i in length(elts):-1:1
        elt = elts[i]
        acc = quasiquote_loop(elt, acc)
    end
    return acc
end

function quasiquote(ast)
    if isa(ast, TaySymbol)
        TayList([TaySymbol("quote"), ast])
    elseif isa(ast, Dict)
        TayList([TaySymbol("quote"), ast])
    elseif isa(ast, TayList)
        if starts_with(ast, "unquote")
            ast[2]
        else
            quasiquote_foldr(ast.list)
        end
    elseif isa(ast, Tuple)
        Any[TaySymbol("vec"), quasiquote_foldr(ast)]
    else
        ast
    end
end

function ismacroCall(ast, env)
    return isa(ast, TayList) &&
           !isempty(ast.list) &&
           isa(ast.list[1], TaySymbol) &&
           env_find(env, ast.list[1]) != nothing &&
           isa(env_get(env, ast.list[1]), TayFunc) &&
           env_get(env, ast.list[1]).ismacro
end

function macroexpand(ast, env)
    while ismacroCall(ast, env)
        mac = env_get(env, ast.list[1])
        ast = mac.fn(ast.list[2:end]...)
    end
    ast
end

function eval_ast(ast, env)
    if isa(ast, TaySymbol)
        env_get(env,ast)
    elseif isa(ast, TayList)
        TayList(map((x) -> EVAL(x,env), ast.list))
    elseif isa(ast, Array) || isa(ast, Tuple)
        TayList(map((x) -> EVAL(x,env), ast))
    elseif isa(ast, Dict)
        [EVAL(x[1],env) => EVAL(x[2], env) for x=ast]
    else
        ast
    end
end

function EVAL(ast, env)
  while true
    #println("EVAL: $(printer.pr_str(ast,true))")
    if !isa(ast, TayList) return eval_ast(ast, env) end

    # apply
    ast = macroexpand(ast, env)
    if !isa(ast, TayList) return eval_ast(ast, env) end
    if isempty(ast.list) return ast end
    ast = ast.list

    if     "def!" == ast[1].v.view
        return env_set(env, ast[2], EVAL(ast[3], env))
    elseif "let*" == ast[1].v.view
        let_env = Env(env)
        for i = 1:2:length(ast[2])
            env_set(let_env, ast[2][i], EVAL(ast[2][i+1], let_env))
        end
        env = let_env
        ast = ast[3]
        # TCO loop
    elseif "quote" == ast[1].v.view
        return ast[2]
    elseif "quasiquoteexpand" == ast[1].v.view
        return quasiquote(ast[2])
    elseif "quasiquote" == ast[1].v.view
        ast = quasiquote(ast[2])
        # TCO loop
    elseif "defmacro!" == ast[1].v.view
        func = EVAL(ast[3], env)
        func.ismacro = true
        return env_set(env, ast[2], func)
    elseif "macroexpand" == ast[1].v.view
        return macroexpand(ast[2], env)
    elseif "try*" == ast[1].v.view
        try
            return EVAL(ast[2], env)
        catch exc
            e = string(exc)
            if isa(exc, TayException)
                e = exc.tayval
            elseif isa(exc, ErrorException)
                e = exc.msg
            else
                e = string(e)
            end
            if length(ast) > 2 && ast[3][1] == Symbol("catch*")
                return EVAL(ast[3][3], Env(env, Any[ast[3][2]], Any[e]))
            else
                rethrow(exc)
            end
        end
    elseif "do" == ast[1].v.view
        eval_ast(ast[2:end-1], env)
        ast = ast[end]
        # TCO loop
    elseif "if" == ast[1].v.view
        cond = EVAL(ast[2], env)
        if cond === nothing || cond === false
            if length(ast) >= 4
                ast = ast[4]
                # TCO loop
            else
                return nothing
            end
        else
            ast = ast[3]
            # TCO loop
        end
    elseif "fn*" == ast[1].v.view
        return TayFunc(
            (args...) -> EVAL(ast[3], Env(env, ast[2], Any[args...])),
            ast[3], env, ast[2])
    else
        el = eval_ast(ast, env)
        list = isa(el, TayList) ? el.list : el
        f, args = list[1], list[2:end]
        if isa(f, TayFunc)
            ast = f.ast
            env = Env(f.env, f.params, args)
            # TCO loop
        else
            return f(args...)
        end
    end
  end
end

# PRINT
function PRINT(exp)
    printer.pr_str(exp)
end

# REPL
repl_env = nothing
function REP(str)
    return PRINT(EVAL(READ(str), repl_env))
end

function init()
    # core.jl: defined using Julia
    global repl_env = Env(nothing, core.ns())
    env_set(repl_env, TaySymbol("eval"), (ast) -> EVAL(ast, repl_env))
    env_set(repl_env, TaySymbol("*ARGV*"), ARGS[2:end])

    # core.tay: defined using the language itself
    REP("(def! *host-language* \"julia\")")
    REP("(def! not (fn* (a) (if a false true)))")
    REP("(def! load-file (fn* (f) (eval (read-string (str \"(do \" (slurp f) \"\nnil)\")))))")
    REP("(defmacro! cond (fn* (& xs) (if (> (count xs) 0) (list 'if (first xs) (if (> (count xs) 1) (nth xs 1) (throw \"odd number of forms to cond\")) (cons 'cond (rest (rest xs)))))))")
end

# if length(ARGS) > 0
#     REP("(load-file \"$(ARGS[1])\")")
#     exit(0)
# end

# REP("(println (str \"Tay [\" *host-language* \"]\"))")
# while true
#     line = readline_mod.do_readline("user> ")
#     if line === nothing break end
#     try
#         println(REP(line))
#     catch e
#         if isa(e, ErrorException)
#             println("Error: $(e.msg)")
#         else
#             println("Error: $(string(e))")
#         end
#         # TODO: show at least part of stack
#         if !isa(e, StackOverflowError)
#             bt = catch_backtrace()
#             Base.show_backtrace(stderr, bt)
#         end
#         println()
#     end
# end




end
