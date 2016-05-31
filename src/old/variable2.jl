export Variable
export hasgrad, topsort, backward!, approx_gradient, check_gradient

type Variable{T}
  val::T
  grad::T
  f
  args::Vector{Variable}
  backward!
end

Variable(val, grad) = Variable(val, grad, nothing, Variable[], nothing)
Variable(val) = Variable(val, zeros(val))
Variable() = Variable(nothing, nothing)

function forward(f::Functor, args::Vector{Variable})
  v = Variable(nothing, nothing, f, args, nothing)
  for a in args
    a.val == nothing && return v
  end
  forward!(f, v)
  v
end

function forward(f::Functor, args::Tuple)
  vars = Variable[]
  for a in args
    v = typeof(a) == Variable ? a : Variable(a, nothing)
    push!(vars, v)
  end
  forward(f, vars)
end
forward(f::Functor, args...) = forward(f, args)

Base.getindex(v::Variable, key) = v.args[key]
Base.setindex!(v::Variable, val, key) = v.args[key] = val
Base.eltype(v::Variable) = eltype(v.val)

hasgrad(v::Variable) = v.grad != nothing

function topsort(var::Variable)
  sorted = Variable[]
  dict = ObjectIdDict()
  function visit(v::Variable)
    if !haskey(dict, v)
      dict[v] = v
      for a in v.args
        visit(a)
      end
      push!(sorted, v)
    end
  end
  visit(var)
  sorted
end

function backward!(var::Variable)
  hasgrad(var) || (var.grad = ones(var.val))
  sorted = topsort(var)
  for v in sorted
    (v == var || hasgrad(v) || v.backward! == nothing) && continue
    v.grad = zeros(v.val)
  end
  for i = length(sorted):-1:1
    v = sorted[i]
    v.backward! == nothing || v.backward!()
  end
  sorted
end

"""
Computes numerical gradient.
"""
function approx_gradient{N}(f::Functor, xs::NTuple{N,Data})
  epsilon = 1e-4
  map(xs) do x
    gx = zeros(x)
    orig = copy(x)
    for k = 1:length(x)
      x[k] = orig[k] + epsilon
      y1 = f(xs).val
      x[k] = orig[k] - epsilon
      y2 = f(xs).val
      x[k] = orig[k]
      gx[k] = sum(y1 - y2) / 2epsilon
    end
    copy!(x, orig)
    gx
  end
end
approx_gradient(f::Functor, x::Data) = approx_gradient(f, (x,))[1]

function gradient2{N}(f::Functor, xs::NTuple{N,Data})
  inputs = map(Variable, xs)
  out = f(inputs)
  gradient!(out)
  map(v -> v.grad, inputs)
end
gradient2(f::Functor, xs::Data...) = gradient2(f, xs)

"""
Check gradient.
"""
function check_gradient{N}(f::Functor, xs::NTuple{N,Data})
  inputs = map(Variable, xs)
  out = f(inputs)
  gradient!(out)
  approx_gxs = approx_gradient(f, xs)
  for i = 1:length(xs)
    gx1 = inputs[i].grad
    gx2 = approx_gxs[i]
    all(d -> abs(d) < 1e-4, gx1 - gx2) || return false
  end
  true
end
#check_gradient(f::Functor, x::Data) = check_gradient(f, (x,))
check_gradient(f::Functor, xs::Data...) = check_gradient(f, xs)