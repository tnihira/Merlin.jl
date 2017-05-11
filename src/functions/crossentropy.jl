export crossentropy

"""
    crossentropy(p::Var, q::Var)

Returns cross-entropy between p and q.
When p[i] == 0, returns 0.

* p: Var of Vector{Int} or Matrix{Float}
* q: Var of Matrix{Float}

```julia
p = Var(rand(0:10,5))
q = Var(rand(Float32,10,5))
y = crossentropy(p, q)
```
"""
function crossentropy(p::Var, q::Var, softmax=true)
    y = Var(nothing, crossentropy, (p,q))
    softmax ? softmax_crossentropy!(y,p.data,q.data) : crossentropy!(y,p.data,q.data)
    y
end

function crossentropy!{T}(out::Var, p::Array{Int}, q::Array{T})
    size(p,1) == 1 || throw(DimensionMismatch("size(p,1) != 1"))
    size(p,2) == size(q,2) || throw(DimensionMismatch("size of p: $(size(p)), size of q: $(size(q))"))
    y = Array{T}(1, length(p))
    @inbounds @simd for j = 1:length(p)
        y[j] = p[j] > 0 ? -log(q[p[j],j]) : T(0)
    end
    out.data = y
    out.df! = function df!()
        isvoid(out[2].grad) || ∇crossentropy!(out.grad, p, q, out[2].grad)
    end
end

function softmax_crossentropy!{T}(out::Var, p::Array{Int}, q::Array{T})
    logq = logsoftmax(q)
    size(p,1) == 1 || throw(DimensionMismatch("size(p,1) != 1"))
    size(p,2) == size(logq,2) || throw(DimensionMismatch("size of p: $(size(p)), size of logq: $(size(logq))"))
    y = Array{T}(1, length(p))
    @inbounds @simd for j = 1:length(p)
        y[j] = p[j] > 0 ? -logq[p[j],j] : T(0)
    end
    out.data = y
    out.df! = function df!()
        isvoid(out[2].grad) || ∇softmax_crossentropy!(out.grad, p, logq, out[2].grad)
    end
end

@generated function crossentropy{T}(p::CuVector{Int32}, logq::CuMatrix{T})
    f = CuFunction("""
    __global__ void f($T *y, $int *p, Array<$T,2> logq) {
        int idx = blockIdx.x * blockDim.x + threadIdx.x;
        if (idx < logq.dims[1]) {
            y[idx] = p[idx] > 0 ? -logq(p[idx]-1,idx) : 0;
        }
    }""")
    quote
        length(p) == size(logq,2) || throw(DimensionMismatch())
        y = CuArray{T}(1, length(p))
        $f(y.ptr, p.ptr, logq, dx=length(p))
        y
    end
end

function ∇crossentropy!{T}(gy::Matrix{T}, p::Matrix{Int}, q::Matrix{T}, gq::Matrix{T})
    @inbounds @simd for j = 1:length(p)
        if p[j] > 0
            if q[p[j],j] < T(-1e-10) || q[p[j],j] > T(1e-10)
                gq[p[j],j] -= T(1) / q[p[j],j]
            end
        end
    end
end

function ∇softmax_crossentropy!{T}(gy::Matrix{T}, p::Matrix{Int}, logq::Matrix{T}, gq::Matrix{T})
    for j = 1:length(p)
        g = gy[j]
        @inbounds @simd for i = 1:size(logq,1)
            if p[j] > 0
                delta = ifelse(i == p[j], T(1), T(0))
                gq[i,j] += g * (exp(logq[i,j]) - delta)
            end
        end
    end
end

@generated function ∇softmax_crossentropy!{T}(gy::CuMatrix{T}, p::CuVector{Int32}, logq::CuMatrix{T}, gq::CuMatrix{T})
    f = CuFunction("""
    __global__ void f($T *gy, $T *p, Array<$T,2> logq, Array<$T,2> gq) {
        int idx = blockIdx.x * blockDim.x + threadIdx.x;
        if (idx >= logq.length()) return;

        int subs[2];
        logq.idx2sub(subs);
        int i = subs[0];
        int j = subs[1];
        if (p[j] > 0) {
            $T delta = (i == p[j]-1) ? 1 : 0;
            gq(i,j) += gy[j] * (exp(logq(i,j)) - delta);
        }
    }""")
    quote
        $f(gy.ptr, p.ptr, logq, gq, dx=length(logq))
    end
end

function softmax_crossentropy{T}(p::Matrix{T}, logq::Matrix{T})
    y = Array(T, 1, size(p,2))
    for j = 1:size(p,2)
        s = T(0)
        @inbounds @simd for i = 1:size(p,1)
            s += -p[i,j] * logq[i,j]
        end
        y[j] = s
    end
    y
end

function ∇softmax_crossentropy!{T}(gy::Matrix{T}, p::Matrix{T}, logq::Matrix{T}, gq::Matrix{T})
    for j = 1:size(p,2)
        g = gy[j]
        @inbounds @simd for i = 1:size(p,1)
            gq[i,j] += g * (exp(logq[i,j]) - p[i,j])
        end
    end
end
