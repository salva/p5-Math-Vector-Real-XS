#ifndef MVR_H_INCLUDED
#define MVR_H_INCLUDED

typedef AV *mvr;

static HV *mvr_stash_cache = NULL;

static void
mvr_on_boot(pTHX) {
    mvr_stash_cache = gv_stashpv("Math::Vector::Real", GV_ADD);
}

static void
mvr_on_clone(pTHX) {
    mvr_stash_cache = NULL;
}

static I32
mvr_len(pTHX_ mvr v) {
    return av_len(v);
}

static void
mvr_check_len(pTHX_ mvr av, I32 len) {
    if (len != mvr_len(aTHX_ av)) croak("vector dimensions do not match");
}

static NV
mvr_get(pTHX_ mvr av, I32 ix) {
    SV **svp = av_fetch(av, ix, 0);
    if (svp) return SvNV(*svp);
    return 0;
}

void
mvr_set(pTHX_ mvr av, I32 ix, NV nv) {
    av_store(av, ix, newSVnv(nv));
}

static SV*
mvr_get_sv(pTHX_ mvr av, I32 ix) {
    SV **svp = av_fetch(av, ix, 1);
    if (!svp) croak("unable to get lvalue element from array");
    return *svp;
}

static mvr 
mvr_from_sv(pTHX_ SV *sv) {
    if (SvROK(sv)) {
        mvr av = (mvr )SvRV(sv);
        if (SvTYPE((SV *)av) == SVt_PVAV) return av;
    }
    croak("argument is not an object of class Math::Vector::Real or can not be coerced into one");
}

static void
sv_set_mvr(pTHX_ SV *sv, mvr av) {
    HV *stash;
#if (PERL_VERSION < 12)
    sv_upgrade(sv, SVt_RV);
#else
    sv_upgrade(sv, SVt_IV);
#endif
    SvTEMP_off((SV*)av);
    SvRV_set(sv, (SV*)(av));
    SvROK_on(sv);
    stash = (mvr_stash_cache ? mvr_stash_cache : gv_stashpv("Math::Vector::Real", GV_ADD));    
    sv_bless(sv, stash);
}

static mvr 
mvr_new(pTHX_ I32 len) {
    mvr av = newAV();
    av_extend(av, len);
    return av;
}

static mvr 
mvr_clone(pTHX_ mvr v, I32 len) {
    I32 i;
    mvr av = mvr_new(aTHX_ len);
    for (i = 0; i <= len; i++)
        mvr_set(aTHX_ av, i, mvr_get(aTHX_ v, i));
    return av;
}

static mvr
mvr_2mortal(pTHX_ mvr v) {
    return (mvr)sv_2mortal((SV*)v);
}

static int
mvr_equal(pTHX_ mvr v0, mvr v1, I32 len) {
    I32 i;
    for (i = 0; i <= len; i++)
        if (mvr_get(aTHX_ v0, i) != mvr_get(aTHX_ v1, i))
            return 0;
    return 1;
}

static void
mvr_add(pTHX_ mvr v0, mvr v1, I32 len, mvr out) {
    I32 i;
    for (i = 0; i <= len; i++)
        mvr_set(aTHX_ out, i, mvr_get(aTHX_ v0, i) + mvr_get(aTHX_ v1, i));
}

static void
mvr_add_me(pTHX_ mvr v0, mvr v1, I32 len) {
    I32 i;
    for (i = 0; i <= len; i++) {
        SV *sv = mvr_get_sv(aTHX_ v0, i);
        sv_setnv(sv, SvNV(sv) + mvr_get(aTHX_ v1, i));
    }
}

static void
mvr_neg(pTHX_ mvr v, I32 len, mvr out) {
    I32 i;
    for (i = 0; i <= len; i++)
        mvr_set(aTHX_ out, i, -mvr_get(aTHX_ v, i));
}

static void
mvr_neg_me(pTHX_ mvr v, I32 len) {
    I32 i;
    for (i = 0; i <= len; i++) {
        SV *sv = mvr_get_sv(aTHX_ v, i);
        sv_setnv(sv, -SvNV(sv));
    }
}

static void
mvr_subtract(pTHX_ mvr v0, mvr v1, I32 len, mvr out) { /* out = v0 - v1 */
    I32 i;
    for (i = 0; i <= len; i++)
        mvr_set(aTHX_ out, i, mvr_get(aTHX_ v0, i) - mvr_get(aTHX_ v1, i));
}

static void
mvr_subtract_me(pTHX_ mvr v0, mvr v1, I32 len) {
    I32 i;
    for (i = 0; i <= len; i++) {
        SV *sv = mvr_get_sv(aTHX_ v0, i);
        sv_setnv(sv, SvNV(sv) - mvr_get(aTHX_ v1, i));
    }
}

static NV
mvr_dist2(pTHX_ mvr v0, mvr v1, I32 len) {
    I32 i;
    NV d2 = 0;
    for (i = 0; i <= len; i++) {
        NV delta = mvr_get(aTHX_ v0, i) - mvr_get(aTHX_ v1, i);
        d2 += delta * delta;
    }
    return d2;
}

static NV
mvr_dist(pTHX_ mvr v0, mvr v1, I32 len) {
    return sqrt(mvr_dist2(aTHX_ v0, v1, len));
}

static NV
mvr_manhattan_dist(pTHX_ mvr v0, mvr v1) {
    I32 len, i;
    NV d = 0;
    len = mvr_len(aTHX_ v0);
    mvr_check_len(aTHX_ v1, len);
    for (i = 0; i <= len; i++)
        d += fabs(mvr_get(aTHX_ v0, i) - mvr_get(aTHX_ v1, i));
    return d;
}

static NV
mvr_dot_product(pTHX_ mvr v0, mvr v1, I32 len) {
    I32 i;
    NV acu;
    for (acu = 0, i = 0; i <= len; i++)
        acu += mvr_get(aTHX_ v0, i) * mvr_get(aTHX_ v1, i);
    return acu;
}

static void
mvr_scalar_product(pTHX_ mvr v, NV s, I32 len, mvr out) {
    I32 i;
    for (i = 0; i <= len; i++)
        mvr_set(aTHX_ out, i, s * mvr_get(aTHX_ v, i));
}

mvr_scalar_product_me(pTHX_ mvr v0, NV scl, I32 len) {
    I32 i;
    for (i = 0; i <= len; i++) {
        SV *sv = mvr_get_sv(aTHX_ v0, i);
        sv_setnv(sv, scl * SvNV(sv));
    }
}

static void
mvr_subtract_and_neg_me(pTHX_ mvr v0, mvr v1, I32 len) { /* v0 = v1 - v0 */
    I32 i;
    for (i = 0; i <= len; i++) {
        SV *sv = mvr_get_sv(aTHX_ v0, i);
        sv_setnv(sv, mvr_get(aTHX_ v1, i) - SvNV(sv));
    }
}

static NV
mvr_norm2(pTHX_ mvr v, I32 len) {
    I32 i;
    NV acu;
    for (i = 0, acu = 0; i <= len; i++) {
        NV c = mvr_get(aTHX_ v, i);
        acu += c * c;
    }
    return acu;
}

static NV
mvr_norm(pTHX_ mvr v, I32 len) {
    return sqrt(mvr_norm2(aTHX_ v, len));
}

static NV
mvr_manhattan_norm(pTHX_ mvr v, I32 len) {
    I32 i;
    NV acu;
    for (i = 0, acu = 0; i <= len; i++)
        acu += fabs(mvr_get(aTHX_ v, i));
    return acu;
}

static I32
mvr_min_component_index(pTHX_ mvr v, I32 len) {
    I32 i;
    I32 best = 0;
    NV min = fabs(mvr_get(aTHX_ v, best));
    for (i = 1; i <= len; i++) {
        NV c = fabs(mvr_get(aTHX_ v, i));
        if (c < min) {
            min = c;
            best = i;
        }
    }
    return best;
}

static I32
mvr_max_component_index(pTHX_ mvr v, I32 len) {
    I32 i;
    I32 best = 0;
    NV max = 0;
    for (i = 0; i <= len; i++) {
        NV c = fabs(mvr_get(aTHX_ v, i));
        if (c > max) {
            max = c;
            best = i;
        }
    }
    return best;
}

static void
mvr_axis_versor(pTHX_ I32 len, I32 axis, mvr out) {
    I32 i;
    for (i = 0; i <= len; i++)
        mvr_set(aTHX_ out, i, (i == axis ? 1 : 0));
}

static void
mvr_cross_product_3d(pTHX_ mvr v0, mvr v1, mvr out) {
    I32 i;
    NV x0 = mvr_get(aTHX_ v0, 0);
    NV y0 = mvr_get(aTHX_ v0, 1);
    NV z0 = mvr_get(aTHX_ v0, 2);
    NV x1 = mvr_get(aTHX_ v1, 0);
    NV y1 = mvr_get(aTHX_ v1, 1);
    NV z1 = mvr_get(aTHX_ v1, 2);
    mvr_set(aTHX_ out, 0, y0 * z1 - y1 * z0);
    mvr_set(aTHX_ out, 1, z0 * x1 - z1 * x0);
    mvr_set(aTHX_ out, 2, x0 * y1 - x1 * y0);
}

static void
mvr_versor_unsafe(pTHX_ mvr v, I32 len, mvr out) {
    mvr_scalar_product(aTHX_ v, 1.0 / mvr_norm(aTHX_ v, len), len, out);
}

static void
mvr_versor_me_unsafe(pTHX_ mvr v, I32 len) {
    NV inr = 1.0 / mvr_norm(aTHX_ v, len);
    I32 i;
    for (i = 0; i <= len; i++) {
        SV *sv = mvr_get_sv(aTHX_ v, i);
        sv_setnv(sv, inr * SvNV(sv));
    }
}

static void
mvr_first_orthant_reflection(pTHX_ mvr v, I32 len, mvr out) {
    I32 i;
    for (i = 0; i <= len; i++)
        mvr_set(aTHX_ out, i, fabs(mvr_get(aTHX_ v, i)));
}

static NV
mvr_max_dist2_between_boxes(pTHX_ mvr a0, mvr a1, mvr b0, mvr b1, I32 len) {
    I32 i;
    NV d2 = 0;
    for (i = 0; i <= len; i++) {
        NV na0 = mvr_get(aTHX_ a0, i);
        NV na1 = mvr_get(aTHX_ a1, i);
        NV nb0 = mvr_get(aTHX_ b0, i);
        NV nb1 = mvr_get(aTHX_ b1, i);
        if (na1 > na0) {
            NV tmp = na0;
            na0 = na1;
            na1 = tmp;
        }
        if (nb1 > nb0) {
            NV tmp = nb0;
            nb0 = nb1;
            nb1 = tmp;
        }
        NV d0 = nb1 - na0;
        NV d1 = nb0 - na1;
        d0 *= d0;
        d1 *= d1;
        d2 += (d0 > d1 ? d0 : d1);
    }
    return d2;
}

#endif
