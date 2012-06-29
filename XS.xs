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
    if (svp) croak("unable to get lvalue element from array");
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

static NV
dist2(vector_av *v0, vector_av *v1) {
    int len, i;
    NV d2 = 0;
    len = av_len(v0);
    check_len(v1, len);
    for (i = 0; i <= len; i++) {
        NV delta = av_fetch_nv(v0, i) - av_fetch_nv(v1, i);
        d2 += delta * delta;
    }
    return d2;
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
    NV acu = 0;
    for (i = 0; i <= len; i++)
        acu += av_fetch_nv(v0, i) * av_fetch_nv(v1, i);
    return acu;
}

static void
scalar_product(vector_av *v, NV s, I32 len, vector_av *out) {
    I32 i;
    for (i = 0; i <= len; i++)
        av_store_nv(out, i, s * av_fetch_nv(v, i));
}

static NV
norm2(vector_av *v, I32 len) {
    NV acu = 0;
    for (i = 0; i <= len; i++) {
        NV c = av_fetch_nv(v, i);
        acu += c * c;
    }
    return acu;
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
    RETVAL = newAV();
    av_extend(RETVAL, dim - 1);
    for (i = 0; i < dim; i++)
        av_store_nv(RETVAL, i, 0);
OUTPUT:
    RETVAL

vector_av *
axis_versor(klass, dim, axis)
    SV *klass = NO_INIT
    I32 dim
    I32 axis
PREINIT:
    I32 i;
CODE:
    if (dim < 0) Perl_croak(aTHX_ "negative_dimension");
    if ((axis < 0) || (axis >= dim)) Perl_croak(aTHX_ "axis index out of range");
    RETVAL = new_vector_av(dim - 1);
    for (i = 0; i < dim; i++)
        av_store_nv(RETVAL, i, ((i == axis) ? 1 : 0));
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
    for (i = 0; i <= len; i++)
        av_store_nv(RETVAL, i, av_fetch_nv(v0, i) - av_fetch_nv(v1, i));
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
        check_len(sv1, len);
        ST(0) = sv_2mortal(newSVnv(dot_product(v0, v1, len)));
        XSRETURN(1);
    }
    else {
        NV nv1 = SvNV(sv1);
        AV *r = new_vector_av(len);
        for (i = 0; i <= len; i++)
            av_store_nv(r, i, nv1 * av_fetch_nv(v0, i));
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
    NV nv1, inv1;
    I32 len, i;
CODE:
    if (SvTRUE(rev) || (SvROK(sv1) && (SvTYPE(SvRV(sv1)) == SVt_PVAV)))
        Perl_croak(aTHX_ "can't use vector as dividend");
    nv1 = SvNV(sv1);
    if (nv1 == 0)
        Perl_croak(aTHX_ "illegal division by zero");
    inv1 = 1.0 / nv1;
    len = av_len(v0);
    RETVAL = new_vector_av(len);
for (i = 0; i <= len; i++)
        av_store_nv(RETVAL, i, inv1 * av_fetch_nv(v0, i));
OUTPUT:
    RETVAL

void
div_me(v0, sv1, rev = 0)
    vector_av *v0
    SV *sv1
    SV rev = NO_INIT
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
    RETVAL = sqrt(norm2(v, av_len(v)));
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

NV
dist(v0, v1)    
    vector_av *v0
    vector_av *v1
CODE:
    RETVAL = sqrt(dist2(v0, v1));
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
    NV norm2 = 0, inorm;
CODE:
    len = av_len(v);
    RETVAL = new_vector_av(len);
    for (i = 0; i <= len; i++) {
        NV c = av_fetch_nv(v, i);
        norm2 += c * c;
    }
    if (norm2 == 0)
        Perl_croak(aTHX_ "Illegal division by zero");
    inorm = 1.0 / sqrt(norm2);
    for (i = 0; i <= len; i++)
        av_store_nv(RETVAL, i, inorm * av_fetch_nv(v, i));
OUTPUT:
    RETVAL

SV *
max_component_index(v)
    vector_av *v
PREINIT:
    I32 len, i, best_i;
    NV best;
CODE:
    len = av_len(v);
    if (len < 0) RETVAL = &PL_sv_undef;
    else {
        best = -1;
        for (i = 0; i <= len; i++) {
            NV c = fabs(av_fetch_nv(v, i));
            if (c > best) {
                best = c;
                best_i = i;
            }
        }
        RETVAL = newSVuv(best_i);
    }
            
void
decompose(v0, v1)
    vector_av *v0
    vector_av *v1
PREINIT
    I32 len, i;
    vector_av p, n;
    NV f, n2;
CODE:
    len = av_len(v0);
    check_len(v1, len);
    n2 = norm2(v0, len);
    if (n2 == 0) Perl_croak("Illegal division by zero");
    p = new_vector_av(len);
    scalar_product(v0, dot_product(v0, v1, len) / n2, len, p);
    n = working here!!!
