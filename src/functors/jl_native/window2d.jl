const WINDOW2D_FWD_F32_HANDLE = Libdl.dlsym(Native.library, :window2d_fwd_f32)
const WINDOW2D_BWD_F32_HANDLE = Libdl.dlsym(Native.library, :window2d_bwd_f32)

type Window2D <: Functor
  w1::Int
  w2::Int
  s1::Int
  s2::Int
  p1::Int
  p2::Int

  function Window2D(w1, w2, s1, s2, p1=0, p2=0)
    (s1 > 0 && s2 > 0) || throw("stride must be > 0")
    new(w1, w2, s1, s2, p1, p2)
  end
end

fwd_handle(f::Window2D, ::Type{Float32}) = WINDOW2D_FWD_F32_HANDLE
bwd_handle(f::Window2D, ::Type{Float32}) = WINDOW2D_BWD_F32_HANDLE

function forward!(f::Window2D, v::Variable)
  y, params = window2d(f, v[1].value)
  v.value = y
  v.state = params
end

function window2d{T}(f::Window2D, x::Matrix{T})
  w1, w2, s1, s2, p1, p2 = f.w1, f.w2, f.s1, f.s2, f.p1, f.p2
  w1 == -1 && w1 = size(x,1)
  w2 == -1 && w2 = size(x,2)
  n1 = (size(x,1) + 2*p1 - w1) ÷ s1 + 1
  n2 = (size(x,2) + 2*p2 - w2) ÷ s2 + 1
  params = Int32[w1, w2, s1, s2, p1, p2]
  y = Array(T, prod(w), n1*n2)
  ccall(fwd_handle(f,T), Void,
    (Ptr{T}, Ptr{Cint}, Ptr{T}, Cint, Cint),
    x, params, y, size(x,1), size(x,2))
  y, params
end

function window2d{T}(w1, w2, s1, s2, p1, p2, x::AFMatrix{T})
  w1 == -1 && w1 = size(x,1)
  w2 == -1 && w2 = size(x,2)
  y = unwrap(x, w1, w2, s1, s2, p1, p2)
  y, nothing
end

function backward!(f::Window2D, v::Variable)
  gx = ∇window2d(f, v.state, v[1].value, v.grad)
  addgrad!(v[1], gx)
end

function ∇window2d{T}(f::Window2D, params::Vector{Int32}, x::Matrix{T}, gy::Matrix{T})
  gx = zeros(T, size(x))
  ccall(bwd_handle(f,T), Void,
    (Ptr{Cint}, Ptr{T}, Ptr{T}, Cint, Cint),
    params, gy, gx, size(x,1), size(x,2))
  gx
end