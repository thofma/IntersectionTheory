```@meta
CurrentModule = IntersectionTheory
DocTestSetup = quote
  using IntersectionTheory
end
```
```@setup repl
using IntersectionTheory
```
# Constructors
## Generic varieties
The following constructors are available for building generic varieties.
```@docs
variety
```
### Examples
```@repl repl
X = variety(2, ["h", "c1", "c2"], [1, 1, 2])
Y, (E,) = variety(2, [3 => "c"])
chern(E)
Z = variety(2)
chern(tangent_bundle(Z))
```
!!! note
    The generic varieties are created without any relations by default. There
    are of course trivial relations due to dimension (i.e., all classes with
    codimension larger than the dimension of the variety must be zero). Use
    `trim!` on the Chow ring will add these relations and make the quotient
    ring Artinian. Then we will be able to compute `basis`, `betti`, and
    related things.

## Projective spaces, Grassmannians, flag varieties
The following constructors are available.

```@docs
point
proj(n::Int)
grassmannian(k::Int, n::Int; bott::Bool=false)
flag(dims::Int...; bott::Bool=false)
```
!!! note
    Mathematically $\mathrm{Fl}(k, n)$ is exactly the same as $\mathrm{Gr}(k,
    n)$. The difference is that the Chow ring returned by `grassmannian` uses
    only $k$ generators instead of $n$.

### Examples
```@repl repl
proj(2)
grassmannian(2, 4)
grassmannian(2, 4, bott=true)
flag(1, 3, 5)
flag([1, 3, 5])
```
For all the above constructors, the `base` argument can be used to introduce
parameters using Singular's `FunctionField`.
```@repl repl
F, (k,) = FunctionField(Singular.QQ, ["k"]);
P2 = proj(2, base=F);
chi(OO(P2, k))
symmetric_power(k, 2OO(P2))
```

## Projective bundles, relative flag varieties
In the relative setting, the following constructors are available.
```@docs
proj(F::AbsBundle)
flag(d::Int, F::AbsBundle)
```

## Moduli spaces of matrices, parameter spaces of twisted cubics
```@docs
matrix_moduli
twisted_cubics
twisted_cubics_on_quintic_threefold
twisted_cubics_on_cubic_fourfold
```
!!! warning
    The various `twisted_cubics` functions produce the same result as *Chow*,
    however I cannot reproduce the intersection numbers found by Schubert.
    More investigation is needed.

## Others
```@docs
linear_subspaces_on_hypersurface
```
### Examples
```@repl repl
IntersectionTheory.linear_subspaces_on_hypersurface(1, 3)
```

