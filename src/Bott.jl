###############################################################################
#
# TnRep - n-dim representation of a torus, specified by its weights
#
struct TnRep
  n::Int
  w::Vector
  function TnRep(w::Vector{W}) where W
    # be sure to use fmpz to avoid overflow
    W == Int && return new(length(w), [ZZ(wi) for wi in w])
    new(length(w), w)
  end
end
dual(F::TnRep) = TnRep(-F.w)
+(F::TnRep, G::TnRep) = TnRep(vcat(F.w, G.w))
*(F::TnRep, G::TnRep) = TnRep([a+b for a in F.w for b in G.w])
det(F::TnRep) = TnRep([sum(F.w)])
ctop(F::TnRep) = prod(F.w)
function chern(n::Int, F::TnRep)
  sum([prod([F.w[i] for i in c], init=ZZ(1)) for c in combinations(F.n, n)], init=ZZ())
end
function _sym(k::Int, n::Int)
  k == 0 && return [Int[]]
  vcat([[push!(c, i) for c in _sym(k-1,i)] for i in 1:n]...)
end
function symmetric_power(k::Int, F::TnRep)
  TnRep([sum([F.w[i] for i in c], init=ZZ()) for c in _sym(k, F.n)])
end
function exterior_power(k::Int, F::TnRep)
  TnRep([sum([F.w[i] for i in c], init=ZZ()) for c in combinations(F.n, k)])
end

###############################################################################
#
# TnBundle, TnVariety - varieties with a torus action and equivariant bundles
#
# A Tⁿ-variety X is represented as the set of fixed points X.points, each
# labelled using some value of type P (e.g. an array), and has a multiplicty e
# (orbifold multiplicty);
# 
# A Tⁿ-equivariant bundle on X is represented by its localization/restriction
# to each of the points in X.points, which will be of type `TnRep`.
# They are stored as a function to allow lazy evaluation: this is crucial for
# large examples, since otherwise we may run into memory problems.
abstract type TnVarietyT{P} <: Variety end

mutable struct TnBundle{P, V <: TnVarietyT{P}} <: Sheaf
  parent::V
  rank::Int
  loc::Function
  @declare_other
  function TnBundle(X::V, r::Int) where V <: TnVarietyT
    P = V.parameters[1]
    new{P, V}(X, r)
  end
  function TnBundle(X::V, r::Int, f::Function) where V <: TnVarietyT
    P = V.parameters[1]
    new{P, V}(X, r, f)
  end
end

mutable struct TnVariety{P} <: TnVarietyT{P}
  dim::Int
  points::Vector{Pair{P, Int}}
  T::TnBundle
  bundles::Vector{TnBundle}
  @declare_other
  function TnVariety(n::Int, points::Vector{Pair{P, Int}}) where P
    new{P}(n, points)
  end
end

euler(X::TnVariety) = sum(1//ZZ(e) for (p,e) in X.points) # special case of Bott's formula

dual(F::TnBundle) = TnBundle(F.parent, F.rank, p -> dual(F.loc(p)))
+(F::TnBundle, G::TnBundle) = TnBundle(F.parent, F.rank + G.rank, p -> F.loc(p) + G.loc(p))
*(F::TnBundle, G::TnBundle) = TnBundle(F.parent, F.rank * G.rank, p -> F.loc(p) * G.loc(p))
det(F::TnBundle) = TnBundle(F.parent, 1, p -> det(F.loc(p)))
symmetric_power(k::Int, F::TnBundle) = TnBundle(F.parent, binomial(F.rank+k-1, k), p -> symmetric_power(k, F.loc(p)))
exterior_power(k::Int, F::TnBundle) = TnBundle(F.parent, binomial(F.rank, k), p -> exterior_power(k, F.loc(p)))

# we want the same syntax `integral(chern(F))` as in Schubert calculus
# the following ad hoc type represents a formal expressions in chern classes of a bundle F
struct TnBundleChern
  F::TnBundle
  c::ChRingElem
end
for O in [:(+), :(-), :(*)]
  @eval $O(a::TnBundleChern, b::TnBundleChern) = (
    @assert a.F == b.F;
    TnBundleChern(a.F, $O(a.c, b.c)))
end
^(a::TnBundleChern, n::Int) = TnBundleChern(a.F, a.c^n)
*(a::TnBundleChern, n::Scalar) = TnBundleChern(a.F, a.c*n)
*(n::Scalar, a::TnBundleChern) = TnBundleChern(a.F, n*a.c)
Base.show(io::IO, c::TnBundleChern) = print(io, "Chern class $(c.c) of $(c.F)")

# create a ring to hold the chern classes of F
function _get_ring(F::TnBundle)
  if get_special(F, :R) === nothing
    r = min(F.parent.dim, F.rank)
    R = Nemo.PolynomialRing(QQ, _parse_symbol("c", 1:r))[1]
    Ch = ChRing(R, collect(1:r), :variety_dim => F.parent.dim)
    set_special(F, :R => Ch)
  end
  get_special(F, :R)
end

chern(F::TnBundle) = TnBundleChern(F, 1+sum(gens(_get_ring(F))))
chern(k::Int, F::TnBundle) = TnBundleChern(F, chern(F).c[k])
ctop(F::TnBundle) = chern(F.rank, F)
chern(F::TnBundle, x::RingElem) = begin
  R = _get_ring(F)
  @assert length(gens(R)) == length(gens(parent(x)))
  TnBundleChern(F, R.(Nemo.evaluate(x, [c.f for c in gens(R)])))
end

function integral(c::TnBundleChern)
  F, R = c.F, parent(c.c)
  X = F.parent
  n, r = X.dim, length(gens(R))
  top = c.c[n].f
  top == 0 && return QQ()
  exp_vec = sum(Singular.exponent_vectors(top))
  idx = filter(i -> exp_vec[i] > 0, 1:r)
  ans = 0
  for (p,e) in X.points # Bott's formula
    cherns = [i in idx ? chern(i, F.loc(p)) : ZZ() for i in 1:r]
    ans += top(cherns...) * (1 // (e * ctop(X.T.loc(p))))
  end
  ans
end

###############################################################################
#
# Grassmannians and flag varieties
#
# utility function that parses the weight specification
function _parse_weight(n::Int, w)
  w == :int && return ZZ.(collect(1:n))
  w == :poly && return Nemo.PolynomialRing(QQ, ["u$i" for i in 1:n])[2]
  if isa(w, UnitRange) w = collect(w) end
  isa(w, Vector) && length(w) == n && return w
  error("incorrect specification for weights")
end

function tn_grassmannian(k::Int, n::Int; weights=:int)
  @assert k < n
  points = [p=>1 for p in combinations(n, k)]
  d = k*(n-k)
  G = TnVariety(d, points)
  w = _parse_weight(n, weights)
  S = TnBundle(G, k, p -> TnRep([w[i] for i in p]))
  Q = TnBundle(G, n-k, p -> TnRep([w[i] for i in setdiff(1:n, p)]))
  G.bundles = [S, Q]
  G.T = dual(S) * Q
  set_special(G, :description => "Grassmannian Gr($k, $n)")
  return G
end

function tn_flag(dims::Vector{Int}; weights=:int)
  n, l = dims[end], length(dims)
  ranks = pushfirst!([dims[i+1]-dims[i] for i in 1:l-1], dims[1])
  @assert all(r->r>0, ranks)
  d = sum(ranks[i] * sum(dims[end]-dims[i]) for i in 1:l-1)
  function enum(i::Int, rest::Vector{Int})
    i == l && return [[rest]]
    [pushfirst!(y, x) for x in combinations(rest, ranks[i]) for y in enum(i+1, setdiff(rest, x))]
  end
  points = [p=>1 for p in enum(1, collect(1:n))]
  Fl = TnVariety(d, points)
  w = _parse_weight(n, weights)
  Fl.bundles = [TnBundle(Fl, r, p -> TnRep([w[j] for j in p[i]])) for (i, r) in enumerate(ranks)]
  Fl.T = sum(dual(Fl.bundles[i]) * sum([Fl.bundles[j] for j in i+1:l]) for i in 1:l-1)
  set_special(Fl, :description => "Flag variety Flag$(tuple(dims...))")
  return Fl
end
