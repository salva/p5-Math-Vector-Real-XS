#include "EXTERN.h"
#include "perl.h"
#include "XSUB.h"

#include "ppport.h"

typedef AV vector_av;

static void
check_len(AV *av, I32 len) {
    if (len != av_len(av)) croak("vector dimensions do not match");
}

static NV
av_fetch_nv(AV *av, I32 ix) {
    SV **svp = av_fetch(av, ix, 0);
    if (svp) return SvNV(*svp);
    return 0;
}

void
av_store_nv(AV *av, I32 ix, NV nv) {
    av_store(av, ix, newSVnv(nv));
}

static SV*
av_fetch_lvalue(AV *av, I32 ix) {
    SV **svp = av_fetch(av, ix, 1);
    if (!svp) croak("unable to get lvalue element from array");
    return *svp;
}

static AV *
sv_to_vector_av(SV *sv) {
    if (SvROK(sv)) {
        AV *av = (AV*)SvRV(sv);
        if (SvTYPE(av) == SVt_PVAV) return av;
    }
    croak("argument is not an object of class Math::Vector::Real or can not be coerced into one");
}

static void
sv_set_vector_av(SV *sv, vector_av *av) {
    sv_upgrade(sv, SVt_IV);
    SvRV_set(sv, (SV*)(av));
    SvROK_on(sv);
    sv_bless(sv, gv_stashpv("Math::Vector::Real", GV_ADD));
}

static AV *
new_vector_av(I32 len) {
    AV *av = newAV();
    av_extend(av, len);
    return av;
}

static AV *
clone_vector_av(AV *v, I32 len) {
    I32 i;
    AV *av = new_vector_av(len);
    for (i = 0; i < len; i++)
        av_store_nv(av, i, av_fetch_nv(v, i));
    return av;
}

static NV
dist2(vector_av *v0, vector_av *v1, I32 len) {
    I32 i;
    NV d2 = 0;
    for (i = 0; i <= len; i++) {
        NV delta = av_fetch_nv(v0, i) - av_fetch_nv(v1, i);
        d2 += delta * delta;
    }
    return d2;
}

static NV
dist(vector_av *v0, vector_av *v1, I32 len) {
    return sqrt(dist2(v0, v1, len));
}

static NV
manhattan_dist(vector_av *v0, vector_av *v1) {
    I32 len, i;
    NV d = 0;
    len = av_len(v0);
    check_len(v1, len);
    for (i = 0; i <= len; i++)
        d += fabs(av_fetch_nv(v0, i) - av_fetch_nv(v1, i));
    return d;
}

static NV
dot_product(vector_av *v0, vector_av *v1, I32 len) {
    I32 i;
    NV acu;
    for (acu = 0, i = 0; i <= len; i++)
        acu += av_fetch_nv(v0, i) * av_fetch_nv(v1, i);
    return acu;
}

static void
scalar_product(vector_av *v, NV s, I32 len, vector_av *out) {
    I32 i;
    for (i = 0; i <= len; i++)
        av_store_nv(out, i, s * av_fetch_nv(v, i));
}

static void
subtract(vector_av *v0, vector_av *v1, I32 len, vector_av *out) { /* out = v0 - v1 */
    I32 i;
    for (i = 0; i <= len; i++)
        av_store_nv(out, i, av_fetch_nv(v0, i) - av_fetch_nv(v1, i));
}

static void
subtract_and_neg_me(vector_av *v0, vector_av *v1, I32 len) { /* v0 = v1 - v0 */
    I32 i;
    for (i = 0; i <= len; i++) {
        SV *sv = av_fetch_lvalue(v0, i);
        sv_setnv(sv, av_fetch_nv(v1, i) - SvNV(sv));
    }
}

static NV
norm2(vector_av *v, I32 len) {
    I32 i;
    NV acu;
    for (i = 0, acu = 0; i <= len; i++) {
        NV c = av_fetch_nv(v, i);
        acu += c * c;
    }
    return acu;
}

static NV
norm(vector_av *v, I32 len) {
    return sqrt(norm2(v, len));
}

static I32
min_component_index(vector_av *v, I32 len) {
    I32 i;
    I32 best = 0;
    NV min = fabs(av_fetch_nv(v, best));
    for (i = 1; i <= len; i++) {
        NV c = fabs(av_fetch_nv(v, i));
        if (c < min) {
            min = c;
            best = i;
        }
    }
    return best;
}

static I32
max_component_index(vector_av *v, I32 len) {
    I32 i;
    I32 best = 0;
    NV max = 0;
    for (i = 0; i <= len; i++) {
        NV c = fabs(av_fetch_nv(v, i));
        if (c > max) {
            max = c;
            best = i;
        }
    }
    return best;
}

static void
axis_versor(I32 len, I32 axis, vector_av *out) {
    I32 i;
    for (i = 0; i <= len; i++)
        av_store_nv(out, i, (i == axis ? 1 : 0));
}

static void
cross_product_3d(vector_av *v0, vector_av *v1, vector_av *out) {
    I32 i;
    NV x0 = av_fetch_nv(v0, 0);
    NV y0 = av_fetch_nv(v0, 1);
    NV z0 = av_fetch_nv(v0, 2);
    NV x1 = av_fetch_nv(v1, 0);
    NV y1 = av_fetch_nv(v1, 1);
    NV z1 = av_fetch_nv(v1, 2);
    av_store_nv(out, 0, y0 * z1 - y1 * z0);
    av_store_nv(out, 1, z0 * x1 - z1 * x0);
    av_store_nv(out, 2, x0 * y1 - x1 * y0);
}

static void
versor_me_unsafe(vector_av *v, I32 len) {
    NV inr = 1.0 / norm(v, len);
    I32 i;
    for (i = 0; i <= len; i++) {
        SV *sv = av_fetch_lvalue(v, i);
        sv_setnv(sv, inr * SvNV(sv));
    }
}

MODULE = Math::Vector::Real::XS		PACKAGE = Math::Vector::Real		

vector_av *
V(...)
PREINIT:
    I32 i;
CODE:
    RETVAL = new_vector_av(items - 1);
    for (i = 0; i < items; i++)
        av_store_nv(RETVAL, i, SvNV(ST(i)));
OUTPUT:
    RETVAL

vector_av *
zero(klass, dim)
    SV *klass = NO_INIT
    I32 dim
PREINIT:
    I32 i;
CODE:
    if (dim < 0) Perl_croak(aTHX_ "negative dimension");
    RETVAL = new_vector_av(dim - 1);
    for (i = 0; i < dim; i++)
        av_store_nv(RETVAL, i, 0);
OUTPUT:
    RETVAL

vector_av *
axis_versor(klass, dim, axis)
    SV *klass = NO_INIT
    I32 dim
    I32 axis
CODE:
    if (dim < 0) Perl_croak(aTHX_ "negative_dimension");
    if ((axis < 0) || (axis >= dim)) Perl_croak(aTHX_ "axis index out of range");
    RETVAL = new_vector_av(dim - 1);
    axis_versor(dim - 1, axis, RETVAL);
OUTPUT:
    RETVAL

vector_av *
add(v0, v1, rev = 0)
    vector_av *v0
    vector_av *v1
    SV *rev = NO_INIT
PREINIT:
    I32 len, i;
CODE:
    len = av_len(v0);
    check_len(v1, len);
    RETVAL = new_vector_av(len);
    for (i = 0; i <= len; i++)
        av_store_nv(RETVAL, i, av_fetch_nv(v0, i) + av_fetch_nv(v1, i));
OUTPUT:
    RETVAL

void
add_me(v0, v1, rev = 0)
    vector_av *v0
    vector_av *v1
    SV *rev = NO_INIT
PREINIT:
    I32 len, i;
PPCODE:
    len = av_len(v0);
    check_len(v1, len);
    for (i = 0; i <= len; i++) {
        SV *sv = av_fetch_lvalue(v0, i);
        sv_setnv(sv, SvNV(sv) + av_fetch_nv(v1, i));
    }
    XSRETURN(1);

vector_av *
neg(v, v1 = 0, rev = 0)
    vector_av *v
    SV *v1 = NO_INIT
    SV *rev = NO_INIT
PREINIT:
    I32 len, i;
CODE:
    len = av_len(v);
    RETVAL = new_vector_av(len);
    for (i = 0; i <= len; i++)
        av_store_nv(RETVAL, i, -av_fetch_nv(v, i));
OUTPUT:
    RETVAL

vector_av *
sub(v0, v1, rev = &PL_sv_undef)
    vector_av *v0
    vector_av *v1
    SV *rev
PREINIT:
    I32 len, i;
CODE:
    len = av_len(v0);
    check_len(v1, len);
    if (SvTRUE(rev)) {
        vector_av *tmp = v1;
        v1 = v0;
        v0 = tmp;
    }
    RETVAL = new_vector_av(len);
    subtract(v0, v1, len, RETVAL);
OUTPUT:
    RETVAL

void
sub_me(v0, v1, rev = 0)
    vector_av *v0
    vector_av *v1
    SV *rev = NO_INIT
PREINIT:
    I32 len, i;
PPCODE:
    len = av_len(v0);
    check_len(v1, len);
    for (i = 0; i <= len; i++) {
        SV *sv = av_fetch_lvalue(v0, i);
        sv_setnv(sv, SvNV(sv) - av_fetch_nv(v1, i));
    }
    XSRETURN(1);

void
mul(v0, sv1, rev = 0)
    vector_av *v0;
    SV *sv1
    SV *rev = NO_INIT
PREINIT:
    I32 len, i;
    vector_av *v1;
PPCODE:
    /* fprintf(stderr, "using mul operator from XS\n"); fflush(stderr); */
    len = av_len(v0);
    if (SvROK(sv1) && (SvTYPE(v1 = (AV*)SvRV(sv1)) == SVt_PVAV)) {
        NV acu = 0;
        check_len(v1, len);
        ST(0) = sv_2mortal(newSVnv(dot_product(v0, v1, len)));
        XSRETURN(1);
    }
    else {
        AV *r = new_vector_av(len);
        scalar_product(v0, SvNV(sv1), len, r);
        ST(0) = sv_newmortal();
        sv_set_vector_av(ST(0), r);
        XSRETURN(1);
    }

void
mul_me(v0, sv1, rev = 0)
    vector_av *v0
    SV *sv1
    SV *rev = NO_INIT
PREINIT:
    int len, i;
    NV nv1;
PPCODE:
    if (SvROK(sv1) && (SvTYPE(SvRV(sv1)) == SVt_PVAV))
        Perl_croak(aTHX_ "can not multiply by a vector in place as the result is not a vector");
    nv1 = SvNV(sv1);
    len = av_len(v0);
    for (i = 0; i <= len; i++) {
        SV *sv = av_fetch_lvalue(v0, i);
        sv_setnv(sv, nv1 * SvNV(sv));
    }
    XSRETURN(1);

vector_av *
div(v0, sv1, rev = &PL_sv_undef)
    vector_av *v0
    SV *sv1
    SV *rev
PREINIT:
    NV nv1;
    I32 len, i;
CODE:
    if (SvTRUE(rev) || (SvROK(sv1) && (SvTYPE(SvRV(sv1)) == SVt_PVAV)))
        Perl_croak(aTHX_ "can't use vector as dividend");
    nv1 = SvNV(sv1);
    if (nv1 == 0)
        Perl_croak(aTHX_ "illegal division by zero");
    len = av_len(v0);
    RETVAL = new_vector_av(len);
    scalar_product(v0, 1.0 / nv1, len, RETVAL);
OUTPUT:
    RETVAL

void
div_me(v0, sv1, rev = 0)
    vector_av *v0
    SV *sv1
    SV *rev = NO_INIT
PREINIT:
    int len, i;
    NV nv1, inv1;
CODE:
    if (SvROK(sv1) && (SvTYPE(SvRV(sv1)) == SVt_PVAV))
        Perl_croak(aTHX_ "can't use vector as dividend");
    nv1 = SvNV(sv1);
    if (nv1 == 0)
        Perl_croak(aTHX_ "illegal division by zero");
    inv1 = 1.0 / nv1;
    len = av_len(v0);
    for (i = 0; i <= len; i++) {
        SV *sv = av_fetch_lvalue(v0, i);
        sv_setnv(sv, inv1 * SvNV(sv));
    }

vector_av *
cross(v0, v1, rev = &PL_sv_undef)
    vector_av *v0
    vector_av *v1
    SV *rev
PREINIT:
    I32 len;
CODE:
    len = av_len(v0);
    if (len == 2) {
        check_len(v1, 2);
        if (SvTRUE(rev)) {
            vector_av *tmp = v0;
            v0 = v1;
            v1 = tmp;
        }
        RETVAL = new_vector_av(2);
        cross_product_3d(v0, v1, RETVAL);
    }
    else {
        Perl_croak(aTHX_ "cross product not defined or not implemented for the given dimension");
    }
OUTPUT:
    RETVAL

SV *
equal(v0, v1, rev = 0)
    vector_av *v0
    vector_av *v1
    SV *rev = NO_INIT
PREINIT:
    I32 len, i;
CODE:
    RETVAL = &PL_sv_yes;
    len = av_len(v0);
    check_len(v1, len);
    for (i = 0; i <= len; i++) {
        if (av_fetch_nv(v0, i) != av_fetch_nv(v1, i)) {
            RETVAL = &PL_sv_no;
            break;
        }
    }
OUTPUT:
    RETVAL
            
SV *
nequal(v0, v1, rev = 0)
    vector_av *v0
    vector_av *v1
    SV *rev = NO_INIT
PREINIT:
    I32 len, i;
CODE:
    RETVAL = &PL_sv_no;
    len = av_len(v0);
    check_len(v1, len);
    for (i = 0; i <= len; i++) {
        if (av_fetch_nv(v0, i) != av_fetch_nv(v1, i)) {
            RETVAL = &PL_sv_yes;
            break;
        }
    }
OUTPUT:
    RETVAL
            
NV
abs(v, v1 = 0, rev = 0)
    vector_av *v
    SV *v1 = NO_INIT
    SV *rev = NO_INIT
CODE:
    RETVAL = norm(v, av_len(v));
OUTPUT:
    RETVAL

NV
abs2(v)
    vector_av *v
CODE:    
    RETVAL = norm2(v, av_len(v));
OUTPUT:
    RETVAL

NV
manhattan_norm(v)
    vector_av *v
PREINIT:
    I32 len, i;
CODE:
    RETVAL = 0;
    len = av_len(v);
    for (i = 0; i <= len; i++) {
        NV c = av_fetch_nv(v, i);
        RETVAL += fabs(c);
    }
OUTPUT:
    RETVAL

NV
dist2(v0, v1)
    vector_av *v0
    vector_av *v1
PREINIT:
    I32 len;
CODE:
    len = av_len(v0);
    check_len(v1, len);
    RETVAL = dist2(v0, v1, len);
OUTPUT:
    RETVAL

NV
dist(v0, v1)
    vector_av *v0
    vector_av *v1
PREINIT:
    I32 len;
CODE:
    len = av_len(v0);
    check_len(v1, len);
    RETVAL = dist(v0, v1, len);
OUTPUT:
    RETVAL

NV
manhattan_dist(v0, v1)
    vector_av *v0
    vector_av *v1

vector_av *
versor(v)
    vector_av *v
PREINIT:
    I32 len, i;
    NV n;
CODE:
    len = av_len(v);
    n = norm(v, len);
    if (n == 0) Perl_croak(aTHX_ "Illegal division by zero");
    RETVAL = new_vector_av(len);
    scalar_product(v, 1.0 / n, len, RETVAL);
OUTPUT:
    RETVAL

SV *
max_component_index(v)
    vector_av *v
PREINIT:
    I32 len;
CODE:
    len = av_len(v);
    if (len < 0) RETVAL = &PL_sv_undef;
    else RETVAL = newSViv(max_component_index(v, len));
OUTPUT:
    RETVAL

SV *
min_component_index(v)
    vector_av *v
PREINIT:
    I32 len;
CODE:
    len = av_len(v);
    if (len < 0) RETVAL = &PL_sv_undef;
    else RETVAL = newSViv(min_component_index(v, len));
OUTPUT:
   RETVAL

NV
max_component(v)
    vector_av *v
PREINIT:
    I32 len, i;
CODE:
    len = av_len(v);
    for (RETVAL = 0, i = 0; i <= len; i++) {
        NV c = fabs(av_fetch_nv(v, i));
        if (c > RETVAL) RETVAL = c;
    }
OUTPUT:
    RETVAL

NV
min_component(v)
    vector_av *v
PREINIT:
    I32 len, i;
CODE:
    len = av_len(v);
    RETVAL = fabs(av_fetch_nv(v, 0));
    for (i = 1; i <= len; i++) {
        NV c = fabs(av_fetch_nv(v, i));
        if (c < RETVAL) RETVAL = c;
    }
OUTPUT:
    RETVAL

void
box(klass, ...)
    SV *klass = NO_INIT
PPCODE:
    if (items <= 1) XSRETURN(0);
    else {
        I32 len, i , j;
        vector_av *min, *max;
        AV *v = sv_to_vector_av(ST(1));
        len = av_len(v);
        min = clone_vector_av(v, len);
        max = clone_vector_av(v, len);
        for (j = 2; j < items; i++) {
            v = sv_to_vector_av(ST(j));
            for (i = 0; i <= len; i++) {
                NV c = av_fetch_nv(v, i);
                SV *sv = av_fetch_lvalue(max, i);
                if (c > SvNV(sv)) sv_setnv(sv, c);
                else {
                    sv = av_fetch_lvalue(min, i);
                    if (c < SvNV(sv)) sv_setnv(sv, c);
                }
            }
        }
        EXTEND(SP, 2);
        ST(0) = sv_newmortal();
        sv_set_vector_av(ST(0), min);
        ST(1) = sv_newmortal();
        sv_set_vector_av(ST(1), max);
        XSRETURN(2);
    }

void
decompose(v0, v1)
    vector_av *v0
    vector_av *v1
PREINIT:
    I32 len, i;
    vector_av *p, *n;
    NV f, nr;
PPCODE:
    len = av_len(v0);
    check_len(v1, len);
    nr = norm(v0, len);
    if (nr == 0) Perl_croak(aTHX_ "Illegal division by zero");
    p = new_vector_av(len);
    scalar_product(v0, dot_product(v0, v1, len) / nr, len, p);
    if (GIMME_V == G_ARRAY) {
        n = new_vector_av(len);
        subtract(v1, p, len, n);
        EXTEND(SP, 2);
        ST(0) = sv_newmortal();
        sv_set_vector_av(ST(0), p);
        ST(1) = sv_newmortal();
        sv_set_vector_av(ST(1), n);
        XSRETURN(2);
    }
    else {
        subtract_and_neg_me(p, v1, len);
        ST(0) = sv_newmortal();
        sv_set_vector_av(ST(0), p);
        XSRETURN(1);
    }

void
canonical_base(klass, dim)
    SV *klass = NO_INIT
    I32 dim
PREINIT:
    I32 j;
PPCODE:
    if (dim <= 0) Perl_croak(aTHX_ "negative dimension");
    EXTEND(SP, dim);
    for (j = 0; j < dim; j++) {
        AV *v = new_vector_av(dim - 1);
        ST(j) = sv_newmortal();
        sv_set_vector_av(ST(j), v);
        axis_versor(dim - 1, j, v);
    }
    XSRETURN(dim);

void
rotation_base_3d(dir)
    vector_av *dir
PREINIT:
    I32 len, i;
    vector_av *u, *v, *w;
    NV n;
PPCODE:
    len = av_len(dir);
    if (len != 2) Perl_croak(aTHX_ "rotation_base_3d requires a 3D vector");
    n = norm(dir, len);
    if (n == 0) Perl_croak(aTHX_ "Illegal division by zero");
    EXTEND(SP, 3);
    u = new_vector_av(2);
    ST(0) = sv_newmortal();
    sv_set_vector_av(ST(0), u);
    v = new_vector_av(2);
    ST(1) = sv_newmortal();
    sv_set_vector_av(ST(1), v);
    w = new_vector_av(2);
    ST(2) = sv_newmortal();
    sv_set_vector_av(ST(2), w);
    scalar_product(dir, 1.0 / n, len, u);
    axis_versor(len, min_component_index(u, len), w);
    cross_product_3d(u, w, v);
    versor_me_unsafe(v, len);
    cross_product_3d(u, v, w);
    XSRETURN(3);
