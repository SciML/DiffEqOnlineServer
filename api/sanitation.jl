const ALLOWED_FUNCTIONS = Set(union([:+,:-,:/,:*,:^,:\,:%,:!,:(==),:(!=),:<,:(<=),:>,:(>=),:(//)],first.(Calculus.symbolic_derivative_1arg_list)))

### Functions for checking strings before we parse/eval them

# Does it contain a function head?
expr_has_head(s, h) = false
expr_has_head(e::Expr, h::Symbol) = expr_has_head(e, Symbol[h])
function expr_has_head(e::Expr, vh::Vector{Symbol})
    in(e.head, vh) || any(a -> expr_has_head(a, vh), e.args)
end

# Does it contain a function definition?
has_function_def(s::String) = has_function_def(parse(s; raise=false))
function has_function_def(e::Expr)
    expr_has_head(e, Symbol[:(->), :function]) ||
    expr_has_head(e, Symbol[:macro]) ||
    # one line funtion definition:
    (expr_has_head(e, :(=)) && expr_has_head(e.args[], :call))
end

# Does it contain a block definition?
has_block_def(s::String) = has_block_def(parse(s; raise=false))
function has_block_def(e::Expr)
    expr_has_head(e, Symbol[:for]) ||
    expr_has_head(e, Symbol[:while]) ||
    expr_has_head(e, Symbol[:(->), :ccall]) ||
    expr_has_head(e, Symbol[:if]) ||
    expr_has_head(e, Symbol[:begin]) ||
    expr_has_head(e, Symbol[:let]) ||
    expr_has_head(e, Symbol[:do]) ||
    expr_has_head(e, Symbol[:try])
end

# Does it contain a macro using the @-form?
has_macro(s::String) = search(s,'@')!=0

# Does it call any function that's not in a whitelist of basic mathematical functions?
has_bad_call(s) = false
has_bad_call(s::String) = has_bad_call(parse(s; raise=false))
function has_bad_call(e::Expr)
    (in(e.head, Symbol[:call]) && e.args[1] ∉ ALLOWED_FUNCTIONS)|| any(a -> has_bad_call(a), e.args)
end

function sanitize_string(exstr)
  if has_function_def(exstr)
      error("Don't define functions in your system of equations...")
  end
  if has_block_def(exstr)
      error("Don't use Julia control flow blocks in your equations...")
  end
  if has_macro(exstr)
    error("Don't use macros you fowl demon. I'm watching you...")
  end
  if has_bad_call(exstr)
    error("A function which is not allowed was detected. If you're trying to be sneaky, then you're a bad person.")
  end
end
