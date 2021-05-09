module reader

export read_str

using FromFile
@from "types.jl" import types

# import types

mutable struct Reader
    tokens
    position::Int64
end

function next(rdr::Reader)
    if rdr.position > length(rdr.tokens)
        return nothing
    end
    rdr.position += 1
    rdr.tokens[rdr.position-1]
end

function peek(rdr::Reader)
    if rdr.position > length(rdr.tokens)
        return nothing
    end
    rdr.tokens[rdr.position]
end


function tokenize(str)
    re = r"[\s,]*(~@|[\[\]{}()'`~^@]|\"(?:\\.|[^\\\"])*\"?|;.*|[^\s\[\]{}('\"`,;)]*)"
    tokens = map((m) -> m.captures[1], eachmatch(re, str))
    filter((t) -> t != "" && t[1] != ';', tokens)
end

function read_atom(rdr)
    token = next(rdr)
    if match(r"^-?[0-9]+$", token) !== nothing
        types.TayNumber(parse(Int,token))
    elseif match(r"^-?[0-9][0-9.]*$", token) !== nothing
        float(token)
    elseif match(r"^\"(?:\\.|[^\\\"])*\"$", token) !== nothing
        types.TayString(replace(token[2:end-1], r"\\." => (r) -> get(Dict("\\n"=>"\n",
                                                        "\\\""=>"\"",
                                                        "\\\\"=>"\\"), r, r)))
    elseif match(r"^\".*$", token) !== nothing
        error("expected '\"', got EOF")
    elseif token[1] == ':'
        "\u029e$(token[2:end])"
    elseif token == "nil"
        types.TayNilInstance
    elseif token == "true"
        types.TayBoolean(true)
    elseif token == "false"
        types.TayBoolean(false)
    else
        types.TaySymbol(token)
    end
end

function read_list(rdr, start="(", last=")")
    ast = Any[]
    token = next(rdr)
    if (token != start)
        error("expected '$(start)'")
    end
    while ((token = peek(rdr)) != last)
        if token == nothing
            error("expected '$(last)', got EOF")
        end
        push!(ast, read_form(rdr))
    end
    next(rdr)
    types.TayList(ast)
end

function read_vector(rdr)
    lst = read_list(rdr, "[", "]")
    types.TayVector(lst.list)
end

function read_hash_map(rdr)
    lst = read_list(rdr, "{", "}")
    types.TayHashMap(lst.list)
end

function read_form(rdr)
    token = peek(rdr)
    if token == "'"
        next(rdr)
        types.TayList([types.TaySymbol("quote"); Any[read_form(rdr)]])
    elseif token == "`"
        next(rdr)
        types.TayList([types.TaySymbol("quasiquote"); Any[read_form(rdr)]])
    elseif token == "~"
        next(rdr)
        types.TayList([types.TaySymbol("unquote"); Any[read_form(rdr)]])
    elseif token == "~@"
        next(rdr)
        types.TayList([types.TaySymbol("splice-unquote"); Any[read_form(rdr)]])
    elseif token == "^"
        next(rdr)
        meta = read_form(rdr)
        types.TayList([types.TaySymbol("with-meta"); Any[read_form(rdr)]; Any[meta]])
    elseif token == "@"
        next(rdr)
        types.TayList([types.TaySymbol("deref"); Any[read_form(rdr)]])

    elseif token == ")"
        error("unexpected ')'")
    elseif token == "("
        read_list(rdr)
    elseif token == "]"
        error("unexpected ']'")
    elseif token == "["
        read_vector(rdr)
    elseif token == "}"
        error("unexpected '}'")
    elseif token == "{"
        read_hash_map(rdr)
    else
        read_atom(rdr)
    end
end

function read_str(str)
    tokens = tokenize(str)
    if length(tokens) == 0
        return types.TayNilInstance
    end
    read_form(Reader(tokens, 1))
end

end
