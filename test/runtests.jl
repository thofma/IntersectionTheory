using IntersectionTheory
using Test

@testset "ChRing" begin

  R, (x0,) = PolynomialRing(Singular.QQ, ["x"])
  A = IntersectionTheory.ChRing(R, [1])
  @test A isa IntersectionTheory.ChRing
  @test A(1) isa IntersectionTheory.ChRingElem
  x = gens(A)[1]
  @test x == x0
  @test x.f isa Singular.spoly
  @test total_degree(x) == 1
  @test (x + x^3)[1] == x
  @test (x + x^3)[1:3] == [x, A(0), x^3]
  A.I = Singular.std(Singular.Ideal(R, x0^4))
  @test simplify(x^4).f == 0
  @test x^4 == 0
  @test div(x^4, x^3) == 0
  IntersectionTheory.add_rels!(A, [x.f^3])
  x3 = A(x0^3)
  @test x3 == 0
  @test x3.f == x0^3
  @test simplify!(x3) == 0
  @test x3.f == 0
  
  R, (x0, y0) = PolynomialRing(Singular.QQ, ["x", "y"])
  A = IntersectionTheory.ChRing(R, [1, 2])
  x, y = gens(A)
  @test total_degree(y) == 2
  @test (x + x^2 + y)[2] == x^2 + y
  @test ishomogeneous(x^2 + y)
  @test !ishomogeneous(x + y)
  Nemo.AbstractAlgebra.set_special(A, :variety_dim => 2)
  trim!(A)
  @test simplify(x^3) == 0

end

@testset "GenericVariety" begin
  
  # generic variety
  C = variety(1)
  c = gens(C.ring)[1]
  @test C.T === tangent_bundle(C)
  @test rank(C.T) isa Int
  @test chern(C.T) == 1 + c
  trim!(C.ring)
  @test Singular.dimension(C.ring.I) == 0
  @test parent(c) == C.ring
  @test betti(C) == [1, 1]
  @test basis(C) == [[C.ring(1)], [c]]
  @test euler(C) == c
  @test chi(OO(C)) == 1//2 * c

  # generic variety with parameter
  F, (g,) = FunctionField(Singular.QQ, ["g"])
  C = variety(1, base=F)
  c = gens(C.ring)[1]
  trim!(C.ring)
  C.point = 1//(2 - 2g) * chern(1, C)
  @test euler(C) == 2 - 2g
  @test rank(OO(C) * g) == g
  @test rank(symmetric_power(g, 2OO(C))) == g + 1

  # generic variety with bundles
  X, (A, B) = variety(2, [3=>"a", 3=>"b"])
  @test schur_functor([1,1], A) == exterior_power(2, A)
  @test schur_functor([2], A) == symmetric_power(2, A)
  D = degeneracy_locus(2, A, B)
  @test pushforward(D → X, D(1)) == degeneracy_locus(2, A, B, class=true)

  # characteristic classes
  t = todd(2)
  c = gens(parent(t))
  @test t == 1//12 * c[1]^2 + 1//12 * c[2]
  l = l_genus(2)
  p = gens(parent(l))
  @test l == -1//45 * p[1]^2 + 7//45 * p[2]
  a = a_hat_genus(2)
  p = gens(parent(a))
  @test a == 7//5760 * p[1]^2 - 1//1440 * p[2]
  
end

@testset "VarietyHom" begin

  p = point()
  P2 = proj(2)
  i = P2 → P2
  @test i.domain == P2
  @test i.codomain == P2

  i = p → P2
  @test pushforward(i, p(1)) == P2.point
  @test pullback(i, P2.O1) == 0
  @test i.T === tangent_bundle(i)
  @test -i.T == 2OO(p) # normal bundle

  # test that coercion works properly
  pt = P2.struct_map.codomain
  A = OO(P2) * OO(pt)
  @test parent(A) == P2
  @test A == OO(P2)

  PF = proj(P2.bundles[2])
  A = OO(P2) + OO(PF)
  @test parent(A) == PF
  @test A == 2OO(PF)

  # test that hom works for blowup
  Bl, E = blowup(i)
  e = pushforward(E → Bl, E(1))
  @test e == gens(Bl.ring)[1]
  @test integral(e^2) == -1
  @test pullback(E → p, p(1)) == E(1)

  P5 = proj(5, symbol="H")
  h, H = P2.O1, P5.O1
  v = hom(P2, P5, [2h])
  @test pullback(v, H) == 2h
  @test pullback(v, P5.point) == 0
  @test v.pushforward(h) == 2H^4
  @test pushforward(v, P2.point) == P5.point
  @test -v.T == bundle(P2, 3, 1 + 9h + 30h^2) # normal bundle

  # test that hom works for product
  P, Q = proj(1), proj(1)
  PxQ = P * Q
  p, q = PxQ → P, PxQ → Q
  @test pushforward(p, PxQ.point) == P.point
  @test integral(pullback(p, P.point) * pullback(q, Q.point)) == 1

  # cubic containing a plane
  P2 = proj(2)
  Y = complete_intersection(proj(5), 3)
  i = hom(P2, Y, [P2.O1], inclusion=true)
  Y1 = i.codomain
  p = pushforward(i, P2(1))
  h = Y1.O1
  @test Y1 != Y
  @test euler(Y1) == euler(Y)
  @test (Y1 → Y).T.ch == 0
  @test betti(Y1)[3] == 2
  @test basis(2, Y1) == [h^2, p]
  @test intersection_matrix([h^2, p]) == Nemo.matrix(QQ, [3 1; 1 3])

  # a related result:
  # the degree of the hypersurface of cubics containing a plane
  G = grassmannian(3, 6)
  S = G.bundles[1]
  @test integral(chern(symmetric_power(3, dual(S)))) == 3402

end

@testset "Constructors" begin
  
  # proj(2)
  P2 = proj(2)
  h = P2.O1
  S, Q = P2.bundles
  @test gens(P2.ring.I) == [h^3]
  @test h^3 == 0
  @test P2.point == h^2
  @test S == OO(P2, -1)
  @test Q == bundle(P2, 2, 1 + h + h^2)
  @test Q == bundle(P2, 2 + h - 1//2*h^2)
  @test hom(S, Q) == P2.T
  @test euler(P2) == 3
  @test chern(P2) == 1 + 3h + 3h^2
  @test chern(1, P2) == 3h
  @test ctop(P2.T) == chern(2, P2)
  @test segre(P2.T) == 1 - 3h + 6h^2
  @test segre(2, P2.T) == 6h^2
  @test todd(P2) == 1 + 3//2*h + h^2
  @test integral(todd(P2)) == 1
  @test pontryagin(P2) == 1 + 3h^2
  @test pontryagin(1, P2) == 3h^2
  @test a_hat_genus(P2) == -1//8
  @test signature(P2) == 1
  @test chern_number(P2, 2) == 3
  @test chern_numbers(P2) == [Nemo.Partition([2]) => 3, Nemo.Partition([1,1]) => 9]
  @test chi(OO(P2)) == 1
  @test chi(cotangent_bundle(P2)) == -1
  hilb = hilbert_polynomial(P2)
  t = gens(parent(hilb))[1]
  @test hilb isa Singular.spoly{Singular.n_Q}
  @test hilb == 1 + 3//2*t + 1//2*t^2

  # Grassmannian
  G = grassmannian(2, 4)
  S, Q = bundles(G)
  c1, c2 = gens(G.ring)
  @test betti(G) == [1,1,2,1,1]
  @test euler(G) == 6
  @test chern(1, G) == -4chern(1, S)
  @test integral(chern(symmetric_power(3, dual(S)))) == 27
  @test integral(chern(1, dual(S))^4) == 2
  @test integral(chern(2, G)^2) == 98
  @test schubert_class(G, 2) == c1^2-c2
  @test schubert_class(G, [1, 1]) == c2
  @test schubert_class(G, Nemo.Partition([2, 1])) == -c1^3 + c1 * c2
  @test [length(schubert_classes(i, G)) for i in 0:4] == [1,1,2,1,1]

  # Grassmannian: TnVariety version
  G = grassmannian(2, 4, bott=true)
  S, Q = bundles(G)
  @test G isa IntersectionTheory.TnVariety
  @test S isa IntersectionTheory.TnBundle
  @test rank(tangent_bundle(G)) == 4
  @test euler(G) == 6
  @test integral(chern(symmetric_power(3, dual(S)))) == 27
  @test integral(chern(1, dual(S))^4) == 2
  @test integral(chern(2, G)^2) == 98

  # flag variety
  F = flag(1, 2, 3)
  A, B, C = bundles(F)
  @test dim(F) == 3
  @test rank.(bundles(F)) == [1, 1, 1]
  @test betti(F) == [1,2,2,1]
  @test euler(F) == 6

  # flag variety: TnVariety version
  F = flag(1, 2, 3, bott=true)
  A, B, C = bundles(F)
  @test dim(F) == 3
  @test rank.(bundles(F)) == [1, 1, 1]
  @test euler(F) == 6

  # projective bundle
  X, (F,) = variety(3, [3=>"c"])
  PF = proj(F)
  @test dim(PF) == 5
  @test rank.(bundles(PF)) == [1, 2]
  p = PF.struct_map
  @test p.codomain == X
  @test pullback(p, X(1)) == 1
  @test pushforward(p, PF(1)) == 0
  @test pushforward(p, p.O1^2) == 1
  
  # flag bundle
  X, (F,) = variety(2, [4=>"c"])
  FlF = flag(2, F)
  @test dim(FlF) == 6
  @test rank.(bundles(FlF)) == [2, 2]
  p = FlF.struct_map
  @test p.codomain == X
  @test pullback(p, X(1)) == 1
  @test pushforward(p, FlF(1)) == 0
  @test pushforward(p, p.O1^4) == 2
  @test [length(schubert_classes(i, FlF)) for i in 0:4] == [1,1,2,1,1]

end

@testset "Pushfwd" begin
  A = IntersectionTheory.ChRing(PolynomialRing(Singular.QQ, ["x","y","z","w"])[1], [3,3,3,3])
  B = IntersectionTheory.ChRing(PolynomialRing(Singular.QQ, ["s","t"])[1], [1,1])
  s, t = gens(B)
  f = IntersectionTheory.ChAlgHom(A, B, [s^3,s^2*t,s*t^2,t^3]) # twisted cubic
  M, g, pf = IntersectionTheory._pushfwd(f)
  @test length(g) == 6
  x = s^3 + 5s*t + t^20 # random element from B
  @test g' * f.salg.(pf(x.f)) == x.f
   
  A = IntersectionTheory.ChRing(PolynomialRing(Singular.QQ, ["x","y","z","w"])[1], [4,4,2,1])
  B = IntersectionTheory.ChRing(PolynomialRing(Singular.QQ, ["s","t","u"])[1], [1,1,1])
  s, t, u = gens(B)
  f = IntersectionTheory.ChAlgHom(A, B, [s^4+u^4,s*t^2*u,s^2-t^2-u^2,t]) # random morphism
  M, g, pf = IntersectionTheory._pushfwd(f)
  @test length(g) == 8
  x = s^2 + 2s*t + 3s*t*u + t^2*u + 20t*u + u^20 # random element from B
  @test g' * f.salg.(pf(x.f)) == x.f
end

# testset borrowed from Schubert2
@testset "Blowup" begin
  
  # blowup Veronese
  P2 = proj(2)
  P5 = proj(5)
  v = hom(P2, P5, [2P2.O1])
  Bl, E = blowup(v)
  c = ctop(tangent_bundle(Bl))
  @test integral(pushforward(Bl → P5, c)) == 12
  @test integral(c) == 12
  e = pushforward(E → Bl, E(1))
  quad = pullback(Bl → P5, 2P5.O1) - e
  @test integral(quad^5) == 1
  sext = pullback(Bl → P5, 6P5.O1) - 2e
  @test integral(sext^5) == 3264
  
  # blowup point in P2
  P2 = proj(2)
  Bl, E = blowup(point() → P2)
  e = pushforward(E → Bl, E(1))
  @test integral(e^2) == -1
  @test integral(pullback(E → Bl, e)) == -1
  @test euler(Bl) == 4

  # blowup point in P7
  P7 = proj(7)
  Bl, E = blowup(point() → P7)
  e = pushforward(E → Bl, E(1))
  @test euler(Bl) == 14
  
  # blowup twisted cubic
  P1 = proj(1)
  P3 = proj(3)
  i = hom(P1, P3, [3P1.O1])
  Bl, E = blowup(i)
  e = pushforward(E → Bl, E(1))
  quad = pullback(Bl → P3, 2P3.O1) - e
  @test integral(quad^3) == 0
  cubic = pullback(Bl → P3, 3P3.O1) - e
  @test integral(quad^2 * cubic) == 1
  
  # blowup twisted cubic, with parameters
  F, (r, s, t) = FunctionField(Singular.QQ, ["r", "s", "t"])
  P1 = proj(1, base=F)
  P3 = proj(3, base=F)
  i = hom(P1, P3, [3P1.O1])
  Bl, E = blowup(i)
  e = pushforward(E → Bl, E(1))
  rH, sH, tH = [pullback(Bl → P3, x * P3.O1) - e for x in [r,s,t]]
  @test integral(rH * sH * tH) == r*s*t - 3*r - 3*s - 3*t + 10

  G = grassmannian(2, 5)
  P9 = proj(9)
  i = hom(G, P9, [G.O1])
  Bl, E = blowup(i)
  e = pushforward(E → Bl, E(1))
  quad = pullback(Bl → P9, 2P9.O1) - e
  @test simplify(quad^5) == 0
  @test simplify(e^5) != 0
  
  # blowup space curve of degree d and genus g
  F, (r,s,t,d,g) = FunctionField(Singular.QQ, ["r", "s", "t", "d", "g"])
  P3 = proj(3, base=F)
  C = variety(1, base=F)
  trim!(C.ring)
  C.point = 1//(2-2g) * chern(1, C)
  i = hom(C, P3, [d * C.point])
  Bl, E = blowup(i)
  e = pushforward(E → Bl, E(1))
  rH, sH, tH = [pullback(Bl → P3, x * P3.O1) - e for x in [r,s,t]]
  @test integral(rH * sH * tH) == r*s*t - d*(r+s+t) + (2g-2+4d)
  
  G = grassmannian(2, 5)
  Z = section_zero_locus(3OO(G, 1))
  Bl, E = blowup(Z → G)
  @test dim(Bl) == 6
  @test euler(Bl) == 18
  @test betti(Bl) == [1,2,4,4,4,2,1]
  @test [chi(exterior_power(i, cotangent_bundle(Bl))) for i in 0:6] == [1,-2,4,-4,4,-2,1]

end

@testset "Moduli" begin
  
  M = matrix_moduli(5, 1, 2)
  @test betti(M) == betti(grassmannian(2, 5))
  @test euler(M) == 10
  
  M = matrix_moduli(4, 2, 3)
  @test betti(M) == [1,1,3,4,7,8,10,8,7,4,3,1,1]
  f = q -> QQ(1//6)*q*(q-1)*(3q^2-5q+1)
  @test euler(M) == f(4)

  H, Y = twisted_cubics()
  @test betti(H) == [1,2,6,10,16,19,22,19,16,10,6,2,1]
  @test euler(H) == 130
  
end
