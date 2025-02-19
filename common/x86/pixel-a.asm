;*****************************************************************************
;* pixel.asm: x86 pixel metrics
;*****************************************************************************
;* Copyright (C) 2003-2023 x264 project
;*
;* Authors: Loren Merritt <lorenm@u.washington.edu>
;*          Holger Lubitz <holger@lubitz.org>
;*          Laurent Aimar <fenrir@via.ecp.fr>
;*          Alex Izvorski <aizvorksi@gmail.com>
;*          Fiona Glaser <fiona@x264.com>
;*          Oskar Arvidsson <oskar@irock.se>
;*
;* This program is free software; you can redistribute it and/or modify
;* it under the terms of the GNU General Public License as published by
;* the Free Software Foundation; either version 2 of the License, or
;* (at your option) any later version.
;*
;* This program is distributed in the hope that it will be useful,
;* but WITHOUT ANY WARRANTY; without even the implied warranty of
;* MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
;* GNU General Public License for more details.
;*
;* You should have received a copy of the GNU General Public License
;* along with this program; if not, write to the Free Software
;* Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02111, USA.
;*
;* This program is also available under a commercial proprietary license.
;* For more information, contact us at licensing@x264.com.
;*****************************************************************************

%include "x86inc.asm"
%include "x86util.asm"

SECTION_RODATA 32
var_shuf_avx512: db 0,-1, 1,-1, 2,-1, 3,-1, 4,-1, 5,-1, 6,-1, 7,-1
                 db 8,-1, 9,-1,10,-1,11,-1,12,-1,13,-1,14,-1,15,-1
hmul_16p:  times 16 db 1
           times 8 db 1, -1
hmul_8p:   times 8 db 1
           times 4 db 1, -1
           times 8 db 1
           times 4 db 1, -1
mask_ff:   times 16 db 0xff
           times 16 db 0
mask_ac4:  times 2 dw 0, -1, -1, -1, 0, -1, -1, -1
mask_ac4b: times 2 dw 0, -1, 0, -1, -1, -1, -1, -1
mask_ac8:  times 2 dw 0, -1, -1, -1, -1, -1, -1, -1
%if HIGH_BIT_DEPTH
ssd_nv12_shuf: db 0, 1, 4, 5, 2, 3, 6, 7, 8, 9, 12, 13, 10, 11, 14, 15
%endif
%if BIT_DEPTH == 10
ssim_c1:   times 4 dd 6697.7856    ; .01*.01*1023*1023*64
ssim_c2:   times 4 dd 3797644.4352 ; .03*.03*1023*1023*64*63
pf_64:     times 4 dd 64.0
pf_128:    times 4 dd 128.0
%elif BIT_DEPTH == 9
ssim_c1:   times 4 dd 1671         ; .01*.01*511*511*64
ssim_c2:   times 4 dd 947556       ; .03*.03*511*511*64*63
%else ; 8-bit
ssim_c1:   times 4 dd 416          ; .01*.01*255*255*64
ssim_c2:   times 4 dd 235963       ; .03*.03*255*255*64*63
%endif
hmul_4p:   times 2 db 1, 1, 1, 1, 1, -1, 1, -1
mask_10:   times 4 dw 0, -1
mask_1100: times 2 dd 0, -1
pb_pppm:   times 4 db 1,1,1,-1
deinterleave_shuf: db 0, 2, 4, 6, 8, 10, 12, 14, 1, 3, 5, 7, 9, 11, 13, 15
intrax3_shuf: db 7,6,7,6,5,4,5,4,3,2,3,2,1,0,1,0

intrax9a_ddlr1: db  6, 7, 8, 9, 7, 8, 9,10, 4, 5, 6, 7, 3, 4, 5, 6
intrax9a_ddlr2: db  8, 9,10,11, 9,10,11,12, 2, 3, 4, 5, 1, 2, 3, 4
intrax9a_hdu1:  db 15, 4, 5, 6,14, 3,15, 4,14, 2,13, 1,13, 1,12, 0
intrax9a_hdu2:  db 13, 2,14, 3,12, 1,13, 2,12, 0,11,11,11,11,11,11
intrax9a_vrl1:  db 10,11,12,13, 3, 4, 5, 6,11,12,13,14, 5, 6, 7, 8
intrax9a_vrl2:  db  2,10,11,12, 1, 3, 4, 5,12,13,14,15, 6, 7, 8, 9
intrax9a_vh1:   db  6, 7, 8, 9, 6, 7, 8, 9, 4, 4, 4, 4, 3, 3, 3, 3
intrax9a_vh2:   db  6, 7, 8, 9, 6, 7, 8, 9, 2, 2, 2, 2, 1, 1, 1, 1
intrax9a_dc:    db  1, 2, 3, 4, 6, 7, 8, 9,-1,-1,-1,-1,-1,-1,-1,-1
intrax9a_lut:   db 0x60,0x68,0x80,0x00,0x08,0x20,0x40,0x28,0x48,0,0,0,0,0,0,0
pw_s01234567:   dw 0x8000,0x8001,0x8002,0x8003,0x8004,0x8005,0x8006,0x8007
pw_s01234657:   dw 0x8000,0x8001,0x8002,0x8003,0x8004,0x8006,0x8005,0x8007
intrax9_edge:   db  0, 0, 1, 2, 3, 7, 8, 9,10,11,12,13,14,15,15,15

intrax9b_ddlr1: db  6, 7, 8, 9, 4, 5, 6, 7, 7, 8, 9,10, 3, 4, 5, 6
intrax9b_ddlr2: db  8, 9,10,11, 2, 3, 4, 5, 9,10,11,12, 1, 2, 3, 4
intrax9b_hdu1:  db 15, 4, 5, 6,14, 2,13, 1,14, 3,15, 4,13, 1,12, 0
intrax9b_hdu2:  db 13, 2,14, 3,12, 0,11,11,12, 1,13, 2,11,11,11,11
intrax9b_vrl1:  db 10,11,12,13,11,12,13,14, 3, 4, 5, 6, 5, 6, 7, 8
intrax9b_vrl2:  db  2,10,11,12,12,13,14,15, 1, 3, 4, 5, 6, 7, 8, 9
intrax9b_vh1:   db  6, 7, 8, 9, 4, 4, 4, 4, 6, 7, 8, 9, 3, 3, 3, 3
intrax9b_vh2:   db  6, 7, 8, 9, 2, 2, 2, 2, 6, 7, 8, 9, 1, 1, 1, 1
intrax9b_edge2: db  6, 7, 8, 9, 6, 7, 8, 9, 4, 3, 2, 1, 4, 3, 2, 1
intrax9b_v1:    db  0, 1,-1,-1,-1,-1,-1,-1, 4, 5,-1,-1,-1,-1,-1,-1
intrax9b_v2:    db  2, 3,-1,-1,-1,-1,-1,-1, 6, 7,-1,-1,-1,-1,-1,-1
intrax9b_lut:   db 0x60,0x64,0x80,0x00,0x04,0x20,0x40,0x24,0x44,0,0,0,0,0,0,0

ALIGN 32
intra8x9_h1:   db  7, 7, 7, 7, 7, 7, 7, 7, 5, 5, 5, 5, 5, 5, 5, 5
intra8x9_h2:   db  6, 6, 6, 6, 6, 6, 6, 6, 4, 4, 4, 4, 4, 4, 4, 4
intra8x9_h3:   db  3, 3, 3, 3, 3, 3, 3, 3, 1, 1, 1, 1, 1, 1, 1, 1
intra8x9_h4:   db  2, 2, 2, 2, 2, 2, 2, 2, 0, 0, 0, 0, 0, 0, 0, 0
intra8x9_ddl1: db  1, 2, 3, 4, 5, 6, 7, 8, 3, 4, 5, 6, 7, 8, 9,10
intra8x9_ddl2: db  2, 3, 4, 5, 6, 7, 8, 9, 4, 5, 6, 7, 8, 9,10,11
intra8x9_ddl3: db  5, 6, 7, 8, 9,10,11,12, 7, 8, 9,10,11,12,13,14
intra8x9_ddl4: db  6, 7, 8, 9,10,11,12,13, 8, 9,10,11,12,13,14,15
intra8x9_vl1:  db  0, 1, 2, 3, 4, 5, 6, 7, 1, 2, 3, 4, 5, 6, 7, 8
intra8x9_vl2:  db  1, 2, 3, 4, 5, 6, 7, 8, 2, 3, 4, 5, 6, 7, 8, 9
intra8x9_vl3:  db  2, 3, 4, 5, 6, 7, 8, 9, 3, 4, 5, 6, 7, 8, 9,10
intra8x9_vl4:  db  3, 4, 5, 6, 7, 8, 9,10, 4, 5, 6, 7, 8, 9,10,11
intra8x9_ddr1: db  8, 9,10,11,12,13,14,15, 6, 7, 8, 9,10,11,12,13
intra8x9_ddr2: db  7, 8, 9,10,11,12,13,14, 5, 6, 7, 8, 9,10,11,12
intra8x9_ddr3: db  4, 5, 6, 7, 8, 9,10,11, 2, 3, 4, 5, 6, 7, 8, 9
intra8x9_ddr4: db  3, 4, 5, 6, 7, 8, 9,10, 1, 2, 3, 4, 5, 6, 7, 8
intra8x9_vr1:  db  8, 9,10,11,12,13,14,15, 7, 8, 9,10,11,12,13,14
intra8x9_vr2:  db  8, 9,10,11,12,13,14,15, 6, 8, 9,10,11,12,13,14
intra8x9_vr3:  db  5, 7, 8, 9,10,11,12,13, 3, 5, 7, 8, 9,10,11,12
intra8x9_vr4:  db  4, 6, 8, 9,10,11,12,13, 2, 4, 6, 8, 9,10,11,12
intra8x9_hd1:  db  3, 8, 9,10,11,12,13,14, 1, 6, 2, 7, 3, 8, 9,10
intra8x9_hd2:  db  2, 7, 3, 8, 9,10,11,12, 0, 5, 1, 6, 2, 7, 3, 8
intra8x9_hd3:  db  7, 8, 9,10,11,12,13,14, 3, 4, 5, 6, 7, 8, 9,10
intra8x9_hd4:  db  5, 6, 7, 8, 9,10,11,12, 1, 2, 3, 4, 5, 6, 7, 8
intra8x9_hu1:  db 13,12,11,10, 9, 8, 7, 6, 9, 8, 7, 6, 5, 4, 3, 2
intra8x9_hu2:  db 11,10, 9, 8, 7, 6, 5, 4, 7, 6, 5, 4, 3, 2, 1, 0
intra8x9_hu3:  db  5, 4, 3, 2, 1, 0,15,15, 1, 0,15,15,15,15,15,15
intra8x9_hu4:  db  3, 2, 1, 0,15,15,15,15,15,15,15,15,15,15,15,15
pw_s00112233:  dw 0x8000,0x8000,0x8001,0x8001,0x8002,0x8002,0x8003,0x8003
pw_s00001111:  dw 0x8000,0x8000,0x8000,0x8000,0x8001,0x8001,0x8001,0x8001

transd_shuf1: SHUFFLE_MASK_W 0, 8, 2, 10, 4, 12, 6, 14
transd_shuf2: SHUFFLE_MASK_W 1, 9, 3, 11, 5, 13, 7, 15

sw_f0:     dq 0xfff0, 0
pd_f0:     times 4 dd 0xffff0000
pd_2:      times 4 dd 2

pw_76543210: dw 0, 1, 2, 3, 4, 5, 6, 7

ads_mvs_shuffle:
%macro ADS_MVS_SHUFFLE 8
    %assign y x
    %rep 8
        %rep 7
            %rotate (~y)&1
            %assign y y>>((~y)&1)
        %endrep
        db %1*2, %1*2+1
        %rotate 1
        %assign y y>>1
    %endrep
%endmacro
%assign x 0
%rep 256
    ADS_MVS_SHUFFLE 0, 1, 2, 3, 4, 5, 6, 7
%assign x x+1
%endrep

SECTION .text

cextern pb_0
cextern pb_1
cextern pw_1
cextern pw_8
cextern pw_16
cextern pw_32
cextern pw_00ff
cextern pw_ppppmmmm
cextern pw_ppmmppmm
cextern pw_pmpmpmpm
cextern pw_pmmpzzzz
cextern pd_1
cextern hsub_mul
cextern popcnt_table

;=============================================================================
; SSD
;=============================================================================

%if HIGH_BIT_DEPTH
;-----------------------------------------------------------------------------
; int pixel_ssd_WxH( uint16_t *, intptr_t, uint16_t *, intptr_t )
;-----------------------------------------------------------------------------
%macro SSD_ONE 2
cglobal pixel_ssd_%1x%2, 4,7,6
    FIX_STRIDES r1, r3
%if mmsize == %1*2
    %define offset0_1 r1
    %define offset0_2 r1*2
    %define offset0_3 r5
    %define offset1_1 r3
    %define offset1_2 r3*2
    %define offset1_3 r6
    lea     r5, [3*r1]
    lea     r6, [3*r3]
%elif mmsize == %1
    %define offset0_1 mmsize
    %define offset0_2 r1
    %define offset0_3 r1+mmsize
    %define offset1_1 mmsize
    %define offset1_2 r3
    %define offset1_3 r3+mmsize
%elif mmsize == %1/2
    %define offset0_1 mmsize
    %define offset0_2 mmsize*2
    %define offset0_3 mmsize*3
    %define offset1_1 mmsize
    %define offset1_2 mmsize*2
    %define offset1_3 mmsize*3
%endif
    %assign %%n %2/(2*mmsize/%1)
%if %%n > 1
    mov    r4d, %%n
%endif
    pxor    m0, m0
.loop:
    mova    m1, [r0]
    mova    m2, [r0+offset0_1]
    mova    m3, [r0+offset0_2]
    mova    m4, [r0+offset0_3]
    psubw   m1, [r2]
    psubw   m2, [r2+offset1_1]
    psubw   m3, [r2+offset1_2]
    psubw   m4, [r2+offset1_3]
%if %%n > 1
    lea     r0, [r0+r1*(%2/%%n)]
    lea     r2, [r2+r3*(%2/%%n)]
%endif
    pmaddwd m1, m1
    pmaddwd m2, m2
    pmaddwd m3, m3
    pmaddwd m4, m4
    paddd   m1, m2
    paddd   m3, m4
    paddd   m0, m1
    paddd   m0, m3
%if %%n > 1
    dec    r4d
    jg .loop
%endif
    HADDD   m0, m5
    movd   eax, xm0
    RET
%endmacro

INIT_MMX mmx2
SSD_ONE     4,  4
SSD_ONE     4,  8
SSD_ONE     4, 16
SSD_ONE     8,  4
SSD_ONE     8,  8
SSD_ONE     8, 16
SSD_ONE    16,  8
SSD_ONE    16, 16
INIT_XMM sse2
SSD_ONE     8,  4
SSD_ONE     8,  8
SSD_ONE     8, 16
SSD_ONE    16,  8
SSD_ONE    16, 16
INIT_YMM avx2
SSD_ONE    16,  8
SSD_ONE    16, 16
%endif ; HIGH_BIT_DEPTH

%if HIGH_BIT_DEPTH == 0
%macro SSD_LOAD_FULL 5
    mova      m1, [t0+%1]
    mova      m2, [t2+%2]
    mova      m3, [t0+%3]
    mova      m4, [t2+%4]
%if %5==1
    add       t0, t1
    add       t2, t3
%elif %5==2
    lea       t0, [t0+2*t1]
    lea       t2, [t2+2*t3]
%endif
%endmacro

%macro LOAD 5
    movh      m%1, %3
    movh      m%2, %4
%if %5
    lea       t0, [t0+2*t1]
%endif
%endmacro

%macro JOIN 7
    movh      m%3, %5
    movh      m%4, %6
%if %7
    lea       t2, [t2+2*t3]
%endif
    punpcklbw m%1, m7
    punpcklbw m%3, m7
    psubw     m%1, m%3
    punpcklbw m%2, m7
    punpcklbw m%4, m7
    psubw     m%2, m%4
%endmacro

%macro JOIN_SSE2 7
    movh      m%3, %5
    movh      m%4, %6
%if %7
    lea       t2, [t2+2*t3]
%endif
    punpcklqdq m%1, m%2
    punpcklqdq m%3, m%4
    DEINTB %2, %1, %4, %3, 7
    psubw m%2, m%4
    psubw m%1, m%3
%endmacro

%macro JOIN_SSSE3 7
    movh      m%3, %5
    movh      m%4, %6
%if %7
    lea       t2, [t2+2*t3]
%endif
    punpcklbw m%1, m%3
    punpcklbw m%2, m%4
%endmacro

%macro LOAD_AVX2 5
    mova     xm%1, %3
    vinserti128 m%1, m%1, %4, 1
%if %5
    lea       t0, [t0+2*t1]
%endif
%endmacro

%macro JOIN_AVX2 7
    mova     xm%2, %5
    vinserti128 m%2, m%2, %6, 1
%if %7
    lea       t2, [t2+2*t3]
%endif
    SBUTTERFLY bw, %1, %2, %3
%endmacro

%macro SSD_LOAD_HALF 5
    LOAD      1, 2, [t0+%1], [t0+%3], 1
    JOIN      1, 2, 3, 4, [t2+%2], [t2+%4], 1
    LOAD      3, 4, [t0+%1], [t0+%3], %5
    JOIN      3, 4, 5, 6, [t2+%2], [t2+%4], %5
%endmacro

%macro SSD_CORE 7-8
%ifidn %8, FULL
    mova      m%6, m%2
    mova      m%7, m%4
    psubusb   m%2, m%1
    psubusb   m%4, m%3
    psubusb   m%1, m%6
    psubusb   m%3, m%7
    por       m%1, m%2
    por       m%3, m%4
    punpcklbw m%2, m%1, m%5
    punpckhbw m%1, m%5
    punpcklbw m%4, m%3, m%5
    punpckhbw m%3, m%5
%endif
    pmaddwd   m%1, m%1
    pmaddwd   m%2, m%2
    pmaddwd   m%3, m%3
    pmaddwd   m%4, m%4
%endmacro

%macro SSD_CORE_SSE2 7-8
%ifidn %8, FULL
    DEINTB %6, %1, %7, %2, %5
    psubw m%6, m%7
    psubw m%1, m%2
    SWAP %6, %2, %1
    DEINTB %6, %3, %7, %4, %5
    psubw m%6, m%7
    psubw m%3, m%4
    SWAP %6, %4, %3
%endif
    pmaddwd   m%1, m%1
    pmaddwd   m%2, m%2
    pmaddwd   m%3, m%3
    pmaddwd   m%4, m%4
%endmacro

%macro SSD_CORE_SSSE3 7-8
%ifidn %8, FULL
    punpckhbw m%6, m%1, m%2
    punpckhbw m%7, m%3, m%4
    punpcklbw m%1, m%2
    punpcklbw m%3, m%4
    SWAP %6, %2, %3
    SWAP %7, %4
%endif
    pmaddubsw m%1, m%5
    pmaddubsw m%2, m%5
    pmaddubsw m%3, m%5
    pmaddubsw m%4, m%5
    pmaddwd   m%1, m%1
    pmaddwd   m%2, m%2
    pmaddwd   m%3, m%3
    pmaddwd   m%4, m%4
%endmacro

%macro SSD_ITER 6
    SSD_LOAD_%1 %2,%3,%4,%5,%6
    SSD_CORE  1, 2, 3, 4, 7, 5, 6, %1
    paddd     m1, m2
    paddd     m3, m4
    paddd     m0, m1
    paddd     m0, m3
%endmacro

;-----------------------------------------------------------------------------
; int pixel_ssd_16x16( uint8_t *, intptr_t, uint8_t *, intptr_t )
;-----------------------------------------------------------------------------
%macro SSD 2
%if %1 != %2
    %assign function_align 8
%else
    %assign function_align 16
%endif
cglobal pixel_ssd_%1x%2, 0,0,0
%if cpuflag(ssse3)
    PIC_BEGIN rax, 0
    mova    m7, [pic(hsub_mul)]
    PIC_END
%elifidn cpuname, sse2
    PIC_BEGIN rax, 0
    mova    m7, [pic(pw_00ff)]
    PIC_END
%elif %1 >= mmsize
    pxor    m7, m7
%endif
    mov     al, %1*%2/mmsize/2

%if %1 != %2
    jmp mangle(private_prefix %+ _pixel_ssd_%1x%1 %+ SUFFIX %+ .startloop)
%else

.startloop:
%if ARCH_X86_64
    DECLARE_REG_TMP 0,1,2,3
    PROLOGUE 0,0,8
%else
    PROLOGUE 0,5
    DECLARE_REG_TMP 1,2,3,4
    mov t0, r0m
    mov t1, r1m
    mov t2, r2m
    mov t3, r3m
%endif

    ; m7 init has been moved to the top of pixel_ssd_%1x%2 function (this one
    ; or caller of this one), to forego saving eax register in PIC_BEGIN.
    ; Because m7 init doesn't depend on %2, it's the same in pixel_ssd_%1x%1
    ; and in pixel_ssd_%1x%2.
    pxor    m0, m0

ALIGN 16
.loop:
%if %1 > mmsize
    SSD_ITER FULL, 0, 0, mmsize, mmsize, 1
%elif %1 == mmsize
    SSD_ITER FULL, 0, 0, t1, t3, 2
%else
    SSD_ITER HALF, 0, 0, t1, t3, 2
%endif
    dec     al
    jg .loop
%if mmsize==32
    vextracti128 xm1, m0, 1
    paddd  xm0, xm1
    HADDD  xm0, xm1
    movd   eax, xm0
%else
    HADDD   m0, m1
    movd   eax, m0
%endif
    RET
%endif
%endmacro

INIT_MMX mmx
SSD 16, 16
SSD 16,  8
SSD  8,  8
SSD  8, 16
SSD  4,  4
SSD  8,  4
SSD  4,  8
SSD  4, 16
INIT_XMM sse2slow
SSD 16, 16
SSD  8,  8
SSD 16,  8
SSD  8, 16
SSD  8,  4
INIT_XMM sse2
%define SSD_CORE SSD_CORE_SSE2
%define JOIN JOIN_SSE2
SSD 16, 16
SSD  8,  8
SSD 16,  8
SSD  8, 16
SSD  8,  4
INIT_XMM ssse3
%define SSD_CORE SSD_CORE_SSSE3
%define JOIN JOIN_SSSE3
SSD 16, 16
SSD  8,  8
SSD 16,  8
SSD  8, 16
SSD  8,  4
INIT_XMM avx
SSD 16, 16
SSD  8,  8
SSD 16,  8
SSD  8, 16
SSD  8,  4
INIT_MMX ssse3
SSD  4,  4
SSD  4,  8
SSD  4, 16
INIT_XMM xop
SSD 16, 16
SSD  8,  8
SSD 16,  8
SSD  8, 16
SSD  8,  4
%define LOAD LOAD_AVX2
%define JOIN JOIN_AVX2
INIT_YMM avx2
SSD 16, 16
SSD 16,  8
%assign function_align 16
%endif ; !HIGH_BIT_DEPTH

;-----------------------------------------------------------------------------
; void pixel_ssd_nv12_core( uint16_t *pixuv1, intptr_t stride1, uint16_t *pixuv2, intptr_t stride2,
;                           int width, int height, uint64_t *ssd_u, uint64_t *ssd_v )
;
; The maximum width this function can handle without risk of overflow is given
; in the following equation: (mmsize in bits)
;
;   2 * mmsize/32 * (2^32 - 1) / (2^BIT_DEPTH - 1)^2
;
; For 10-bit XMM this means width >= 32832. At sane distortion levels
; it will take much more than that though.
;-----------------------------------------------------------------------------
%if HIGH_BIT_DEPTH
%macro SSD_NV12 0
cglobal pixel_ssd_nv12_core, 6,7,7
    shl        r4d, 2
    FIX_STRIDES r1, r3
    add         r0, r4
    add         r2, r4
    neg         r4
    pxor        m4, m4
    pxor        m5, m5
%if mmsize == 32
    PIC_BEGIN r6, 0 ; don't save r6, it's destroyed in .loopy: mov r6, r4
    vbroadcasti128 m6, [pic(ssd_nv12_shuf)]
    PIC_END
%endif
.loopy:
    mov         r6, r4
    pxor        m2, m2
    pxor        m3, m3
.loopx:
    mova        m0, [r0+r6]
    mova        m1, [r0+r6+mmsize]
    psubw       m0, [r2+r6]
    psubw       m1, [r2+r6+mmsize]
%if mmsize == 32
    pshufb      m0, m6
    pshufb      m1, m6
%else
    SBUTTERFLY wd, 0, 1, 6
%endif
%if cpuflag(xop)
    pmadcswd    m2, m0, m0, m2
    pmadcswd    m3, m1, m1, m3
%else
    pmaddwd     m0, m0
    pmaddwd     m1, m1
    paddd       m2, m0
    paddd       m3, m1
%endif
    add         r6, 2*mmsize
    jl .loopx
%if mmsize == 32 ; avx2 may overread by 32 bytes, that has to be handled
    jz .no_overread
    psubd       m3, m1
.no_overread:
%endif
    punpckhdq   m0, m2, m5 ; using HADDD would remove the mmsize/32 part from the
    punpckhdq   m1, m3, m5 ; equation above, putting the width limit at 8208
    punpckldq   m2, m5
    punpckldq   m3, m5
    paddq       m0, m1
    paddq       m2, m3
    paddq       m4, m0
    paddq       m4, m2
    add         r0, r1
    add         r2, r3
    dec        r5d
    jg .loopy
    mov         r0, r6m
    mov         r1, r7m
%if mmsize == 32
    vextracti128 xm0, m4, 1
    paddq      xm4, xm0
%endif
    movq      [r0], xm4
    movhps    [r1], xm4
    RET
%endmacro ; SSD_NV12

%else ; !HIGH_BIT_DEPTH
;-----------------------------------------------------------------------------
; void pixel_ssd_nv12_core( uint8_t *pixuv1, intptr_t stride1, uint8_t *pixuv2, intptr_t stride2,
;                           int width, int height, uint64_t *ssd_u, uint64_t *ssd_v )
;
; This implementation can potentially overflow on image widths >= 11008 (or
; 6604 if interlaced), since it is called on blocks of height up to 12 (resp
; 20). At sane distortion levels it will take much more than that though.
;-----------------------------------------------------------------------------
%macro SSD_NV12 0
cglobal pixel_ssd_nv12_core, 6,7
    add    r4d, r4d
    add     r0, r4
    add     r2, r4
    neg     r4
    pxor    m3, m3
    pxor    m4, m4
    PIC_BEGIN r6, 0 ; don't save r6, it's destroyed in .loopy: mov r6, r4
    mova    m5, [pic(pw_00ff)]
    PIC_END
.loopy:
    mov     r6, r4
.loopx:
%if mmsize == 32 ; only 16-byte alignment is guaranteed
    movu    m2, [r0+r6]
    movu    m1, [r2+r6]
%else
    mova    m2, [r0+r6]
    mova    m1, [r2+r6]
%endif
    psubusb m0, m2, m1
    psubusb m1, m2
    por     m0, m1
    psrlw   m2, m0, 8
    pand    m0, m5
%if cpuflag(xop)
    pmadcswd m4, m2, m2, m4
    pmadcswd m3, m0, m0, m3
%else
    pmaddwd m2, m2
    pmaddwd m0, m0
    paddd   m4, m2
    paddd   m3, m0
%endif
    add     r6, mmsize
    jl .loopx
%if mmsize == 32 ; avx2 may overread by 16 bytes, that has to be handled
    jz .no_overread
    pcmpeqb xm1, xm1
    pandn   m0, m1, m0 ; zero the lower half
    pandn   m2, m1, m2
    psubd   m3, m0
    psubd   m4, m2
.no_overread:
%endif
    add     r0, r1
    add     r2, r3
    dec    r5d
    jg .loopy
    mov     r0, r6m
    mov     r1, r7m
%if cpuflag(ssse3)
    phaddd  m3, m4
%else
    SBUTTERFLY qdq, 3, 4, 0
    paddd   m3, m4
%endif
%if mmsize == 32
    vextracti128 xm4, m3, 1
    paddd  xm3, xm4
%endif
    psllq  xm4, xm3, 32
    paddd  xm3, xm4
    psrlq  xm3, 32
    movq  [r0], xm3
    movhps [r1], xm3
    RET
%endmacro ; SSD_NV12
%endif ; !HIGH_BIT_DEPTH

INIT_XMM sse2
SSD_NV12
INIT_XMM avx
SSD_NV12
INIT_XMM xop
SSD_NV12
INIT_YMM avx2
SSD_NV12

;=============================================================================
; variance
;=============================================================================

%macro VAR_START 1 ; PIC*[%1&!HIGH_BIT_DEPTH]
    pxor  m5, m5    ; sum
    pxor  m6, m6    ; sum squared
%if HIGH_BIT_DEPTH == 0
%if %1
    PIC_BEGIN
    mova  m7, [pic(pw_00ff)]
    PIC_END
%elif mmsize == 16
    pxor  m7, m7    ; zero
%endif
%endif ; !HIGH_BIT_DEPTH
%endmacro

%macro VAR_END 0 ; edx:eax, PIC:rax,0
    PIC_BEGIN rax, 0 ; don't save rax, it's not used until getting destroyed
                     ; by `movq rax, xm5' / `movd eax, xm5'
    pmaddwd       m5, [pic(pw_1)]
    PIC_END
    SBUTTERFLY    dq, 5, 6, 0
    paddd         m5, m6
%if mmsize == 32
    vextracti128 xm6, m5, 1
    paddd        xm5, xm6
%endif
    MOVHL        xm6, xm5
    paddd        xm5, xm6
%if ARCH_X86_64
    movq         rax, xm5
%else
    movd         eax, xm5
%if cpuflag(avx)
    pextrd       edx, xm5, 1
%else
    pshuflw      xm5, xm5, q1032
    movd         edx, xm5
%endif
%endif ; ARCH
%endmacro

%macro VAR_CORE 0 ; m0,1,3..6
    paddw     m5, m0
    paddw     m5, m3
    paddw     m5, m1
    paddw     m5, m4
    pmaddwd   m0, m0
    pmaddwd   m3, m3
    pmaddwd   m1, m1
    pmaddwd   m4, m4
    paddd     m6, m0
    paddd     m6, m3
    paddd     m6, m1
    paddd     m6, m4
%endmacro

;-----------------------------------------------------------------------------
; int pixel_var_wxh( uint8_t *, intptr_t )
;-----------------------------------------------------------------------------
%if HIGH_BIT_DEPTH
%macro VAR 0
cglobal pixel_var_16x16, 2,2,8
    FIX_STRIDES r1
    VAR_START 0
    %assign %%i 8
%rep %%i
    %assign %%i %%i-1
    mova      m0, [r0]
    mova      m1, [r0+mmsize]
    mova      m3, [r0+r1]
    mova      m4, [r0+r1+mmsize]
    VAR_CORE ; m0,1,3..6
    %if %%i
    lea       r0, [r0+r1*2]
    %endif
%endrep
    VAR_END ; PIC:rax,0
    RET

cglobal pixel_var_8x8, 2,3,8
    lea       r2, [r1*3]
    VAR_START 0
    mova      m0, [r0]
    mova      m1, [r0+r1*2]
    mova      m3, [r0+r1*4]
    mova      m4, [r0+r2*2]
    VAR_CORE ; m0,1,3..6
    lea       r0, [r0+r1*8]
    mova      m0, [r0]
    mova      m1, [r0+r1*2]
    mova      m3, [r0+r1*4]
    mova      m4, [r0+r2*2]
    VAR_CORE
    VAR_END ; PIC:rax,0
    RET
%endmacro ; VAR

INIT_XMM sse2
VAR
INIT_XMM avx
VAR

%else ; HIGH_BIT_DEPTH == 0

%macro VAR 0
cglobal pixel_var_16x16, 2,2,8
    PIC_BEGIN
    CHECK_REG_COLLISION "rpic","r0","r1"
    VAR_START 1 ; PIC*
    %assign %%i 8
%rep %%i
    %assign %%i %%i-1
    mova      m0, [r0]
    mova      m3, [r0+r1]
    DEINTB    1, 0, 4, 3, 7 ; m0,1,3,4,7
    VAR_CORE ; m0,1,3..6
    %if %%i
    lea       r0, [r0+r1*2]
    %endif
%endrep
    VAR_END ; PIC
    PIC_END
    RET

cglobal pixel_var_8x8, 2,3,8
    %define rpicsave ; safe to push/pop rpic
    PIC_BEGIN
    CHECK_REG_COLLISION "rpic","r0","r1","r2"
    VAR_START 1 ; PIC*
    lea       r2, [r1*3]
    %assign %%i 2
%rep %%i
    %assign %%i %%i-1
    movh      m0, [r0]
    movh      m3, [r0+r1]
    movhps    m0, [r0+r1*2]
    movhps    m3, [r0+r2]
    DEINTB    1, 0, 4, 3, 7 ; m0,1,3,4,7
    VAR_CORE ; m0,1,3..6
    %if %%i
    lea       r0, [r0+r1*4]
    %endif
%endrep
    VAR_END ; PIC
    PIC_END
    RET

cglobal pixel_var_8x16, 2,3,8
    %define rpicsave ; safe to push/pop rpic
    PIC_BEGIN
    CHECK_REG_COLLISION "rpic","r0","r1","r2"
    VAR_START 1 ; PIC*
    lea       r2, [r1*3]
    %assign %%i 4
%rep %%i
    %assign %%i %%i-1
    movh      m0, [r0]
    movh      m3, [r0+r1]
    movhps    m0, [r0+r1*2]
    movhps    m3, [r0+r2]
    DEINTB    1, 0, 4, 3, 7 ; m0,1,3,4,7
    VAR_CORE ; m0,1,3..6
    %if %%i
    lea       r0, [r0+r1*4]
    %endif
%endrep
    VAR_END ; PIC
    PIC_END
    RET
%endmacro ; VAR

INIT_XMM sse2
VAR
INIT_XMM avx
VAR
%endif ; !HIGH_BIT_DEPTH

INIT_YMM avx2
cglobal pixel_var_16x16, 2,3,7
    FIX_STRIDES r1
    VAR_START 0
    lea       r2, [r1*3]
%push
%assign %$i 4
%rep %$i
    %assign %$i %$i-1
%if HIGH_BIT_DEPTH
    mova      m0, [r0]
    mova      m3, [r0+r1]
    mova      m1, [r0+r1*2]
    mova      m4, [r0+r2]
%else
    pmovzxbw  m0, [r0]
    pmovzxbw  m3, [r0+r1]
    pmovzxbw  m1, [r0+r1*2]
    pmovzxbw  m4, [r0+r2]
%endif
    VAR_CORE ; m0,1,3..6
    %if %$i
    lea       r0, [r0+r1*4]
    %endif
%endrep
%pop
    VAR_END ; PIC:rax,0
    RET

%macro VAR_AVX512_CORE 1 ; accum ; m0..3
%if %1
    paddw    m0, m2
    pmaddwd  m2, m2
    paddw    m0, m3
    pmaddwd  m3, m3
    paddd    m1, m2
    paddd    m1, m3
%else
    paddw    m0, m2, m3
    pmaddwd  m2, m2
    pmaddwd  m3, m3
    paddd    m1, m2, m3
%endif
%endmacro

%macro VAR_AVX512_CORE_16x16 1 ; accum ; r0..2, k1, m0..4
%if HIGH_BIT_DEPTH
    mova            ym2, [r0]
    vinserti64x4     m2, [r0+r1], 1
    mova            ym3, [r0+2*r1]
    vinserti64x4     m3, [r0+r2], 1
%else
    vbroadcasti64x2 ym2, [r0]
    vbroadcasti64x2  m2 {k1}, [r0+r1]
    vbroadcasti64x2 ym3, [r0+2*r1]
    vbroadcasti64x2  m3 {k1}, [r0+r2]
    pshufb           m2, m4
    pshufb           m3, m4
%endif
    VAR_AVX512_CORE %1 ; m0..3
%endmacro

%macro VAR_AVX512_CORE_8x8 1 ; accum ; r0..2, m0..4*
%if HIGH_BIT_DEPTH
    mova            xm2, [r0]
    mova            xm3, [r0+r1]
%else
    movq            xm2, [r0]
    movq            xm3, [r0+r1]
%endif
    vinserti128     ym2, [r0+2*r1], 1
    vinserti128     ym3, [r0+r2], 1
    lea              r0, [r0+4*r1]
    vinserti32x4     m2, [r0], 2
    vinserti32x4     m3, [r0+r1], 2
    vinserti32x4     m2, [r0+2*r1], 3
    vinserti32x4     m3, [r0+r2], 3
%if HIGH_BIT_DEPTH == 0
    punpcklbw        m2, m4
    punpcklbw        m3, m4
%endif
    VAR_AVX512_CORE %1 ; m0..3
%endmacro

INIT_ZMM avx512
cglobal pixel_var_16x16, 2,3
    FIX_STRIDES     r1
%push
%assign %$i 0xf0
%if HIGH_BIT_DEPTH == 0
    PIC_BEGIN r2, 0 ; r2 not used yet, don't save
    vbroadcasti64x4 m4, [pic(var_shuf_avx512)]
    PIC_END
    mov            r2d, %$i
    kmovb           k1, r2d
%endif
    lea             r2, [3*r1] ; r2 is used from here till var_avx512_end
    VAR_AVX512_CORE_16x16 0 ; r0..2, k1, m0..4
%rep %cond(%$i/0x50 > 1, %$i/0x50, 1)
    lea             r0, [r0+4*r1]
    VAR_AVX512_CORE_16x16 1
    %assign %$i %$i-0x50
    %if %$i <= 0
        %exitrep
    %endif
%endrep
%pop
var_avx512_end:
    PIC_BEGIN rax, 0 ; rax isn't used anymore until having retval written to it
    vbroadcasti32x4 m2, [pic(pw_1)]
    PIC_END
    pmaddwd         m0, m2
    SBUTTERFLY      dq, 0, 1, 2
    paddd           m0, m1
    vextracti32x8  ym1, m0, 1
    paddd          ym0, ym1
    vextracti128   xm1, ym0, 1
    paddd         xmm0, xm0, xm1
    punpckhqdq    xmm1, xmm0, xmm0
    paddd         xmm0, xmm1
%if ARCH_X86_64
    movq           rax, xmm0
%else
    movd           eax, xmm0
    pextrd         edx, xmm0, 1
%endif
    RET

%if HIGH_BIT_DEPTH == 0 ; 8x8 doesn't benefit from AVX-512 in high bit-depth
cglobal pixel_var_8x8, 2,3
    lea             r2, [3*r1]
    pxor           xm4, xm4
    VAR_AVX512_CORE_8x8 0 ; r0..2, m0..4*
    jmp var_avx512_end
%endif

cglobal pixel_var_8x16, 2,3
    FIX_STRIDES     r1
    lea             r2, [3*r1]
%if HIGH_BIT_DEPTH == 0
    pxor           xm4, xm4
%endif
    VAR_AVX512_CORE_8x8 0 ; r0..2, m0..4*
    lea             r0, [r0+4*r1]
    VAR_AVX512_CORE_8x8 1
    jmp var_avx512_end

;-----------------------------------------------------------------------------
; int pixel_var2_8x8( pixel *fenc, pixel *fdec, int ssd[2] )
;-----------------------------------------------------------------------------

%if ARCH_X86_64
    DECLARE_REG_TMP 6
%else
    DECLARE_REG_TMP 2
%endif

%macro VAR2_END 3 ; src, tmp, shift ; r2=r2mp, eax, RET
    movifnidn r2, r2mp
    pshufd    %2, %1, q3331
    pmuludq   %1, %1
    movq    [r2], %2 ; sqr_u sqr_v
    psrld     %1, %3
    psubd     %2, %1 ; sqr - (sum * sum >> shift)
    MOVHL     %1, %2
    paddd     %1, %2
    movd     eax, %1
    RET
%endmacro

%macro VAR2_8x8_SSE2 2
%if HIGH_BIT_DEPTH
cglobal pixel_var2_8x%1, 2,3,6
    pxor       m4, m4
    pxor       m5, m5
%define %%sum2 m4
%define %%sqr2 m5
%else
cglobal pixel_var2_8x%1, 2,3,7
    PIC_BEGIN t0, 0 ; t0==r2(edx)-restorable from r2mp / or r6(rax)-retval
    CHECK_REG_COLLISION "rpic","r0","r1","r2mp"
    mova       m6, [pic(pw_00ff)]
    PIC_END
%define %%sum2 m0
%define %%sqr2 m1
%endif
    pxor       m0, m0 ; sum
    pxor       m1, m1 ; sqr
    mov       t0d, (%1-1)*FENC_STRIDEB ; TODO: unroll t0d .loop
.loop:
%if HIGH_BIT_DEPTH
    mova       m2, [r0+1*t0]
    psubw      m2, [r1+2*t0]
    mova       m3, [r0+1*t0+16]
    psubw      m3, [r1+2*t0+32]
%else
    mova       m3, [r0+1*t0]
    movq       m5, [r1+2*t0]
    punpcklqdq m5, [r1+2*t0+16]
    DEINTB      2, 3, 4, 5, 6
    psubw      m2, m4
    psubw      m3, m5
%endif
    paddw      m0, m2
    pmaddwd    m2, m2
    paddw  %%sum2, m3
    pmaddwd    m3, m3
    paddd      m1, m2
    paddd  %%sqr2, m3
    sub       t0d, FENC_STRIDEB
    jge .loop
%if HIGH_BIT_DEPTH
    SBUTTERFLY dq, 0, 4, 2
    paddw      m0, m4 ; sum_u sum_v
    ; * on x86_64 t0==r6(rax): r6/rax is not used from this point until just
    ;   before RET, there retval gets written to eax, old value lost (no need
    ;   saving).
    ; * on x86_32 t0==r2(edx): r2 is not used from here until VAR2_END where
    ;   arg[2] gets written to r2 (mov r2,r2mp), old value lost (no need
    ;   saving).
    PIC_BEGIN t0, 0
    pmaddwd    m0, [pic(pw_1)]
    PIC_END
    SBUTTERFLY dq, 1, 5, 2
    paddd      m1, m5 ; sqr_u sqr_v
    SBUTTERFLY dq, 0, 1, 2
    paddd      m0, m1
%else
    PIC_BEGIN t0, 0
    CHECK_REG_COLLISION "rpic","r2mp"
    pmaddwd    m0, [pic(pw_1)]
    PIC_END
    shufps     m2, m0, m1, q2020
    shufps     m0, m1, q3131
    paddd      m0, m2
    pshufd     m0, m0, q3120 ; sum_u sqr_u sum_v sqr_v
%endif
    VAR2_END   m0, m1, %2 ; r2=r2mp, eax, RET
%endmacro

INIT_XMM sse2
VAR2_8x8_SSE2  8, 6
VAR2_8x8_SSE2 16, 7

%macro VAR2_CORE 3 ; src1, src2, accum ; m0,1
%if %3
    paddw    m0, %1
    pmaddwd  %1, %1
    paddw    m0, %2
    pmaddwd  %2, %2
    paddd    m1, %1
    paddd    m1, %2
%else
    paddw    m0, %1, %2
    pmaddwd  %1, %1
    pmaddwd  %2, %2
    paddd    m1, %1, %2
%endif
%endmacro

%if HIGH_BIT_DEPTH == 0
INIT_XMM ssse3
cglobal pixel_var2_internal
    ; r0,1 and t0 regs are passed to this function
    ; r0,1 are returned unchanged
    ; t0 is clobbered upon return (decremented or used for PIC)
%define lpic      $$  ; start of .text when loaded in mem
%assign lpiccf    1   ; pixel_var2_internal expects $$ in lpiccache
%if ARCH_X86_64
%define lpiccache r3  ; scratch reg (volatile)
%else
    ; x264_X_pixel_var2_internal_ssse3 is called from
    ; x264_X_pixel_var2_8x8_Y, x86_32 stack is as follows:
    ;   stack addr:               var2_8x8:  var2_internal:
    ;   0x...8:                   arg2/r2m   r3m
    ;   0x...4:                   arg1/r1m   r2m
    ;   0x...0 (16-aligned):      arg0/r0m   r1m
    ;   0x...c:                   retaddr    r0m
    ;   0x...8 (esp points here): retaddr2   retaddr
    ; As you can see, pixel_var2_8x8's arg[0] is pixel_var2_internal's arg[1].
    ; So it's possible to define lpiccache as r0m in pixel_var2_8x8,
    ; to define it as r1m in pixel_var2_internal and have both definitions
    ; refer to the same location.
%define lpiccache r1m ; r0m in caller
%endif
    pxor        m0, m0 ; sum
    pxor        m1, m1 ; sqr
.loop:
    movq        m2, [r0+1*t0]
    punpcklbw   m2, [r1+2*t0]
    movq        m3, [r0+1*t0-1*FENC_STRIDE]
    punpcklbw   m3, [r1+2*t0-1*FDEC_STRIDE]
    movq        m4, [r0+1*t0-2*FENC_STRIDE]
    punpcklbw   m4, [r1+2*t0-2*FDEC_STRIDE]
    movq        m5, [r0+1*t0-3*FENC_STRIDE]
    punpcklbw   m5, [r1+2*t0-3*FDEC_STRIDE]
    pmaddubsw   m2, m7
    pmaddubsw   m3, m7
    pmaddubsw   m4, m7
    pmaddubsw   m5, m7
    VAR2_CORE   m2, m3, 1 ; m0..3
    VAR2_CORE   m4, m5, 1 ; m0,1,4,5
    sub        t0d, 4*FENC_STRIDE
    jg .loop
    PIC_BEGIN t0, 0 ; t0 is OK to be clobbered upon return
    CHECK_REG_COLLISION "rpic","r0","r1"
    pmaddwd     m0, [pic(pw_1)]
    PIC_END
    ret

%macro VAR2_8x8_SSSE3 2
cglobal pixel_var2_8x%1, 2,3,8
%if ARCH_X86_64
%define lpiccache r3
%else
%define lpiccache r0m ; this r0m == pixel_var2_internal_ssse3()'s r1m
%endif
    PIC_BEGIN t0, 0, $$ ; t0 is reset later anyways
    CHECK_REG_COLLISION "rpic","r2mp"
    mova        m7, [pic(hsub_mul)]
    PIC_END
    mov        t0d, (%1-1)*FENC_STRIDE ; t0 is reset
    call pixel_var2_internal_ssse3 ; u
    add         r0, 8
    add         r1, 16
    SBUTTERFLY qdq, 0, 1, 6
    paddd       m1, m0
    mov        t0d, (%1-1)*FENC_STRIDE ; t0 is reset
    call pixel_var2_internal_ssse3 ; v
    SBUTTERFLY qdq, 0, 6, 2
    paddd       m0, m6
    phaddd      m1, m0 ; sum_u sqr_u sum_v sqr_v
    VAR2_END    m1, m0, %2 ; r2=r2mp, eax, RET
%endmacro

VAR2_8x8_SSSE3  8, 6
VAR2_8x8_SSSE3 16, 7
%endif ; !HIGH_BIT_DEPTH

%macro VAR2_AVX2_LOAD 3 ; offset_reg, row1_offset, row2_offset ; r0,1; m2..6*
%if HIGH_BIT_DEPTH
%if mmsize == 64
    mova        m2, [r1+2*%1+%2*FDEC_STRIDEB]
    vshufi32x4  m2, [r1+2*%1+%2*FDEC_STRIDEB+64], q2020
    mova        m3, [r1+2*%1+%3*FDEC_STRIDEB]
    vshufi32x4  m3, [r1+2*%1+%3*FDEC_STRIDEB+64], q2020
%else
    mova       xm2, [r1+2*%1+%2*FDEC_STRIDEB]
    vinserti128 m2, [r1+2*%1+%2*FDEC_STRIDEB+32], 1
    mova       xm3, [r1+2*%1+%3*FDEC_STRIDEB]
    vinserti128 m3, [r1+2*%1+%3*FDEC_STRIDEB+32], 1
%endif
    psubw       m2, [r0+1*%1+%2*FENC_STRIDEB]
    psubw       m3, [r0+1*%1+%3*FENC_STRIDEB]
%else ; !HIGH_BIT_DEPTH
    pmovzxbw    m2, [r0+1*%1+%2*FENC_STRIDE]
    mova        m4, [r1+2*%1+%2*FDEC_STRIDE]
    pmovzxbw    m3, [r0+1*%1+%3*FENC_STRIDE]
    mova        m5, [r1+2*%1+%3*FDEC_STRIDE]
    punpcklbw   m4, m6
    punpcklbw   m5, m6
    psubw       m2, m4
    psubw       m3, m5
%endif ; BIT_DEPTH
%endmacro

%macro VAR2_8x8_AVX2 2
%if HIGH_BIT_DEPTH
cglobal pixel_var2_8x%1, 2,3,4
%else
cglobal pixel_var2_8x%1, 2,3,7
    pxor           m6, m6
%endif
    mov           t0d, (%1-3)*FENC_STRIDEB
    VAR2_AVX2_LOAD t0, 2, 1 ; r0,1; t0, m2..6*
    VAR2_CORE      m2, m3, 0 ; m0..3
.loop:
    VAR2_AVX2_LOAD t0, 0, -1
    VAR2_CORE      m2, m3, 1
    sub           t0d, 2*FENC_STRIDEB
    jg .loop

    PIC_BEGIN t0, 0 ; t0 not used anymore till VAR2_END
    CHECK_REG_COLLISION "rpic","r2mp"
    pmaddwd        m0, [pic(pw_1)]
    PIC_END
    SBUTTERFLY    qdq, 0, 1, 2
    paddd          m0, m1
    vextracti128  xm1, m0, 1
    phaddd        xm0, xm1
    VAR2_END      xm0, xm1, %2 ; r2=r2mp, eax, RET
%endmacro

INIT_YMM avx2
VAR2_8x8_AVX2  8, 6
VAR2_8x8_AVX2 16, 7

%macro VAR2_AVX512_END 1 ; shift ; PIC:rax,0, r2=r2mp, eax, RET
    PIC_BEGIN rax, 0
    CHECK_REG_COLLISION "rpic","r2mp"
    vbroadcasti32x4 m2, [pic(pw_1)]
    PIC_END
    pmaddwd         m0, m2
    SBUTTERFLY     qdq, 0, 1, 2
    paddd           m0, m1
    vextracti32x8  ym1, m0, 1
    paddd          ym0, ym1
    psrlq          ym1, ym0, 32
    paddd          ym0, ym1
    vpmovqd       xmm0, ym0 ; sum_u, sqr_u, sum_v, sqr_v
    VAR2_END      xmm0, xmm1, %1 ; r2=r2mp, eax, RET
%endmacro

INIT_ZMM avx512
cglobal pixel_var2_8x8, 2,3
%if HIGH_BIT_DEPTH == 0
    pxor          xm6, xm6
%endif
    VAR2_AVX2_LOAD  0, 0, 2   ; r0,1; m2..6*
    VAR2_CORE      m2, m3, 0  ; m0..3
    VAR2_AVX2_LOAD  0, 4, 6
    VAR2_CORE      m2, m3, 1
    VAR2_AVX512_END 6 ; PIC:rax,0, r2=r2mp, eax, RET

cglobal pixel_var2_8x16, 2,3
%if HIGH_BIT_DEPTH == 0
    pxor          xm6, xm6
%endif
    mov           t0d, 10*FENC_STRIDEB
    VAR2_AVX2_LOAD  0, 14, 12 ; r0,1; m2..6*
    VAR2_CORE      m2, m3, 0  ; m0..3
.loop:
    VAR2_AVX2_LOAD t0, 0, -2  ; r0,1; t0, m2..6*
    VAR2_CORE      m2, m3, 1
    sub           t0d, 4*FENC_STRIDEB
    jg .loop
    VAR2_AVX512_END 7 ; PIC:rax,0, r2=r2mp, eax, RET

;=============================================================================
; SATD
;=============================================================================

%macro JDUP 2
%if cpuflag(sse4)
    ; just use shufps on anything post conroe
    shufps %1, %2, 0
%elif cpuflag(ssse3) && notcpuflag(atom)
    ; join 2x 32 bit and duplicate them
    ; emulating shufps is faster on conroe
    punpcklqdq %1, %2
    movsldup %1, %1
%else
    ; doesn't need to dup. sse2 does things by zero extending to words and full h_2d
    punpckldq %1, %2
%endif
%endmacro

%macro HSUMSUB 5
    pmaddubsw m%2, m%5
    pmaddubsw m%1, m%5
    pmaddubsw m%4, m%5
    pmaddubsw m%3, m%5
%endmacro

%macro DIFF_UNPACK_SSE2 5
    punpcklbw m%1, m%5
    punpcklbw m%2, m%5
    punpcklbw m%3, m%5
    punpcklbw m%4, m%5
    psubw m%1, m%2
    psubw m%3, m%4
%endmacro

%macro DIFF_SUMSUB_SSSE3 5
    HSUMSUB %1, %2, %3, %4, %5
    psubw m%1, m%2
    psubw m%3, m%4
%endmacro

%macro LOAD_DUP_2x4P 4 ; dst, tmp, 2* pointer
    movd %1, %3
    movd %2, %4
    JDUP %1, %2
%endmacro

%macro LOAD_DUP_4x8P_CONROE 8 ; 4*dst, 4*pointer
    movddup m%3, %6
    movddup m%4, %8
    movddup m%1, %5
    movddup m%2, %7
%endmacro

%macro LOAD_DUP_4x8P_PENRYN 8
    ; penryn and nehalem run punpcklqdq and movddup in different units
    movh m%3, %6
    movh m%4, %8
    punpcklqdq m%3, m%3
    movddup m%1, %5
    punpcklqdq m%4, m%4
    movddup m%2, %7
%endmacro

%macro LOAD_SUMSUB_8x2P 9
    LOAD_DUP_4x8P %1, %2, %3, %4, %6, %7, %8, %9
    DIFF_SUMSUB_SSSE3 %1, %3, %2, %4, %5
%endmacro

%macro LOAD_SUMSUB_8x4P_SSSE3 7-11 r0, r2, 0, 0 ; r1, r3..r5
; 4x dest, 2x tmp, 1x mul, [2* ptr], [increment?]
    LOAD_SUMSUB_8x2P %1, %2, %5, %6, %7, [%8], [%9], [%8+r1], [%9+r3]
    LOAD_SUMSUB_8x2P %3, %4, %5, %6, %7, [%8+2*r1], [%9+2*r3], [%8+r4], [%9+r5]
%if %10
    lea %8, [%8+4*r1]
    lea %9, [%9+4*r3]
%endif
%endmacro

%macro LOAD_SUMSUB_16P_SSSE3 7 ; 2*dst, 2*tmp, mul, 2*ptr
    movddup m%1, [%7]
    movddup m%2, [%7+8]
    mova m%4, [%6]
    movddup m%3, m%4
    punpckhqdq m%4, m%4
    DIFF_SUMSUB_SSSE3 %1, %3, %2, %4, %5
%endmacro

%macro LOAD_SUMSUB_16P_SSE2 7 ; 2*dst, 2*tmp, mask, 2*ptr
    movu  m%4, [%7]
    mova  m%2, [%6]
    DEINTB %1, %2, %3, %4, %5
    psubw m%1, m%3
    psubw m%2, m%4
    SUMSUB_BA w, %1, %2, %3
%endmacro

%macro LOAD_SUMSUB_16x4P 10-13 r0, r2, none ; r1, r3..r5
; 8x dest, 1x tmp, 1x mul, [2* ptr] [2nd tmp]
    LOAD_SUMSUB_16P %1, %5, %2, %3, %10, %11, %12
    LOAD_SUMSUB_16P %2, %6, %3, %4, %10, %11+r1, %12+r3
    LOAD_SUMSUB_16P %3, %7, %4, %9, %10, %11+2*r1, %12+2*r3
    LOAD_SUMSUB_16P %4, %8, %13, %9, %10, %11+r4, %12+r5
%endmacro

%macro LOAD_SUMSUB_16x2P_AVX2 9
; 2*dst, 2*tmp, mul, 4*ptr
    vbroadcasti128 m%1, [%6]
    vbroadcasti128 m%3, [%7]
    vbroadcasti128 m%2, [%8]
    vbroadcasti128 m%4, [%9]
    DIFF_SUMSUB_SSSE3 %1, %3, %2, %4, %5
%endmacro

%macro LOAD_SUMSUB_16x4P_AVX2 7-11 r0, r2, 0, 0 ; r1, r3..r5
; 4x dest, 2x tmp, 1x mul, [2* ptr], [increment?]
    LOAD_SUMSUB_16x2P_AVX2 %1, %2, %5, %6, %7, %8, %9, %8+r1, %9+r3
    LOAD_SUMSUB_16x2P_AVX2 %3, %4, %5, %6, %7, %8+2*r1, %9+2*r3, %8+r4, %9+r5
%if %10
    lea  %8, [%8+4*r1]
    lea  %9, [%9+4*r3]
%endif
%endmacro

%macro LOAD_DUP_4x16P_AVX2 8 ; 4*dst, 4*pointer
    mova  xm%3, %6
    mova  xm%4, %8
    mova  xm%1, %5
    mova  xm%2, %7
    vpermq m%3, m%3, q0011
    vpermq m%4, m%4, q0011
    vpermq m%1, m%1, q0011
    vpermq m%2, m%2, q0011
%endmacro

%macro LOAD_SUMSUB8_16x2P_AVX2 9
; 2*dst, 2*tmp, mul, 4*ptr
    LOAD_DUP_4x16P_AVX2 %1, %2, %3, %4, %6, %7, %8, %9
    DIFF_SUMSUB_SSSE3 %1, %3, %2, %4, %5
%endmacro

%macro LOAD_SUMSUB8_16x4P_AVX2 7-11 r0, r2, 0, 0 ; r1, r3..r5
; 4x dest, 2x tmp, 1x mul, [2* ptr], [increment?]
    LOAD_SUMSUB8_16x2P_AVX2 %1, %2, %5, %6, %7, [%8], [%9], [%8+r1], [%9+r3]
    LOAD_SUMSUB8_16x2P_AVX2 %3, %4, %5, %6, %7, [%8+2*r1], [%9+2*r3], [%8+r4], [%9+r5]
%if %10
    lea  %8, [%8+4*r1]
    lea  %9, [%9+4*r3]
%endif
%endmacro

; in: r4=3*stride1, r5=3*stride2
; in: %2 = horizontal offset
; in: %3 = whether we need to increment pix1 and pix2
; clobber: m3..m7
; out: %1 = satd
%macro SATD_4x4_MMX 3 ; r0..r5
    %xdefine %%n nn%1
    %assign offset %2*SIZEOF_PIXEL
    LOAD_DIFF m4, m3, none, [r0+     offset], [r2+     offset]
    LOAD_DIFF m5, m3, none, [r0+  r1+offset], [r2+  r3+offset]
    LOAD_DIFF m6, m3, none, [r0+2*r1+offset], [r2+2*r3+offset]
    LOAD_DIFF m7, m3, none, [r0+  r4+offset], [r2+  r5+offset]
%if %3
    lea  r0, [r0+4*r1]
    lea  r2, [r2+4*r3]
%endif
    HADAMARD4_2D 4, 5, 6, 7, 3, %%n
    paddw m4, m6
    SWAP %%n, 4
%endmacro

; in: %1 = horizontal if 0, vertical if 1
%macro SATD_8x4_SSE 8-9 ; PIC*
%if %1
    HADAMARD4_2D_SSE %2, %3, %4, %5, %6, amax
%else
    HADAMARD4_V %2, %3, %4, %5, %6
    ; doing the abs first is a slight advantage
    ABSW2 m%2, m%4, m%2, m%4, m%6, m%7
    ABSW2 m%3, m%5, m%3, m%5, m%6, m%7
    HADAMARD 1, max, %2, %4, %6, %7 ; PIC*
%endif
%ifnidn %9, swap
    paddw m%8, m%2
%else
    SWAP %8, %2
%endif
%if %1
    paddw m%8, m%4
%else
    HADAMARD 1, max, %3, %5, %6, %7 ; PIC*
    paddw m%8, m%3
%endif
%endmacro

%macro SATD_START_MMX 0 ; r1, r3..r5
    FIX_STRIDES r1, r3
    lea  r4, [3*r1] ; 3*stride1
    lea  r5, [3*r3] ; 3*stride2
%endmacro

%macro SATD_END_MMX 0 ; eax, RET
%if HIGH_BIT_DEPTH
    HADDUW      m0, m1
    movd       eax, m0
%else ; !HIGH_BIT_DEPTH
    pshufw      m1, m0, q1032
    paddw       m0, m1
    pshufw      m1, m0, q2301
    paddw       m0, m1
    movd       eax, m0
    and        eax, 0xffff
%endif ; HIGH_BIT_DEPTH
    RET
%endmacro

; FIXME avoid the spilling of regs to hold 3*stride.
; for small blocks on x86_32, modify pixel pointer instead.

;-----------------------------------------------------------------------------
; int pixel_satd_16x16( uint8_t *, intptr_t, uint8_t *, intptr_t )
;-----------------------------------------------------------------------------
INIT_MMX mmx2
cglobal pixel_satd_16x4_internal
    SATD_4x4_MMX m2,  0, 0
    SATD_4x4_MMX m1,  4, 0
    paddw        m0, m2
    SATD_4x4_MMX m2,  8, 0
    paddw        m0, m1
    SATD_4x4_MMX m1, 12, 0
    paddw        m0, m2
    paddw        m0, m1
    ret

cglobal pixel_satd_8x8_internal
    SATD_4x4_MMX m2,  0, 0
    SATD_4x4_MMX m1,  4, 1
    paddw        m0, m2
    paddw        m0, m1
pixel_satd_8x4_internal_mmx2:
    SATD_4x4_MMX m2,  0, 0
    SATD_4x4_MMX m1,  4, 0
    paddw        m0, m2
    paddw        m0, m1
    ret

%if HIGH_BIT_DEPTH
%macro SATD_MxN_MMX 3
cglobal pixel_satd_%1x%2, 4,7
    SATD_START_MMX
    pxor   m0, m0
    call pixel_satd_%1x%3_internal_mmx2
    HADDUW m0, m1
    movd  r6d, m0
%rep %2/%3-1
    pxor   m0, m0
    lea    r0, [r0+4*r1]
    lea    r2, [r2+4*r3]
    call pixel_satd_%1x%3_internal_mmx2
    movd   m2, r4
    HADDUW m0, m1
    movd   r4, m0
    add    r6, r4
    movd   r4, m2
%endrep
    movifnidn eax, r6d
    RET
%endmacro

SATD_MxN_MMX 16, 16, 4
SATD_MxN_MMX 16,  8, 4
SATD_MxN_MMX  8, 16, 8
%endif ; HIGH_BIT_DEPTH

%if HIGH_BIT_DEPTH == 0
cglobal pixel_satd_16x16, 4,6
    SATD_START_MMX
    pxor   m0, m0
%rep 3
    call pixel_satd_16x4_internal_mmx2
    lea  r0, [r0+4*r1]
    lea  r2, [r2+4*r3]
%endrep
    call pixel_satd_16x4_internal_mmx2
    HADDUW m0, m1
    movd  eax, m0
    RET

cglobal pixel_satd_16x8, 4,6
    SATD_START_MMX
    pxor   m0, m0
    call pixel_satd_16x4_internal_mmx2
    lea  r0, [r0+4*r1]
    lea  r2, [r2+4*r3]
    call pixel_satd_16x4_internal_mmx2
    SATD_END_MMX

cglobal pixel_satd_8x16, 4,6
    SATD_START_MMX
    pxor   m0, m0
    call pixel_satd_8x8_internal_mmx2
    lea  r0, [r0+4*r1]
    lea  r2, [r2+4*r3]
    call pixel_satd_8x8_internal_mmx2
    SATD_END_MMX
%endif ; !HIGH_BIT_DEPTH

cglobal pixel_satd_8x8, 4,6
    SATD_START_MMX
    pxor   m0, m0
    call pixel_satd_8x8_internal_mmx2
    SATD_END_MMX

cglobal pixel_satd_8x4, 4,6
    SATD_START_MMX
    pxor   m0, m0
    call pixel_satd_8x4_internal_mmx2
    SATD_END_MMX

cglobal pixel_satd_4x16, 4,6
    SATD_START_MMX
    SATD_4x4_MMX m0, 0, 1
    SATD_4x4_MMX m1, 0, 1
    paddw  m0, m1
    SATD_4x4_MMX m1, 0, 1
    paddw  m0, m1
    SATD_4x4_MMX m1, 0, 0
    paddw  m0, m1
    SATD_END_MMX

cglobal pixel_satd_4x8, 4,6
    SATD_START_MMX
    SATD_4x4_MMX m0, 0, 1
    SATD_4x4_MMX m1, 0, 0
    paddw  m0, m1
    SATD_END_MMX

cglobal pixel_satd_4x4, 4,6
    SATD_START_MMX
    SATD_4x4_MMX m0, 0, 0
    SATD_END_MMX

%macro SATD_START_SSE2 2-3 0 ; r1, r3..r5, PIC*
    FIX_STRIDES r1, r3
%if HIGH_BIT_DEPTH && %3
    pxor    %2, %2
%elif cpuflag(ssse3) && notcpuflag(atom)
    PIC_BEGIN r4
    ; %2 is *mm (%2 is dest in pxor)
%if mmsize==32
    mova    %2, [pic(hmul_16p)]
%else
    mova    %2, [pic(hmul_8p)]
%endif
    PIC_END
%endif
    lea     r4, [3*r1]
    lea     r5, [3*r3]
    pxor    %1, %1
%endmacro

%macro SATD_END_SSE2 1-2 ; PIC*, PIC_END*, eax, RET
%if HIGH_BIT_DEPTH
    HADDUW  %1, xm0
%if %0 == 2
    paddd   %1, %2
%endif
%else
    ; If not inside PIC_BEGIN/END block and no designated rpic:
    %if picb<1 && %isidn(%str(dpic), "dpic")
	; Designate rax for no-save PIC as it's retval'ed later:
        CHECK_REG_COLLISION "rax",%1
	DESIGNATE_RPIC rax
    %endif
    HADDW   %1, xm7 ; PIC*:r4,1 / designated:rax,0
%endif
    %if picb == 1
        PIC_END
    %endif
    movd   eax, %1 ; eax is reset by retval; if rpic==rax, can forego saving
    RET
%endmacro

%macro SATD_ACCUM 3
%if HIGH_BIT_DEPTH
    HADDUW %1, %2
    paddd  %3, %1
    pxor   %1, %1
%endif
%endmacro

%macro BACKUP_POINTERS 0 ; r0, r2, r6, r7, stack
%if ARCH_X86_64
%if WIN64
    PUSH r7
%endif
    mov     r6, r0
    mov     r7, r2
%endif
%endmacro

%macro RESTORE_AND_INC_POINTERS 0 ; r0, r2, r6, r7, stack
%if ARCH_X86_64
    lea     r0, [r6+8*SIZEOF_PIXEL]
    lea     r2, [r7+8*SIZEOF_PIXEL]
%if WIN64
    POP r7
%endif
%else
    mov     r0, r0mp
    mov     r2, r2mp
    add     r0, 8*SIZEOF_PIXEL
    add     r2, 8*SIZEOF_PIXEL
%endif
%endmacro

%macro SATD_4x8_SSE 3 ; r0..r5, PIC*
%if HIGH_BIT_DEPTH
    movh    m0, [r0+0*r1]
    movh    m4, [r2+0*r3]
    movh    m1, [r0+1*r1]
    movh    m5, [r2+1*r3]
    movhps  m0, [r0+4*r1]
    movhps  m4, [r2+4*r3]
    movh    m2, [r0+2*r1]
    movh    m6, [r2+2*r3]
    psubw   m0, m4
    movh    m3, [r0+r4]
    movh    m4, [r2+r5]
    lea     r0, [r0+4*r1]
    lea     r2, [r2+4*r3]
    movhps  m1, [r0+1*r1]
    movhps  m5, [r2+1*r3]
    movhps  m2, [r0+2*r1]
    movhps  m6, [r2+2*r3]
    psubw   m1, m5
    movhps  m3, [r0+r4]
    movhps  m4, [r2+r5]
    psubw   m2, m6
    psubw   m3, m4
%else ; !HIGH_BIT_DEPTH
    movd m4, [r2]
    movd m5, [r2+r3]
    movd m6, [r2+2*r3]
    add r2, r5
    movd m0, [r0]
    movd m1, [r0+r1]
    movd m2, [r0+2*r1]
    add r0, r4
    movd m3, [r2+r3]
    JDUP m4, m3
    movd m3, [r0+r1]
    JDUP m0, m3
    movd m3, [r2+2*r3]
    JDUP m5, m3
    movd m3, [r0+2*r1]
    JDUP m1, m3
%if %1==0 && %2==1
    PIC_BEGIN r4
    mova m3, [pic(hmul_4p)]
    PIC_END
    DIFFOP 0, 4, 1, 5, 3
%else
    DIFFOP 0, 4, 1, 5, 7
%endif
    movd m5, [r2]
    add r2, r5
    movd m3, [r0]
    add r0, r4
    movd m4, [r2]
    JDUP m6, m4
    movd m4, [r0]
    JDUP m2, m4
    movd m4, [r2+r3]
    JDUP m5, m4
    movd m4, [r0+r1]
    JDUP m3, m4
%if %1==0 && %2==1
    PIC_BEGIN r4
    mova m4, [pic(hmul_4p)]
    PIC_END
    DIFFOP 2, 6, 3, 5, 4
%else
    DIFFOP 2, 6, 3, 5, 7
%endif
%endif ; BIT_DEPTH
    SATD_8x4_SSE %1, 0, 1, 2, 3, 4, 5, 7, %3 ; PIC*
%endmacro

;-----------------------------------------------------------------------------
; int pixel_satd_8x4( uint8_t *, intptr_t, uint8_t *, intptr_t )
;-----------------------------------------------------------------------------
%macro SATDS_SSE2 0
%define vertical ((notcpuflag(ssse3) || cpuflag(atom)) || HIGH_BIT_DEPTH)

%if cpuflag(ssse3) && (vertical==0 || HIGH_BIT_DEPTH)
cglobal pixel_satd_4x4, 4, 6, 6
    SATD_START_MMX
    ; x264_{8,10}_pixel_satd_4x4_ssse3 don't use ebp:
    ; objdump -dr pixel-a-8.o pixel-a-10.o \
         | awk '/pixel_satd_4x4.*:\n/ {print}' RS= \
         | grep ebp
    %define rpicsave ; safe to push/pop rpic
    PIC_BEGIN r6
    mova m4, [pic(hmul_4p)]
    LOAD_DUP_2x4P m2, m5, [r2], [r2+r3]
    LOAD_DUP_2x4P m3, m5, [r2+2*r3], [r2+r5]
    LOAD_DUP_2x4P m0, m5, [r0], [r0+r1]
    LOAD_DUP_2x4P m1, m5, [r0+2*r1], [r0+r4]
    DIFF_SUMSUB_SSSE3 0, 2, 1, 3, 4
    HADAMARD 0, sumsub, 0, 1, 2, 3 ; PIC*, won't trigger
    HADAMARD 4, sumsub, 0, 1, 2, 3 ; PIC*, won't trigger
    HADAMARD 1, amax, 0, 1, 2, 3 ; PIC*
    HADDW m0, m1 ; PIC*
    PIC_END
    movd eax, m0
    RET
%endif

cglobal pixel_satd_4x8, 4, 6, 8
    SATD_START_MMX
    ; x264_8_pixel_satd_4x8_{sse2,ssse3_atom,ssse3,sse4,avx,xop}
    ; x264_10_pixel_satd_4x8_{sse2,ssse3,sse4,avx}
    ; don't use ebp
    %define rpicsave ; safe to push/pop rpic
    PIC_BEGIN r6
%if vertical==0
    mova m7, [pic(hmul_4p)]
%endif
    SATD_4x8_SSE vertical, 0, swap ; PIC*
    HADDW m7, m1 ; PIC*
    PIC_END
    movd eax, m7
    RET

cglobal pixel_satd_4x16, 4, 6, 8
    SATD_START_MMX
    ; x264_8_pixel_satd_4x16_{sse2,ssse3_atom,ssse3,sse4,avx,xop}
    ; x264_10_pixel_satd_4x16_{sse2,ssse3,sse4,avx}
    ; don't use ebp
    %define rpicsave ; safe to push/pop rpic
    PIC_BEGIN r6
%if vertical==0
    mova m7, [pic(hmul_4p)]
%endif
    SATD_4x8_SSE vertical, 0, swap ; PIC*
    lea r0, [r0+r1*2*SIZEOF_PIXEL]
    lea r2, [r2+r3*2*SIZEOF_PIXEL]
    SATD_4x8_SSE vertical, 1, add ; PIC*
    HADDW m7, m1 ; PIC*
    PIC_END
    movd eax, m7
    RET

; in: r0..5, r6=$$ (PIC)
cglobal pixel_satd_8x8_internal
%if i386pic
    %assign  picb  1
    %xdefine rpic  r6
    %xdefine lpic $$
%endif
    LOAD_SUMSUB_8x4P 0, 1, 2, 3, 4, 5, 7, r0, r2, 1, 0
    SATD_8x4_SSE vertical, 0, 1, 2, 3, 4, 5, 6 ; PIC*
%%pixel_satd_8x4_internal:
    LOAD_SUMSUB_8x4P 0, 1, 2, 3, 4, 5, 7, r0, r2, 1, 0
    SATD_8x4_SSE vertical, 0, 1, 2, 3, 4, 5, 6 ; PIC*
%if i386pic
    %assign picb 0
    %undef  rpic
    %undef  lpic
%endif
    ret

; 16x8 regresses on phenom win64, 16x16 is almost the same (too many spilled registers)
; These aren't any faster on AVX systems with fast movddup (Bulldozer, Sandy Bridge)
%if HIGH_BIT_DEPTH == 0 && UNIX64 && notcpuflag(avx)
cglobal pixel_satd_16x4_internal
    LOAD_SUMSUB_16x4P 0, 1, 2, 3, 4, 8, 5, 9, 6, 7, r0, r2, 11
    lea  r2, [r2+4*r3]
    lea  r0, [r0+4*r1]
    ; always use horizontal mode here
    SATD_8x4_SSE 0, 0, 1, 2, 3, 6, 11, 10
    SATD_8x4_SSE 0, 4, 8, 5, 9, 6, 3, 10
    ret

cglobal pixel_satd_16x8, 4,6,12
    SATD_START_SSE2 m10, m7
%if vertical
    mova m7, [pw_00ff]
%endif
    jmp %%pixel_satd_16x8_internal

cglobal pixel_satd_16x16, 4,6,12
    SATD_START_SSE2 m10, m7
%if vertical
    mova m7, [pw_00ff]
%endif
    call pixel_satd_16x4_internal
    call pixel_satd_16x4_internal
%%pixel_satd_16x8_internal:
    call pixel_satd_16x4_internal
    call pixel_satd_16x4_internal
    SATD_END_SSE2 m10

%else ; HIGH_BIT_DEPTH || !UNIX64 || cpuflag(avx)

cglobal pixel_satd_16x8, 4,6,8
    %define rpicsave ; safe to push/pop rpic
    PIC_BEGIN r6, 1, $$
    SATD_START_SSE2 m6, m7
    BACKUP_POINTERS
    call pixel_satd_8x8_internal ; pass r6=$$
    RESTORE_AND_INC_POINTERS
    call pixel_satd_8x8_internal
    SATD_END_SSE2 m6 ; PIC*, PIC_END*, eax, RET

cglobal pixel_satd_16x16, 4,6,8
    %define rpicsave ; safe to push/pop rpic
    PIC_BEGIN r6, 1, $$
    SATD_START_SSE2 m6, m7, 1
    BACKUP_POINTERS
    call pixel_satd_8x8_internal ; pass r6=$$
    call pixel_satd_8x8_internal
    SATD_ACCUM m6, m0, m7
    RESTORE_AND_INC_POINTERS
    call pixel_satd_8x8_internal
    call pixel_satd_8x8_internal
    SATD_END_SSE2 m6, m7 ; PIC*, PIC_END*, eax, RET

%endif ; HIGH_BIT_DEPTH, UNIX64, cpuflag(avx)

cglobal pixel_satd_8x16, 4,6,8
    %define rpicsave ; safe to push/pop rpic
    PIC_BEGIN r6, 1, $$
    SATD_START_SSE2 m6, m7
    call pixel_satd_8x8_internal ; pass r6=$$
    call pixel_satd_8x8_internal
    SATD_END_SSE2 m6 ; PIC*, PIC_END*, RET

cglobal pixel_satd_8x8, 4,6,8
    %define rpicsave ; safe to push/pop rpic
    PIC_BEGIN r6, 1, $$
    SATD_START_SSE2 m6, m7
    call pixel_satd_8x8_internal ; pass r6=$$
    SATD_END_SSE2 m6 ; PIC*, PIC_END*, eax, RET

cglobal pixel_satd_8x4, 4,6,8
    %define rpicsave ; safe to push/pop rpic
    PIC_BEGIN r6, 1, $$
    SATD_START_SSE2 m6, m7
    call %%pixel_satd_8x4_internal ; pass r6=$$
    SATD_END_SSE2 m6 ; PIC*, PIC_END*, eax, RET
%endmacro ; SATDS_SSE2

%macro SA8D_INTER 0 ; %def rh [esp+48]*
%if ARCH_X86_64
    %define lh m10
    %define rh m0
%else
    %define lh m0
    %define rh [esp+48]
    %undef rpicsave ; unsafe to push rpic after %define rh [esp+48]
%endif
%if HIGH_BIT_DEPTH
    HADDUW  m0, m1
    paddd   lh, rh
%else
    paddusw lh, rh
%endif
%endmacro

%macro SA8D 0
; sse2 doesn't seem to like the horizontal way of doing things
%define vertical ((notcpuflag(ssse3) || cpuflag(atom)) || HIGH_BIT_DEPTH)

%if ARCH_X86_64
;-----------------------------------------------------------------------------
; int pixel_sa8d_8x8( uint8_t *, intptr_t, uint8_t *, intptr_t )
;-----------------------------------------------------------------------------
cglobal pixel_sa8d_8x8_internal
    lea  r6, [r0+4*r1]
    lea  r7, [r2+4*r3]
    LOAD_SUMSUB_8x4P 0, 1, 2, 8, 5, 6, 7, r0, r2
    LOAD_SUMSUB_8x4P 4, 5, 3, 9, 11, 6, 7, r6, r7
%if vertical
    HADAMARD8_2D 0, 1, 2, 8, 4, 5, 3, 9, 6, amax
%else ; non-sse2
    HADAMARD8_2D_HMUL 0, 1, 2, 8, 4, 5, 3, 9, 6, 11
%endif
    paddw m0, m1
    paddw m0, m2
    paddw m0, m8
    SAVE_MM_PERMUTATION
    ret

cglobal pixel_sa8d_8x8, 4,8,12
    FIX_STRIDES r1, r3
    lea  r4, [3*r1]
    lea  r5, [3*r3]
%if vertical == 0
    mova m7, [hmul_8p]
%endif
    call pixel_sa8d_8x8_internal
%if HIGH_BIT_DEPTH
    HADDUW m0, m1
%else
    HADDW m0, m1
%endif ; HIGH_BIT_DEPTH
    movd eax, m0
    add eax, 1
    shr eax, 1
    RET

cglobal pixel_sa8d_16x16, 4,8,12
    FIX_STRIDES r1, r3
    lea  r4, [3*r1]
    lea  r5, [3*r3]
%if vertical == 0
    mova m7, [hmul_8p]
%endif
    call pixel_sa8d_8x8_internal ; pix[0]
    add  r2, 8*SIZEOF_PIXEL
    add  r0, 8*SIZEOF_PIXEL
%if HIGH_BIT_DEPTH
    HADDUW m0, m1
%endif
    mova m10, m0
    call pixel_sa8d_8x8_internal ; pix[8]
    lea  r2, [r2+8*r3]
    lea  r0, [r0+8*r1]
    SA8D_INTER
    call pixel_sa8d_8x8_internal ; pix[8*stride+8]
    sub  r2, 8*SIZEOF_PIXEL
    sub  r0, 8*SIZEOF_PIXEL
    SA8D_INTER
    call pixel_sa8d_8x8_internal ; pix[8*stride]
    SA8D_INTER
    SWAP 0, 10
%if HIGH_BIT_DEPTH == 0
    HADDUW m0, m1
%endif
    movd eax, m0
    add  eax, 1
    shr  eax, 1
    RET

%else ; !ARCH_X86_64

%if mmsize == 16
cglobal pixel_sa8d_8x8_internal
    %define spill0 [esp+4]
    %define spill1 [esp+20]
    %define spill2 [esp+36]
    ; %define tmp3 [esp+52]   ; unused in the pixel_sa8d_8x8_internal, but used
                              ; by pixel_sa8d_16x16, which calls
                              ; pixel_sa8d_8x8_internal
    %define rpicsave [esp+68] ; alloc rpicsave just above tmp3
    ; Upon entry into pixel_sa8d_8x8_internal() we have in stack:
    ; ...0 rpicsave   [esp+68] ; rpicsave area allocated by caller
    ; ...0 tmp3       [esp+52] ; temporary area used by one of callers
    ; ...0 spill2     [esp+36] ;
    ; ...0 spill1     [esp+20] ; spill0..2 allocated for us by caller
    ; ...0 spill0     [esp+4]  ;
    ; ...c retadddr   [esp]    ; return address for ret
%if vertical
    LOAD_DIFF_8x4P 0, 1, 2, 3, 4, 5, 6, r0, r2, 1
    HADAMARD4_2D 0, 1, 2, 3, 4
    movdqa spill0, m3
    LOAD_DIFF_8x4P 4, 5, 6, 7, 3, 3, 2, r0, r2, 1
    HADAMARD4_2D 4, 5, 6, 7, 3
    HADAMARD2_2D 0, 4, 1, 5, 3, qdq, amax
    movdqa m3, spill0
    paddw m0, m1
    HADAMARD2_2D 2, 6, 3, 7, 5, qdq, amax
%else ; horizontal
    PIC_BEGIN
    mova m7, [pic(hmul_8p)]
    PIC_END
    LOAD_SUMSUB_8x4P 0, 1, 2, 3, 5, 6, 7, r0, r2, 1
    ; could do first HADAMARD4_V here to save spilling later
    ; surprisingly, not a win on conroe or even p4
    mova spill0, m2
    mova spill1, m3
    mova spill2, m1
    SWAP 1, 7
    LOAD_SUMSUB_8x4P 4, 5, 6, 7, 2, 3, 1, r0, r2, 1
    HADAMARD4_V 4, 5, 6, 7, 3
    mova m1, spill2
    mova m2, spill0
    mova m3, spill1
    mova spill0, m6
    mova spill1, m7
    HADAMARD4_V 0, 1, 2, 3, 7
    SUMSUB_BADC w, 0, 4, 1, 5, 7
    HADAMARD 2, sumsub, 0, 4, 7, 6 ; PIC*
    HADAMARD 2, sumsub, 1, 5, 7, 6 ; PIC*
    HADAMARD 1, amax, 0, 4, 7, 6 ; PIC*
    HADAMARD 1, amax, 1, 5, 7, 6 ; PIC*
    mova m6, spill0
    mova m7, spill1
    paddw m0, m1
    SUMSUB_BADC w, 2, 6, 3, 7, 4
    HADAMARD 2, sumsub, 2, 6, 4, 5 ; PIC*
    HADAMARD 2, sumsub, 3, 7, 4, 5 ; PIC*
    HADAMARD 1, amax, 2, 6, 4, 5 ; PIC*
    HADAMARD 1, amax, 3, 7, 4, 5 ; PIC*
%endif ; sse2/non-sse2
    paddw m0, m2
    paddw m0, m3
    SAVE_MM_PERMUTATION
    ret
%endif ; ifndef mmx2

cglobal pixel_sa8d_8x8, 4,7
    FIX_STRIDES r1, r3
    mov    r6, esp
    sub   esp, gprsize  ; allocate space for rpicsave
    and   esp, ~15      ; align
    sub   esp, 64       ; alloc spill0..spill2+tmp3
    %define rpicsave [esp+64] ; alloc rpicsave just above tmp3
    lea    r4, [3*r1]
    lea    r5, [3*r3]
    call pixel_sa8d_8x8_internal
%if HIGH_BIT_DEPTH
    HADDUW m0, m1
%else
    HADDW  m0, m1 ; PIC*
%endif ; HIGH_BIT_DEPTH
    movd  eax, m0
    add   eax, 1
    shr   eax, 1
    mov   esp, r6
    RET

cglobal pixel_sa8d_16x16, 4,7
    FIX_STRIDES r1, r3
    mov    r6, esp      ; save 'pre-alloc' esp in r6
    sub   esp, gprsize  ; allocate space for rpicsave
    and   esp, ~15      ; align
    sub   esp, 64       ; alloc spill0..spill2+tmp3/rh
    ; %define rpicsave [esp+64] ; alloc rpicsave just above tmp3/rh
    ; ...c arg4       [r6+32]
    ; ...8 arg3       [r6+28]
    ; ...4 arg2       [r6+24]
    ; ...0 arg1       [r6+20]
    ; ...c retaddr    [r6+16]   <- esp0: esp at pixel_sa8d_16x16() entry point
    ; ...8 pushed ebx [r6+12]
    ; ...4 pushed esi [r6+8]
    ; ...0 pushed edi [r6+4]
    ; ...c pushed ebp [r6]      <- r6 == (esp1: esp after PROLOGUE 4,7)
    ; ...8 ..4bytes..           <- (esp1-gprsize) ; rpicsave size
    ; ...4 ..4bytes..
    ; ...0 rpicsave   [esp2+64] <- (esp1-gprsize) & ~15 ; aligned
    ; ...8      tmp3h [esp2+56]
    ; ...0 tmp3       [esp2+48]
    ; ...8   spill2h
    ; ...0 spill2     [esp2+32]
    ; ...8   spill1h
    ; ...0 spill1     [esp2+16]
    ; ...8   spill0h
    ; ...0 spill0     [esp2]    <- esp2: (((esp1-gprsize) & ~15) - 64)
    lea  r4, [3*r1]
    lea  r5, [3*r3]
    call pixel_sa8d_8x8_internal
%if mmsize == 8
    lea  r0, [r0+4*r1]
    lea  r2, [r2+4*r3]
%endif
%if HIGH_BIT_DEPTH
    HADDUW m0, m1
%endif
    mova [esp+48], m0 ; tmp3/rh
    call pixel_sa8d_8x8_internal
    mov  r0, [r6+20] ; arg1
    mov  r2, [r6+28] ; arg3
    add  r0, 8*SIZEOF_PIXEL
    add  r2, 8*SIZEOF_PIXEL
    SA8D_INTER
    mova [esp+48], m0 ; tmp3/rh
    call pixel_sa8d_8x8_internal
%if mmsize == 8
    lea  r0, [r0+4*r1]
    lea  r2, [r2+4*r3]
%else
    SA8D_INTER
%endif
    mova [esp+64-mmsize], m0 ; tmp3h/tmp3/rh
    call pixel_sa8d_8x8_internal
%if HIGH_BIT_DEPTH
    SA8D_INTER
%else ; !HIGH_BIT_DEPTH
    paddusw m0, [esp+64-mmsize] ; tmp3h/tmp3/rh
%if mmsize == 16
    HADDUW m0, m1
%else
    mova m2, [esp+48] ; tmp3/rh
    pxor m7, m7
    mova m1, m0
    mova m3, m2
    punpcklwd m0, m7
    punpckhwd m1, m7
    punpcklwd m2, m7
    punpckhwd m3, m7
    paddd m0, m1
    paddd m2, m3
    paddd m0, m2
    HADDD m0, m1
%endif
%endif ; HIGH_BIT_DEPTH
    movd eax, m0
    add  eax, 1
    shr  eax, 1
    mov  esp, r6
    RET
%endif ; ARCH
%endmacro ; SA8D

;=============================================================================
; SA8D_SATD
;=============================================================================

; %1: vertical/horizontal mode
; %2-%5: sa8d output regs (m0,m1,m2,m3,m4,m5,m8,m9)
; m10: satd result
; m6, m11-15: tmp regs
%macro SA8D_SATD_8x4 5 ; r0..r5, PIC*[0]
%if %1
    LOAD_DIFF_8x4P %2, %3, %4, %5, 6, 11, 7, r0, r2, 1 ; r0..r5
    HADAMARD   0, sumsub, %2, %3, 6
    HADAMARD   0, sumsub, %4, %5, 6
    SBUTTERFLY        wd, %2, %3, 6
    SBUTTERFLY        wd, %4, %5, 6
    HADAMARD2_2D  %2, %4, %3, %5, 6, dq

    mova   m12, m%2
    mova   m13, m%3
    mova   m14, m%4
    mova   m15, m%5
    HADAMARD 0, sumsub, %2, %3, 6
    HADAMARD 0, sumsub, %4, %5, 6
    SBUTTERFLY     qdq, 12, 13, 6
    HADAMARD   0, amax, 12, 13, 6
    SBUTTERFLY     qdq, 14, 15, 6
    paddw m10, m12
    HADAMARD   0, amax, 14, 15, 6
    paddw m10, m14
%else
    LOAD_SUMSUB_8x4P %2, %3, %4, %5, 6, 11, 7, r0, r2, 1 ; r0..r5
    HADAMARD4_V %2, %3, %4, %5, 6

    pabsw    m12, m%2 ; doing the abs first is a slight advantage
    pabsw    m14, m%4
    pabsw    m13, m%3
    pabsw    m15, m%5
    HADAMARD 1, max, 12, 14, 6, 11 ; PIC*
    paddw    m10, m12
    HADAMARD 1, max, 13, 15, 6, 11 ; PIC*
    paddw    m10, m13
%endif
%endmacro ; SA8D_SATD_8x4

; %1: add spilled regs?
; %2: spill regs?
%macro SA8D_SATD_ACCUM 2 ; x64
    ASSERT !i386pic ; assert that this macro is only instantiated when i386 PIC
                    ; is _not_ active (e.g. ARCH_X86_64 excludes PIC mode 2).
%if HIGH_BIT_DEPTH
    pmaddwd m10, [pw_1]
    HADDUWD  m0, m1
%if %1
    paddd   m10, temp1
    paddd    m0, temp0
%endif
%if %2
    mova  temp1, m10
    pxor    m10, m10
%endif
%elif %1
    paddw    m0, temp0
%endif
%if %2
    mova  temp0, m0
%endif
%endmacro

%macro SA8D_SATD 0 ; x64
%define vertical ((notcpuflag(ssse3) || cpuflag(atom)) || HIGH_BIT_DEPTH)
cglobal pixel_sa8d_satd_8x8_internal
    ASSERT !i386pic ; assert that this function is compiled only when i386 PIC
                    ; is _not_ active (e.g. x86_64 targets exclude PIC mode 2).
    SA8D_SATD_8x4 vertical, 0, 1, 2, 3
    SA8D_SATD_8x4 vertical, 4, 5, 8, 9

%if vertical ; sse2-style
    HADAMARD2_2D 0, 4, 2, 8, 6, qdq, amax
    HADAMARD2_2D 1, 5, 3, 9, 6, qdq, amax
%else        ; complete sa8d
    SUMSUB_BADC w, 0, 4, 1, 5, 12
    HADAMARD 2, sumsub, 0, 4, 12, 11 ; PIC*
    HADAMARD 2, sumsub, 1, 5, 12, 11 ; PIC*
    SUMSUB_BADC w, 2, 8, 3, 9, 12
    HADAMARD 2, sumsub, 2, 8, 12, 11 ; PIC*
    HADAMARD 2, sumsub, 3, 9, 12, 11 ; PIC*
    HADAMARD 1, amax, 0, 4, 12, 11 ; PIC*
    HADAMARD 1, amax, 1, 5, 12, 4 ; PIC*
    HADAMARD 1, amax, 2, 8, 12, 4 ; PIC*
    HADAMARD 1, amax, 3, 9, 12, 4 ; PIC*
%endif

    ; create sa8d sub results
    paddw    m1, m2
    paddw    m0, m3
    paddw    m0, m1

    SAVE_MM_PERMUTATION
    ret

;-------------------------------------------------------------------------------
; uint64_t pixel_sa8d_satd_16x16( pixel *, intptr_t, pixel *, intptr_t )
;-------------------------------------------------------------------------------
cglobal pixel_sa8d_satd_16x16, 4,8-(mmsize/32),16,SIZEOF_PIXEL*mmsize ; x64
    ASSERT !i386pic ; assert that this function is compiled only when i386 PIC
                    ; is _not_ active (e.g. x86_64 targets exclude PIC mode 2).
    %define temp0 [rsp+0*mmsize]
    %define temp1 [rsp+1*mmsize]
    FIX_STRIDES r1, r3
%if vertical==0
    mova     m7, [hmul_8p]
%endif
    lea      r4, [3*r1]
    lea      r5, [3*r3]
    pxor    m10, m10

%if mmsize==32
    call pixel_sa8d_satd_8x8_internal
    SA8D_SATD_ACCUM 0, 1
    call pixel_sa8d_satd_8x8_internal
    SA8D_SATD_ACCUM 1, 0
    vextracti128 xm1, m0, 1
    vextracti128 xm2, m10, 1
    paddw   xm0, xm1
    paddw  xm10, xm2
%else
    lea      r6, [r2+8*SIZEOF_PIXEL]
    lea      r7, [r0+8*SIZEOF_PIXEL]

    call pixel_sa8d_satd_8x8_internal
    SA8D_SATD_ACCUM 0, 1
    call pixel_sa8d_satd_8x8_internal
    SA8D_SATD_ACCUM 1, 1

    mov      r0, r7
    mov      r2, r6

    call pixel_sa8d_satd_8x8_internal
    SA8D_SATD_ACCUM 1, 1
    call pixel_sa8d_satd_8x8_internal
    SA8D_SATD_ACCUM 1, 0
%endif

; xop already has fast horizontal sums
%if cpuflag(sse4) && notcpuflag(xop) && HIGH_BIT_DEPTH==0
    pmaddwd xm10, [pw_1]
    HADDUWD xm0, xm1
    phaddd  xm0, xm10       ;  sa8d1  sa8d2  satd1  satd2
    pshufd  xm1, xm0, q2301 ;  sa8d2  sa8d1  satd2  satd1
    paddd   xm0, xm1        ;   sa8d   sa8d   satd   satd
    movd    r0d, xm0
    pextrd  eax, xm0, 2
%else
%if HIGH_BIT_DEPTH
    HADDD   xm0, xm1
    HADDD  xm10, xm2
%else
    HADDUW  xm0, xm1
    HADDW  xm10, xm2
%endif
    movd    r0d, xm0
    movd    eax, xm10
%endif
    add     r0d, 1
    shl     rax, 32
    shr     r0d, 1
    or      rax, r0
    RET
%endmacro ; SA8D_SATD

;=============================================================================
; INTRA SATD
;=============================================================================

%macro HSUMSUB2 8
    pshufd %4, %2, %7
    pshufd %5, %3, %7
    %1     %2, %8
    %1     %6, %8
    paddw  %2, %4
    paddw  %3, %5
%endmacro

; intra_sa8d_x3_8x8 and intra_satd_x3_4x4 are obsoleted by x9 on ssse3+,
; and are only retained for old cpus.
%macro INTRA_SA8D_SSE2 0
%if ARCH_X86_64
;-----------------------------------------------------------------------------
; void intra_sa8d_x3_8x8( uint8_t *fenc, uint8_t edge[36], int *res )
;-----------------------------------------------------------------------------
cglobal intra_sa8d_x3_8x8, 3,3,13
    ; 8x8 hadamard
    pxor        m8, m8
    movq        m0, [r0+0*FENC_STRIDE]
    movq        m1, [r0+1*FENC_STRIDE]
    movq        m2, [r0+2*FENC_STRIDE]
    movq        m3, [r0+3*FENC_STRIDE]
    movq        m4, [r0+4*FENC_STRIDE]
    movq        m5, [r0+5*FENC_STRIDE]
    movq        m6, [r0+6*FENC_STRIDE]
    movq        m7, [r0+7*FENC_STRIDE]
    punpcklbw   m0, m8
    punpcklbw   m1, m8
    punpcklbw   m2, m8
    punpcklbw   m3, m8
    punpcklbw   m4, m8
    punpcklbw   m5, m8
    punpcklbw   m6, m8
    punpcklbw   m7, m8

    HADAMARD8_2D 0, 1, 2, 3, 4, 5, 6, 7, 8

    ABSW2       m8, m9, m2, m3, m2, m3
    ABSW2      m10, m11, m4, m5, m4, m5
    paddw       m8, m10
    paddw       m9, m11
    ABSW2      m10, m11, m6, m7, m6, m7
    ABSW       m12, m1, m1
    paddw      m10, m11
    paddw       m8, m9
    paddw      m12, m10
    paddw      m12, m8

    ; 1D hadamard of edges
    movq        m8, [r1+7]
    movq        m9, [r1+16]
    pxor       m10, m10
    punpcklbw   m8, m10
    punpcklbw   m9, m10
    HSUMSUB2 pmullw, m8, m9, m10, m11, m11, q1032, [pw_ppppmmmm]
    HSUMSUB2 pmullw, m8, m9, m10, m11, m11, q2301, [pw_ppmmppmm]
    pshuflw    m10, m8, q2301
    pshuflw    m11, m9, q2301
    pshufhw    m10, m10, q2301
    pshufhw    m11, m11, q2301
    pmullw      m8, [pw_pmpmpmpm]
    pmullw     m11, [pw_pmpmpmpm]
    paddw       m8, m10
    paddw       m9, m11

    ; differences
    paddw      m10, m8, m9
    paddw      m10, [pw_8]
    pand       m10, [sw_f0]
    psllw       m8, 3 ; left edge
    psllw      m10, 2 ; dc
    psubw       m8, m0
    psubw      m10, m0
    punpcklwd   m0, m1
    punpcklwd   m2, m3
    punpcklwd   m4, m5
    punpcklwd   m6, m7
    ABSW       m10, m10, m1
    paddw      m10, m12
    punpckldq   m0, m2
    punpckldq   m4, m6
    punpcklqdq  m0, m4 ; transpose
    psllw       m9, 3 ; top edge
    psrldq      m2, m10, 2 ; 8x7 sum
    psubw       m0, m9  ; 8x1 sum
    ABSW2       m8, m0, m8, m0, m1, m3 ; 1x8 sum
    paddw       m8, m12
    paddusw     m2, m0

    ; 3x HADDW
    mova        m7, [pd_f0]
    pandn       m0, m7, m10
    psrld      m10, 16
    pandn       m1, m7, m8
    psrld       m8, 16
    pandn       m7, m2
    psrld       m2, 16
    paddd       m0, m10
    paddd       m1, m8
    paddd       m2, m7
    pshufd      m3, m0, q2301
    punpckhdq   m4, m2, m1
    punpckldq   m2, m1
    paddd       m3, m0
    paddd       m2, m4
    punpckhqdq  m0, m2, m3
    punpcklqdq  m2, m3
    paddd       m0, [pd_2]
    paddd       m0, m2
    psrld       m0, 2
    mova      [r2], m0
    RET
%endif ; ARCH_X86_64
%endmacro ; INTRA_SA8D_SSE2

; in: r0 = fenc
; clobber: m4,7*
; out: m0..m3 = hadamard coefs
INIT_MMX
cglobal hadamard_load ; r0, m0..4,7*
; not really a global, but otherwise cycles get attributed to the wrong function in profiling
%if HIGH_BIT_DEPTH
    mova        m0, [r0+0*FENC_STRIDEB]
    mova        m1, [r0+1*FENC_STRIDEB]
    mova        m2, [r0+2*FENC_STRIDEB]
    mova        m3, [r0+3*FENC_STRIDEB]
%else
    pxor        m7, m7
    movd        m0, [r0+0*FENC_STRIDE]
    movd        m1, [r0+1*FENC_STRIDE]
    movd        m2, [r0+2*FENC_STRIDE]
    movd        m3, [r0+3*FENC_STRIDE]
    punpcklbw   m0, m7
    punpcklbw   m1, m7
    punpcklbw   m2, m7
    punpcklbw   m3, m7
%endif
    HADAMARD4_2D 0, 1, 2, 3, 4 ; m0..4
    SAVE_MM_PERMUTATION
    ret

%macro SCALAR_HADAMARD 4-5 ; direction, offset, 3x tmp ; r1, stack, PIC
%ifidn %1, top
%if HIGH_BIT_DEPTH
    mova        %3, [r1+%2*SIZEOF_PIXEL-FDEC_STRIDEB]
%else
    movd        %3, [r1+%2*SIZEOF_PIXEL-FDEC_STRIDEB]
    pxor        %5, %5
    punpcklbw   %3, %5
%endif
%else ; left
%ifnidn %2, 0
    shl         %2d, 5 ; log(FDEC_STRIDEB)
%endif
    movd        %3, [r1+%2*SIZEOF_PIXEL-4+1*FDEC_STRIDEB]
    pinsrw      %3, [r1+%2*SIZEOF_PIXEL-2+0*FDEC_STRIDEB], 0
    pinsrw      %3, [r1+%2*SIZEOF_PIXEL-2+2*FDEC_STRIDEB], 2
    pinsrw      %3, [r1+%2*SIZEOF_PIXEL-2+3*FDEC_STRIDEB], 3
%if HIGH_BIT_DEPTH == 0
    psrlw       %3, 8
%endif
%ifnidn %2, 0
    shr         %2d, 5
%endif
%endif ; direction
%if cpuflag(ssse3)
    %define %%sign psignw
%else
    %define %%sign pmullw
%endif
    pshufw      %4, %3, q1032
    PIC_BEGIN r4 ; %3 & %4 are *mm (dest in paddw/pshufw is *mm reg)
    CHECK_REG_COLLISION "rpic",,,%3,%4
    %%sign      %4, [pic(pw_ppmmppmm)]
    paddw       %3, %4
    pshufw      %4, %3, q2301
    %%sign      %4, [pic(pw_pmpmpmpm)]
    PIC_END
    paddw       %3, %4
    psllw       %3, 2
    mova        [%1_1d+2*%2], %3 ; stack (e.g. top_1d==rsp+8)
%endmacro

%macro SUM_MM_X3 8 ; 3x sum, 4x tmp, op
    pxor        %7, %7
    pshufw      %4, %1, q1032
    pshufw      %5, %2, q1032
    pshufw      %6, %3, q1032
    paddw       %1, %4
    paddw       %2, %5
    paddw       %3, %6
    punpcklwd   %1, %7
    punpcklwd   %2, %7
    punpcklwd   %3, %7
    pshufw      %4, %1, q1032
    pshufw      %5, %2, q1032
    pshufw      %6, %3, q1032
    %8          %1, %4
    %8          %2, %5
    %8          %3, %6
%endmacro

; in: m1..m3
; out: m7
; clobber: m4..m6
%macro SUM3x4 0
    ABSW2       m4, m5, m1, m2, m1, m2
    ABSW        m7, m3, m3
    paddw       m4, m5
    paddw       m7, m4
%endmacro

; in: m0..m3 (4x4)
; out: m0 v, m4 h, m5 dc
; clobber: m1..m3
%macro SUM4x3 3 ; dc, left, top
    movq        m4, %2
%ifnum sizeof%1
    movq        m5, %1
%else
    movd        m5, %1
%endif
    psubw       m4, m0
    psubw       m5, m0
    punpcklwd   m0, m1
    punpcklwd   m2, m3
    punpckldq   m0, m2 ; transpose
    psubw       m0, %3
    ABSW2       m4, m5, m4, m5, m2, m3 ; 1x4 sum
    ABSW        m0, m0, m1 ; 4x1 sum
%endmacro

%macro INTRA_X3_MMX 0
;-----------------------------------------------------------------------------
; void intra_satd_x3_4x4( uint8_t *fenc, uint8_t *fdec, int *res )
;-----------------------------------------------------------------------------
cglobal intra_satd_x3_4x4, 3,3
    %assign %%pad 16 + (15 & -(gprsize+stack_offset+16))
    SUB         rsp, %%pad
%define top_1d  rsp+8  ; size 8
%define left_1d rsp    ; size 8

    call hadamard_load ; r0, m0..4,7*
    PIC_BEGIN r0, 0 ; r0 is not used anymore, don't save
    CHECK_REG_COLLISION "rpic","r1","left_1d","top_1d"
    SCALAR_HADAMARD left, 0, m4, m5     ; r1, stack, PIC
    SCALAR_HADAMARD top,  0, m6, m5, m7 ; r1, stack, PIC
    paddw       m6, m4
    pavgw       m6, [pic(pw_16)]
    pand        m6, [pic(sw_f0)] ; dc
    PIC_END

    SUM3x4
    SUM4x3      m6, [left_1d], [top_1d]
    paddw       m4, m7
    paddw       m5, m7
    movq        m1, m5
    psrlq       m1, 16 ; 4x3 sum
    paddw       m0, m1

    SUM_MM_X3   m0, m4, m5, m1, m2, m3, m6, pavgw
    movd    [r2+0], m0 ; i4x4_v satd
    movd    [r2+4], m4 ; i4x4_h satd
    movd    [r2+8], m5 ; i4x4_dc satd
    ADD         rsp, %%pad
    %undef    %%pad
    RET

;-----------------------------------------------------------------------------
; void intra_satd_x3_16x16( uint8_t *fenc, uint8_t *fdec, int *res )
;-----------------------------------------------------------------------------
cglobal intra_satd_x3_16x16, 0,5
    %assign %%pad  120 + (15 & -(gprsize+stack_offset+120))
    ; not really needed on x86_64, just shuts up valgrind about storing data below the stack across a function call
    SUB         rsp, %%pad
%define sums    rsp+64 ; size 56
%define top_1d  rsp+32 ; size 32
%define left_1d rsp    ; size 32
    movifnidn   r1, r1mp

    pxor        m7, m7
    mova [sums+ 0], m7
    mova [sums+ 8], m7
    mova [sums+16], m7
%if HIGH_BIT_DEPTH
    mova [sums+24], m7
    mova [sums+32], m7
    mova [sums+40], m7
    mova [sums+48], m7
%endif

    ; 1D hadamards
    mov        r3d, 12
    PIC_BEGIN r0, 0 ; r0 not used/loaded from r0mp yet
    CHECK_REG_COLLISION "rpic","r1","r3d","left_1d","top_1d"
    movd        m6, [pic(pw_32)]
.loop_edge:
    SCALAR_HADAMARD left, r3, m0, m1     ; r1, r3d, stack, PIC
    SCALAR_HADAMARD top,  r3, m1, m2, m3 ; r1, r3d, stack, PIC
    pavgw       m0, m1
    paddw       m6, m0
    sub        r3d, 4
    jge .loop_edge
    psrlw       m6, 2
    pand        m6, [pic(sw_f0)] ; dc
    PIC_END

    ; 2D hadamards
    movifnidn   r0, r0mp ; r0 loaded from r0mp here
    mov         r3, -4
.loop_y:
    mov         r4, -4
.loop_x:
    call hadamard_load ; r0, m0..4,7*

    SUM3x4
    SUM4x3 m6, [left_1d+8*(r3+4)], [top_1d+8*(r4+4)]
    pavgw       m4, m7
    pavgw       m5, m7
    paddw       m0, [sums+ 0] ; i16x16_v satd
    paddw       m4, [sums+ 8] ; i16x16_h satd
    paddw       m5, [sums+16] ; i16x16_dc satd
    mova [sums+ 0], m0
    mova [sums+ 8], m4
    mova [sums+16], m5

    add         r0, 4*SIZEOF_PIXEL
    inc         r4
    jl  .loop_x
%if HIGH_BIT_DEPTH
    psrld       m7, m4, 16
    pslld       m4, 16
    psrld       m4, 16
    paddd       m4, m7
    psrld       m7, m0, 16
    pslld       m0, 16
    psrld       m0, 16
    paddd       m0, m7
    paddd       m4, [sums+32]
    paddd       m0, [sums+24]
    mova [sums+32], m4
    mova [sums+24], m0
    pxor        m7, m7
    punpckhwd   m3, m5, m7
    punpcklwd   m5, m7
    paddd       m3, [sums+48]
    paddd       m5, [sums+40]
    mova [sums+48], m3
    mova [sums+40], m5
    mova [sums+ 0], m7
    mova [sums+ 8], m7
    mova [sums+16], m7
%endif
    add         r0, 4*FENC_STRIDEB-16*SIZEOF_PIXEL
    inc         r3
    jl  .loop_y

; horizontal sum
    movifnidn   r2, r2mp
%if HIGH_BIT_DEPTH
    mova        m1, m5
    paddd       m5, m3
    HADDD       m5, m7 ; DC satd
    HADDD       m4, m7 ; H satd
    HADDD       m0, m7 ; the part of V satd that doesn't overlap with DC
    psrld       m0, 1
    psrlq       m1, 32 ; DC[1]
    paddd       m0, m3 ; DC[2]
    psrlq       m3, 32 ; DC[3]
    paddd       m0, m1
    paddd       m0, m3
%else
    mova        m7, m5
    SUM_MM_X3   m0, m4, m5, m3, m1, m2, m6, paddd
    psrld       m0, 1
    pslld       m7, 16
    psrld       m7, 16
    paddd       m0, m5
    psubd       m0, m7
%endif
    movd    [r2+8], m5 ; i16x16_dc satd
    movd    [r2+4], m4 ; i16x16_h satd
    movd    [r2+0], m0 ; i16x16_v satd
    ADD        rsp, %%pad ; free sums/top_1d/left_1d area
    %undef   %%pad
    RET

%if ARCH_X86_64
    %define  t0 r6
%else
    %define  t0 r2
%endif

;-----------------------------------------------------------------------------
; void intra_satd_x3_8x8c( uint8_t *fenc, uint8_t *fdec, int *res )
;-----------------------------------------------------------------------------
cglobal intra_satd_x3_8x8c, 0,6
    ; not really needed on x86_64, just shuts up valgrind about storing data below the stack across a function call
    %assign %%pad0 72
%if HIGH_BIT_DEPTH && (!cpuflag(xop) || mmsize != 16)
    %assign %%pad0 %%pad0+2*(gprsize)
    %define lpiccache [rsp+72+gprsize] ; size gprsize
    %define rpicsave   [rsp+72]         ; size gprsize
%endif
    %assign %%pad %%pad0 + (15 & -(gprsize+stack_offset+%%pad0))
    SUB          rsp, %%pad
%define  sums    rsp+48 ; size 24
%define  dc_1d   rsp+32 ; size 16
%define  top_1d  rsp+16 ; size 16
%define  left_1d rsp    ; size 16
    movifnidn   r1, r1mp
    pxor        m7, m7
    mova [sums+ 0], m7
    mova [sums+ 8], m7
    mova [sums+16], m7

    ; 1D hadamards
    mov         r3d, 4
    PIC_BEGIN r0, 0 ; r0 not used/loaded from r0mp yet
    CHECK_REG_COLLISION "rpic","r1","r3d","left_1d","top_1d"
.loop_edge:
    SCALAR_HADAMARD left, r3, m0, m1     ; r1, r3d, stack, PIC
    SCALAR_HADAMARD top,  r3, m0, m1, m2 ; r1, r3d, stack, PIC
    sub         r3d, 4
    jge .loop_edge
    PIC_END

    ; dc
    movzx       t0d, word [left_1d+0]
    movzx       r3d, word [top_1d+0]
    movzx       r4d, word [left_1d+8]
    movzx       r5d, word [top_1d+8]
    lea         t0d, [t0 + r3 + 16]
    lea         r3d, [r4 + r5 + 16]
    shr         t0d, 1
    shr         r3d, 1
    add         r4d, 8
    add         r5d, 8
    and         t0d, -16 ; tl
    and         r3d, -16 ; br
    and         r4d, -16 ; bl
    and         r5d, -16 ; tr
    mov         [dc_1d+ 0], t0d ; tl
    mov         [dc_1d+ 4], r5d ; tr
    mov         [dc_1d+ 8], r4d ; bl
    mov         [dc_1d+12], r3d ; br
    lea         r5, [dc_1d]

    ; 2D hadamards
    movifnidn   r0,  r0mp ; r0 loaded from r0mp here
    movifnidn   r2,  r2mp
    mov         r3,  -2
.loop_y:
    mov         r4,  -2
.loop_x:
    call hadamard_load ; r0, m0..4,7*

    SUM3x4
    SUM4x3 [r5+4*(r4+2)], [left_1d+8*(r3+2)], [top_1d+8*(r4+2)]
    pavgw       m4, m7
    pavgw       m5, m7
    paddw       m0, [sums+16] ; i4x4_v satd
    paddw       m4, [sums+8]  ; i4x4_h satd
    paddw       m5, [sums+0]  ; i4x4_dc satd
    movq        [sums+16], m0
    movq        [sums+8], m4
    movq        [sums+0], m5

    add         r0, 4*SIZEOF_PIXEL
    inc         r4
    jl  .loop_x
    add         r0, 4*FENC_STRIDEB-8*SIZEOF_PIXEL
    add         r5, 8
    inc         r3
    jl  .loop_y

; horizontal sum
    movq        m0, [sums+0]
    movq        m1, [sums+8]
    movq        m2, [sums+16]
    movq        m7, m0
%if HIGH_BIT_DEPTH
    psrlq       m7, 16
    ; Designate r0 (which is not used anymore) for no-save PIC, in case HADDW
    ; macro below triggers PIC memory access:
    DESIGNATE_RPIC r0
    HADDW       m7, m3 ; PIC*
    SUM_MM_X3   m0, m1, m2, m3, m4, m5, m6, paddd
    psrld       m2, 1
    paddd       m2, m7
%else
    psrlq       m7, 15
    paddw       m2, m7
    SUM_MM_X3   m0, m1, m2, m3, m4, m5, m6, paddd
    psrld       m2, 1
%endif
    movd    [r2+0], m0 ; i8x8c_dc satd
    movd    [r2+4], m1 ; i8x8c_h satd
    movd    [r2+8], m2 ; i8x8c_v satd
    ADD        rsp, %%pad ; free rpicsave/sums/dc_1d/top_1d/left_1d area
    %undef   %%pad
    RET
%endmacro ; INTRA_X3_MMX



%macro PRED4x4_LOWPASS 5 ; PIC
%ifnum sizeof%5
    pavgb       %5, %2, %3
    pxor        %3, %2
    PIC_BEGIN r4
    CHECK_REG_COLLISION "rpic",%{1:-1}
    pand        %3, [pic(pb_1)]
    PIC_END
    psubusb     %5, %3
    pavgb       %1, %4, %5
%else
    mova        %5, %2
    pavgb       %2, %3
    pxor        %3, %5
    PIC_BEGIN r4
    CHECK_REG_COLLISION "rpic",%{1:-1}
    pand        %3, [pic(pb_1)]
    PIC_END
    psubusb     %2, %3
    pavgb       %1, %4, %2
%endif
%endmacro

%macro INTRA_X9_PRED 2 ; r1, PIC
%if cpuflag(sse4)
    movu       m1, [r1-1*FDEC_STRIDE-8]
    pinsrb     m1, [r1+3*FDEC_STRIDE-1], 0
    pinsrb     m1, [r1+2*FDEC_STRIDE-1], 1
    pinsrb     m1, [r1+1*FDEC_STRIDE-1], 2
    pinsrb     m1, [r1+0*FDEC_STRIDE-1], 3
%else
    movd      mm0, [r1+3*FDEC_STRIDE-4]
    punpcklbw mm0, [r1+2*FDEC_STRIDE-4]
    movd      mm1, [r1+1*FDEC_STRIDE-4]
    punpcklbw mm1, [r1+0*FDEC_STRIDE-4]
    punpckhwd mm0, mm1
    psrlq     mm0, 32
    movq2dq    m0, mm0
    movu       m1, [r1-1*FDEC_STRIDE-8]
    movss      m1, m0                  ; l3 l2 l1 l0 __ __ __ lt t0 t1 t2 t3 t4 t5 t6 t7
%endif ; cpuflag
    PIC_BEGIN r4
    CHECK_REG_COLLISION "rpic",,%2
    pshufb     m1, [pic(intrax9_edge)] ; l3 l3 l2 l1 l0 lt t0 t1 t2 t3 t4 t5 t6 t7 t7 __
    psrldq     m0, m1, 1               ; l3 l2 l1 l0 lt t0 t1 t2 t3 t4 t5 t6 t7 t7 __ __
    psrldq     m2, m1, 2               ; l2 l1 l0 lt t0 t1 t2 t3 t4 t5 t6 t7 t7 __ __ __
    pavgb      m5, m0, m1              ; Gl3 Gl2 Gl1 Gl0 Glt Gt0 Gt1 Gt2 Gt3 Gt4 Gt5  __  __ __ __ __
    mova       %2, m1
    PRED4x4_LOWPASS m0, m1, m2, m0, m4 ; Fl3 Fl2 Fl1 Fl0 Flt Ft0 Ft1 Ft2 Ft3 Ft4 Ft5 Ft6 Ft7 __ __ __ ; PIC
    ; ddl               ddr
    ; Ft1 Ft2 Ft3 Ft4   Flt Ft0 Ft1 Ft2
    ; Ft2 Ft3 Ft4 Ft5   Fl0 Flt Ft0 Ft1
    ; Ft3 Ft4 Ft5 Ft6   Fl1 Fl0 Flt Ft0
    ; Ft4 Ft5 Ft6 Ft7   Fl2 Fl1 Fl0 Flt
    pshufb     m2, m0, [pic(%1_ddlr1)] ; a: ddl row0, ddl row1, ddr row0, ddr row1 / b: ddl row0, ddr row0, ddl row1, ddr row1
    pshufb     m3, m0, [pic(%1_ddlr2)] ; rows 2,3
    ; hd                hu
    ; Glt Flt Ft0 Ft1   Gl0 Fl1 Gl1 Fl2
    ; Gl0 Fl0 Glt Flt   Gl1 Fl2 Gl2 Fl3
    ; Gl1 Fl1 Gl0 Fl0   Gl2 Fl3 Gl3 Gl3
    ; Gl2 Fl2 Gl1 Fl1   Gl3 Gl3 Gl3 Gl3
    pslldq     m0, 5                   ; ___ ___ ___ ___ ___ Fl3 Fl2 Fl1 Fl0 Flt Ft0 Ft1 Ft2 Ft3 Ft4 Ft5
    palignr    m7, m5, m0, 5           ; Fl3 Fl2 Fl1 Fl0 Flt Ft0 Ft1 Ft2 Ft3 Ft4 Ft5 Gl3 Gl2 Gl1 Gl0 Glt
    pshufb     m6, m7, [pic(%1_hdu1)]
    pshufb     m7, m7, [pic(%1_hdu2)]
    ; vr                vl
    ; Gt0 Gt1 Gt2 Gt3   Gt1 Gt2 Gt3 Gt4
    ; Flt Ft0 Ft1 Ft2   Ft1 Ft2 Ft3 Ft4
    ; Fl0 Gt0 Gt1 Gt2   Gt2 Gt3 Gt4 Gt5
    ; Fl1 Flt Ft0 Ft1   Ft2 Ft3 Ft4 Ft5
    psrldq     m5, 5                   ; Gt0 Gt1 Gt2 Gt3 Gt4 Gt5 ...
    palignr    m5, m0, 6               ; ___ Fl1 Fl0 Flt Ft0 Ft1 Ft2 Ft3 Ft4 Ft5 Gt0 Gt1 Gt2 Gt3 Gt4 Gt5
    pshufb     m4, m5, [pic(%1_vrl1)]
    pshufb     m5, m5, [pic(%1_vrl2)]
    PIC_END
%endmacro ; INTRA_X9_PRED

%macro INTRA_X9_VHDC 5 ; edge, fenc01, fenc23, tmp, tmp ; r3, stack, PIC
    PIC_BEGIN r4
    pshufb     m2, m%1, [pic(intrax9b_vh1)]
    pshufb     m3, m%1, [pic(intrax9b_vh2)]
    PIC_END
    mova      [pred_buf+0x60], m2
    mova      [pred_buf+0x70], m3
    PIC_BEGIN r4
    pshufb    m%1, [pic(intrax9b_edge2)] ; t0 t1 t2 t3 t0 t1 t2 t3 l0 l1 l2 l3 l0 l1 l2 l3
    pmaddubsw m%1, [pic(hmul_4p)]
    pshufhw    m0, m%1, q2301
    pshuflw    m0, m0,  q2301
    psignw    m%1, [pic(pw_pmpmpmpm)]
    paddw      m0, m%1
    psllw      m0, 2 ; hadamard(top), hadamard(left)
    MOVHL      m3, m0
    pshufb     m1, m0, [pic(intrax9b_v1)]
    pshufb     m2, m0, [pic(intrax9b_v2)]
    paddw      m0, m3
    psignw     m3, [pic(pw_pmmpzzzz)] ; FIXME could this be eliminated?
    pavgw      m0, [pic(pw_16)]
    pand       m0, [pic(sw_f0)] ; dc
    PIC_END
    ; This (as well as one of the steps in intra_satd_x9_4x4.satd_8x4) could be
    ; changed from a wd transpose to a qdq, with appropriate rearrangement of inputs.
    ; Which would be faster on conroe, but slower on penryn and sandybridge, and too invasive to ifdef.
    HADAMARD 0, sumsub, %2, %3, %4, %5 ;
    HADAMARD 1, sumsub, %2, %3, %4, %5 ; PIC*
    movd      r3d, m0
    shr       r3d, 4
    imul      r3d, 0x01010101
    mov       [pred_buf+0x80], r3d
    mov       [pred_buf+0x88], r3d
    mov       [pred_buf+0x90], r3d
    mov       [pred_buf+0x98], r3d
    psubw      m3, m%2
    psubw      m0, m%2
    psubw      m1, m%2
    psubw      m2, m%3
    pabsw     m%3, m%3
    pabsw      m3, m3
    pabsw      m0, m0
    pabsw      m1, m1
    pabsw      m2, m2
    pavgw      m3, m%3
    pavgw      m0, m%3
    pavgw      m1, m2
%if cpuflag(sse4)
    phaddw     m3, m0
%else
    SBUTTERFLY qdq, 3, 0, 2
    paddw      m3, m0
%endif
    MOVHL      m2, m1
    paddw      m1, m2
%if cpuflag(xop)
    vphaddwq   m3, m3
    vphaddwq   m1, m1
    packssdw   m1, m3
%else
    phaddw     m1, m3
    PIC_BEGIN r4
    pmaddwd    m1, [pic(pw_1)] ; v, _, h, dc
    PIC_END
%endif
%endmacro ; INTRA_X9_VHDC

%macro INTRA_X9_END 2 ; eax, r1..3, stack/pred_buf, PIC
%if cpuflag(sse4)
    phminposuw m0, m0 ; h,dc,ddl,ddr,vr,hd,vl,hu
    movd      eax, m0
    add       eax, 1<<16
    cmp        ax, r3w
    cmovge    eax, r3d
%else
%if %1
    ; 4x4 sad is up to 12 bits; +bitcosts -> 13 bits; pack with 3 bit index
    psllw      m0, 3
    PIC_BEGIN rax, 0 ; rax is reset later, don't save
    paddw      m0, [pic(pw_s01234567)] ; h,dc,ddl,ddr,vr,hd,vl,hu
    PIC_END
%else
    ; 4x4 satd is up to 13 bits; +bitcosts and saturate -> 13 bits; pack with 3 bit index
    psllw      m0, 2
    paddusw    m0, m0
    PIC_BEGIN rax, 0 ; rax is reset later, don't save
    paddw      m0, [pic(pw_s01234657)] ; h,dc,ddl,ddr,vr,vl,hd,hu
    PIC_END
%endif
    movhlps    m1, m0
    pminsw     m0, m1
    pshuflw    m1, m0, q0032
    pminsw     m0, m1
    pshuflw    m1, m0, q0001
    pminsw     m0, m1
    movd      eax, m0
    movsx     r2d, ax
    and       eax, 7
    sar       r2d, 3
    shl       eax, 16
    ; 1<<16: increment index to match intra4x4_pred_e. couldn't do this before because it had to fit in 3 bits
    ; 1<<12: undo sign manipulation
    lea       eax, [rax+r2+(1<<16)+(1<<12)]
    cmp        ax, r3w
    cmovge    eax, r3d
%endif ; cpuflag

    ; output the predicted samples
    mov       r3d, eax
    shr       r3d, 16
%if ARCH_X86_64
    lea        r2, [%2_lut]
    movzx     r2d, byte [r2+r3]
%else
    PIC_BEGIN r2, 0 ; r2 is reset inside, don't save/restore
    movzx     r2d, byte [pic(%2_lut)+r3] ; intrax9a_lut etc
    PIC_END
%endif
%if %1 ; sad
    movq      mm0, [pred_buf+r2]
    movq      mm1, [pred_buf+r2+16]
    movd     [r1+0*FDEC_STRIDE], mm0
    movd     [r1+2*FDEC_STRIDE], mm1
    psrlq     mm0, 32
    psrlq     mm1, 32
    movd     [r1+1*FDEC_STRIDE], mm0
    movd     [r1+3*FDEC_STRIDE], mm1
%else ; satd
%assign i 0
%rep 4
    mov       r3d, [pred_buf+r2+8*i]
    mov      [r1+i*FDEC_STRIDE], r3d
%assign i i+1
%endrep
%endif
%endmacro ; INTRA_X9_END

%macro INTRA_X9 0
;-----------------------------------------------------------------------------
; int intra_sad_x9_4x4( uint8_t *fenc, uint8_t *fdec, uint16_t *bitcosts )
;-----------------------------------------------------------------------------
%if notcpuflag(xop)
cglobal intra_sad_x9_4x4, 3,4,9
    ; Add gprsize for rpic and 0xb0 for pred_buf, and align:
    %assign %%pad gprsize+0xb0 + (15 & -(gprsize+stack_offset+gprsize+0xb0))
    SUB       rsp, %%pad ; alloc rpicsave/pred_buf area
    %define rpicsave  [rsp+0xb0] ; gprsize
    %define pred_buf2 rsp+0xa0   ; size 16
    %define pred_buf  rsp        ; size 160 (0xa0)
    PIC_BEGIN
    CHECK_REG_COLLISION "rpic","pred_buf","pred_buf2", eax;retval
%if ARCH_X86_64
    INTRA_X9_PRED intrax9a, m8
%else
    INTRA_X9_PRED intrax9a, [pred_buf2] ; r1, stack, PIC
%endif
    mova [rsp+0x00], m2
    mova [rsp+0x10], m3
    mova [rsp+0x20], m4
    mova [rsp+0x30], m5
    mova [rsp+0x40], m6
    mova [rsp+0x50], m7
%if cpuflag(sse4)
    movd       m0, [r0+0*FENC_STRIDE]
    pinsrd     m0, [r0+1*FENC_STRIDE], 1
    movd       m1, [r0+2*FENC_STRIDE]
    pinsrd     m1, [r0+3*FENC_STRIDE], 1
%else
    movd      mm0, [r0+0*FENC_STRIDE]
    punpckldq mm0, [r0+1*FENC_STRIDE]
    movd      mm1, [r0+2*FENC_STRIDE]
    punpckldq mm1, [r0+3*FENC_STRIDE]
    movq2dq    m0, mm0
    movq2dq    m1, mm1
%endif
    punpcklqdq m0, m0
    punpcklqdq m1, m1
    psadbw     m2, m0
    psadbw     m3, m1
    psadbw     m4, m0
    psadbw     m5, m1
    psadbw     m6, m0
    psadbw     m7, m1
    paddd      m2, m3
    paddd      m4, m5
    paddd      m6, m7
%if ARCH_X86_64
    SWAP        7, 8
    pxor       m8, m8
    %define %%zero m8
%else
    mova       m7, [pred_buf2]
    %define %%zero [pic(pb_0)]
%endif
    PIC_BEGIN
    pshufb     m3, m7, [pic(intrax9a_vh1)]
    pshufb     m5, m7, [pic(intrax9a_vh2)]
    pshufb     m7, [pic(intrax9a_dc)]
    psadbw     m7, %%zero
    psrlw      m7, 2
    mova [rsp+0x60], m3
    mova [rsp+0x70], m5
    psadbw     m3, m0
    pavgw      m7, %%zero
    pshufb     m7, %%zero
    PIC_END
    psadbw     m5, m1
    movq [rsp+0x80], m7
    movq [rsp+0x90], m7
    psadbw     m0, m7
    paddd      m3, m5
    psadbw     m1, m7
    paddd      m0, m1
    movzx     r3d, word [r2]
    movd      r0d, m3 ; v
    add       r3d, r0d
    punpckhqdq m3, m0 ; h, dc
    shufps     m3, m2, q2020
    psllq      m6, 32
    por        m4, m6
    movu       m0, [r2+2]
    packssdw   m3, m4
    paddw      m0, m3
    INTRA_X9_END 1, intrax9a ; eax, r1..3, stack/pred_buf, PIC
    PIC_END
    ADD       rsp, %%pad ; free rpicsave/pred_buf area
    %undef  %%pad
    RET
%endif ; cpuflag

%if ARCH_X86_64
;-----------------------------------------------------------------------------
; int intra_satd_x9_4x4( uint8_t *fenc, uint8_t *fdec, uint16_t *bitcosts )
;-----------------------------------------------------------------------------
cglobal intra_satd_x9_4x4, 3,4,16
    %assign pad 0xb0-gprsize-(stack_offset&15)
    %define pred_buf rsp
    sub       rsp, pad
    INTRA_X9_PRED intrax9b, m15
    mova [rsp+0x00], m2
    mova [rsp+0x10], m3
    mova [rsp+0x20], m4
    mova [rsp+0x30], m5
    mova [rsp+0x40], m6
    mova [rsp+0x50], m7
    movd       m8, [r0+0*FENC_STRIDE]
    movd       m9, [r0+1*FENC_STRIDE]
    movd      m10, [r0+2*FENC_STRIDE]
    movd      m11, [r0+3*FENC_STRIDE]
    mova      m12, [hmul_8p]
    pshufd     m8, m8, 0
    pshufd     m9, m9, 0
    pshufd    m10, m10, 0
    pshufd    m11, m11, 0
    pmaddubsw  m8, m12
    pmaddubsw  m9, m12
    pmaddubsw m10, m12
    pmaddubsw m11, m12
    movddup    m0, m2
    pshufd     m1, m2, q3232
    movddup    m2, m3
    punpckhqdq m3, m3
    call .satd_8x4 ; ddr, ddl
    movddup    m2, m5
    pshufd     m3, m5, q3232
    mova       m5, m0
    movddup    m0, m4
    pshufd     m1, m4, q3232
    call .satd_8x4 ; vr, vl
    movddup    m2, m7
    pshufd     m3, m7, q3232
    mova       m4, m0
    movddup    m0, m6
    pshufd     m1, m6, q3232
    call .satd_8x4 ; hd, hu
%if cpuflag(sse4)
    punpckldq  m4, m0
%else
    punpcklqdq m4, m0 ; conroe dislikes punpckldq, and ssse3 INTRA_X9_END can handle arbitrary orders whereas phminposuw can't
%endif
    mova       m1, [pw_ppmmppmm]
    psignw     m8, m1
    psignw    m10, m1
    paddw      m8, m9
    paddw     m10, m11
    INTRA_X9_VHDC 15, 8, 10, 6, 7
    ; find minimum
    movu       m0, [r2+2]
    movd      r3d, m1
    palignr    m5, m1, 8
%if notcpuflag(sse4)
    pshufhw    m0, m0, q3120 ; compensate for different order in unpack
%endif
    packssdw   m5, m4
    paddw      m0, m5
    movzx     r0d, word [r2]
    add       r3d, r0d
    INTRA_X9_END 0, intrax9b
    add       rsp, pad
    RET
RESET_MM_PERMUTATION
ALIGN 16
.satd_8x4:
    pmaddubsw  m0, m12
    pmaddubsw  m1, m12
    pmaddubsw  m2, m12
    pmaddubsw  m3, m12
    psubw      m0, m8
    psubw      m1, m9
    psubw      m2, m10
    psubw      m3, m11
    SATD_8x4_SSE 0, 0, 1, 2, 3, 13, 14, 0, swap
    pmaddwd    m0, [pw_1]
    MOVHL      m1, m0
    paddd    xmm0, m0, m1 ; consistent location of return value. only the avx version of hadamard permutes m0, so 3arg is free
    ret

%else ; !ARCH_X86_64
cglobal intra_satd_x9_4x4, 3,4,8
    ; Add gprsize for rpic and 0x110 for spill/pred_buf/fenc_buf, and align:
    %assign %%pad gprsize+0x110 + (15 & -(gprsize+stack_offset+gprsize+0x110))

    SUB       rsp, %%pad ; alloc rpicsave/spill/pred_buf/fenc_buf area
    %define rpicsave [rsp+0x110] ; gprsize
    %define spill    rsp+0xe0    ; size 48
    %define pred_buf rsp+0x40    ; size 160 (0xa0)
    %define fenc_buf rsp         ; size 64

    PIC_BEGIN r4, 1, $$
    CHECK_REG_COLLISION "rpic","fenc_buf","pred_buf","spill", eax;retval
    INTRA_X9_PRED intrax9b, [spill+0x20] ; r1, stack, PIC
    mova [pred_buf+0x00], m2
    mova [pred_buf+0x10], m3
    mova [pred_buf+0x20], m4
    mova [pred_buf+0x30], m5
    mova [pred_buf+0x40], m6
    mova [pred_buf+0x50], m7
    movd       m4, [r0+0*FENC_STRIDE]
    movd       m5, [r0+1*FENC_STRIDE]
    movd       m6, [r0+2*FENC_STRIDE]
    movd       m0, [r0+3*FENC_STRIDE]
    PIC_BEGIN
    mova       m7, [pic(hmul_8p)]
    PIC_END
    pshufd     m4, m4, 0
    pshufd     m5, m5, 0
    pshufd     m6, m6, 0
    pshufd     m0, m0, 0
    pmaddubsw  m4, m7
    pmaddubsw  m5, m7
    pmaddubsw  m6, m7
    pmaddubsw  m0, m7
    mova [fenc_buf+0x00], m4
    mova [fenc_buf+0x10], m5
    mova [fenc_buf+0x20], m6
    mova [fenc_buf+0x30], m0
    movddup    m0, m2
    pshufd     m1, m2, q3232
    movddup    m2, m3
    punpckhqdq m3, m3
    pmaddubsw  m0, m7
    pmaddubsw  m1, m7
    pmaddubsw  m2, m7
    pmaddubsw  m3, m7
    psubw      m0, m4
    psubw      m1, m5
    psubw      m2, m6
    call .satd_8x4b ; ddr, ddl ; r4=$$
    mova       m3, [pred_buf+0x30]
    mova       m1, [pred_buf+0x20]
    movddup    m2, m3
    punpckhqdq m3, m3
    movq [spill+0x08], m0
    movddup    m0, m1
    punpckhqdq m1, m1
    call .satd_8x4 ; vr, vl ; r4=$$
    mova       m3, [pred_buf+0x50]
    mova       m1, [pred_buf+0x40]
    movddup    m2, m3
    punpckhqdq m3, m3
    movq [spill+0x10], m0
    movddup    m0, m1
    punpckhqdq m1, m1
    call .satd_8x4 ; hd, hu ; r4=$$
    movq [spill+0x18], m0
    mova       m1, [spill+0x20]
    mova       m4, [fenc_buf+0x00]
    mova       m5, [fenc_buf+0x20]
    PIC_BEGIN
    mova       m2, [pic(pw_ppmmppmm)]
    PIC_END
    psignw     m4, m2
    psignw     m5, m2
    paddw      m4, [fenc_buf+0x10]
    paddw      m5, [fenc_buf+0x30]
    INTRA_X9_VHDC 1, 4, 5, 6, 7 ; r3, stack, PIC
    ; find minimum
    movu       m0, [r2+2]
    movd      r3d, m1
    punpckhqdq m1, [spill+0x00]
    packssdw   m1, [spill+0x10]
%if cpuflag(sse4)
    pshufhw    m1, m1, q3120
%else
    pshufhw    m0, m0, q3120
%endif
    paddw      m0, m1
    movzx     r0d, word [r2]
    add       r3d, r0d
    INTRA_X9_END 0, intrax9b ; eax, r1..3, stack/pred_buf, PIC
    PIC_END
    ADD       rsp, %%pad ; free rpicsave/spill/pred_buf/fenc_buf area
    %undef  %%pad
    RET
RESET_MM_PERMUTATION
ALIGN 16
.satd_8x4:       ; expect r4=$$
%if i386pic
    %assign  picb  1
    %xdefine rpic  r4
    %xdefine lpic $$
%endif
    pmaddubsw  m0, m7
    pmaddubsw  m1, m7
    pmaddubsw  m2, m7
    pmaddubsw  m3, m7
    %xdefine fenc_buf fenc_buf+gprsize ; extra retaddr appended
    psubw      m0, [fenc_buf+0x00]
    psubw      m1, [fenc_buf+0x10]
    psubw      m2, [fenc_buf+0x20]
.satd_8x4b:      ; r4=$$
    psubw      m3, [fenc_buf+0x30]
    SATD_8x4_SSE 0, 0, 1, 2, 3, 4, 5, 0, swap ; PIC*
    PIC_BEGIN
    pmaddwd    m0, [pic(pw_1)]
    PIC_END
    MOVHL      m1, m0
    paddd    xmm0, m0, m1
%if i386pic
    %assign  picb  0
    %undef   rpic
    %undef   lpic
%endif
    ret
%endif ; ARCH
%endmacro ; INTRA_X9

%macro INTRA8_X9 0
;-----------------------------------------------------------------------------
; int intra_sad_x9_8x8( uint8_t *fenc, uint8_t *fdec, uint8_t edge[36], uint16_t *bitcosts, uint16_t *satds )
;-----------------------------------------------------------------------------
cglobal intra_sad_x9_8x8, 5,6,9
    %define fenc02 m4
    %define fenc13 m5
    %define fenc46 m6
    %define fenc57 m7
%if ARCH_X86_64
    %define tmp m8
    %assign padbase 0x0
%else
    %define tmp [rsp]
    %assign padbase 0x10 ; == tmpsize
%endif
    ; Add gprsize for rpic and 0x240+padbase for pred+padbase, and align:
    %assign %%pad gprsize+0x240+padbase + \
        (15 & -(gprsize+stack_offset+gprsize+0x240+padbase))

    SUB        rsp, %%pad ; alloc rpicsave/pred/padbase area
    %define rpicsave  [rsp+padbase+0x240]         ; gprsize
    ; pred(0,0)..pred(8,3) -> [rsp+padbase]..[rsp+padbase+0x230]
    %define pred(i,j) [rsp+padbase+i*0x40+j*0x10] ; size 0x240+padbase

    PIC_BEGIN r6 ; do it once and for whole function
    CHECK_REG_COLLISION "rpic","tmp","pred", eax;retval

    movq    fenc02, [r0+FENC_STRIDE* 0]
    movq    fenc13, [r0+FENC_STRIDE* 1]
    movq    fenc46, [r0+FENC_STRIDE* 4]
    movq    fenc57, [r0+FENC_STRIDE* 5]
    movhps  fenc02, [r0+FENC_STRIDE* 2]
    movhps  fenc13, [r0+FENC_STRIDE* 3]
    movhps  fenc46, [r0+FENC_STRIDE* 6]
    movhps  fenc57, [r0+FENC_STRIDE* 7]

    ; save instruction size: avoid 4-byte memory offsets
    PIC_BEGIN r0, 0
    lea         r0, [pic(intra8x9_h1)+128]
    PIC_END
    %define off(m) (r0+m-(intra8x9_h1+128))

; v
    movddup     m0, [r2+16]
    mova pred(0,0), m0   ; [rsp]    *x86_64 / [esp+0x10] *i386
    psadbw      m1, m0, fenc02
    mova pred(0,1), m0   ; [rsp+0x10]       / [esp+0x20]
    psadbw      m2, m0, fenc13
    mova pred(0,2), m0   ; [rsp+0x20]       / [esp+0x30]
    psadbw      m3, m0, fenc46
    mova pred(0,3), m0   ; [rsp+0x30]       / [esp+0x40]
    psadbw      m0, m0, fenc57
    paddw       m1, m2
    paddw       m0, m3
    paddw       m0, m1
    MOVHL       m1, m0
    paddw       m0, m1
    movd    [r4+0], m0

; h
    movq        m0, [r2+7]
    pshufb      m1, m0, [off(intra8x9_h1)]
    pshufb      m2, m0, [off(intra8x9_h2)]
    mova pred(1,0), m1   ; [rsp+0x40]       / [esp+0x50]
    psadbw      m1, fenc02
    mova pred(1,1), m2   ; [rsp+0x50]       / [esp+0x60]
    psadbw      m2, fenc13
    paddw       m1, m2
    pshufb      m3, m0, [off(intra8x9_h3)]
    pshufb      m2, m0, [off(intra8x9_h4)]
    mova pred(1,2), m3   ; [rsp+0x60]       / [esp+0x70]
    psadbw      m3, fenc46

    ; r5 is used to convert [esp+off32] into [r5+off8]
    lea         r5, [rsp+padbase+0xF0]
    %define pred(i,j) [r5+i*0x40+j*0x10-0xF0] ; 1 byte offsets
    ; The following `mova pred(1,3), m2' instruction
    ;     in esp base:
    ; 7fab:       0f 29 94 24 80 00 00    movaps %xmm2,0x80(%esp)
    ; 7fb2:       00
    ;     in r5/edi base:
    ; 7fb2:       0f 29 57 80             movaps %xmm2,-0x80(%edi)

    mova pred(1,3), m2   ; [rsp+0x70]       / [esp+0x00000080]
                         ; [r5-0x80]        / [r5-0x80]
    psadbw      m2, fenc57
    paddw       m1, m3
    paddw       m1, m2
    MOVHL       m2, m1
    paddw       m1, m2
    movd    [r4+2], m1

; dc
    movhps      m0, [r2+16]
    pxor        m2, m2
    psadbw      m0, m2
    MOVHL       m1, m0
    paddw       m0, m1
    psrlw       m0, 3
    pavgw       m0, m2
    pshufb      m0, m2
    mova pred(2,0), m0   ; [rsp+0x00000080] / [esp+0x00000090]
                         ; [r5-0x70]        / [r5-0x70]
    psadbw      m1, m0, fenc02
    mova pred(2,1), m0   ; [rsp+0x00000090] / [esp+0x000000a0]
                         ; [r5-0x60]        / [r5-0x60]
    psadbw      m2, m0, fenc13
    mova pred(2,2), m0   ; [rsp+0x000000a0] / [esp+0x000000b0]
                         ; [r5-0x50]        / [r5-0x50]
    psadbw      m3, m0, fenc46
    mova pred(2,3), m0   ; [rsp+0x000000b0] / [esp+0x000000c0]
                         ; [r5-0x40]        / [r5-0x40]
    psadbw      m0, m0, fenc57
    paddw       m1, m2
    paddw       m0, m3
    paddw       m0, m1
    MOVHL       m1, m0
    paddw       m0, m1
    movd    [r4+4], m0

; ddl
; Ft1 Ft2 Ft3 Ft4 Ft5 Ft6 Ft7 Ft8
; Ft2 Ft3 Ft4 Ft5 Ft6 Ft7 Ft8 Ft9
; Ft3 Ft4 Ft5 Ft6 Ft7 Ft8 Ft9 FtA
; Ft4 Ft5 Ft6 Ft7 Ft8 Ft9 FtA FtB
; Ft5 Ft6 Ft7 Ft8 Ft9 FtA FtB FtC
; Ft6 Ft7 Ft8 Ft9 FtA FtB FtC FtD
; Ft7 Ft8 Ft9 FtA FtB FtC FtD FtE
; Ft8 Ft9 FtA FtB FtC FtD FtE FtF
    mova        m0, [r2+16]
    movu        m2, [r2+17]
    pslldq      m1, m0, 1
    pavgb       m3, m0, m2              ; Gt1 Gt2 Gt3 Gt4 Gt5 Gt6 Gt7 Gt8 Gt9 GtA GtB ___ ___ ___ ___ ___
    PRED4x4_LOWPASS m0, m1, m2, m0, tmp ; ___ Ft1 Ft2 Ft3 Ft4 Ft5 Ft6 Ft7 Ft8 Ft9 FtA FtB FtC FtD FtE FtF ; PIC
    pshufb      m1, m0, [off(intra8x9_ddl1)]
    pshufb      m2, m0, [off(intra8x9_ddl2)]
    mova pred(3,0), m1   ; [rsp+0x000000c0] / [esp+0x000000d0]
                         ; [r5-0x30]        / [r5-0x30]
    psadbw      m1, fenc02
    mova pred(3,1), m2   ; [rsp+0x000000e0] / [esp+0x000000f0]
                         ; [r5-0x20]        / [r5-0x20]
    psadbw      m2, fenc13
    paddw       m1, m2
    pshufb      m2, m0, [off(intra8x9_ddl3)]
    mova pred(3,2), m2   ; [rsp+0x000000f0] / [esp+0x00000100]
                         ; [r5-0x10]        / [r5-0x10]
    psadbw      m2, fenc46
    paddw       m1, m2
    pshufb      m2, m0, [off(intra8x9_ddl4)]
    mova pred(3,3), m2   ; [rsp+0x00000100] / [esp+0x00000c0]
                         ; [r5]             / [r5]
    psadbw      m2, fenc57
    paddw       m1, m2
    MOVHL       m2, m1
    paddw       m1, m2
    movd    [r4+6], m1

; vl
; Gt1 Gt2 Gt3 Gt4 Gt5 Gt6 Gt7 Gt8
; Ft1 Ft2 Ft3 Ft4 Ft5 Ft6 Ft7 Ft8
; Gt2 Gt3 Gt4 Gt5 Gt6 Gt7 Gt8 Gt9
; Ft2 Ft3 Ft4 Ft5 Ft6 Ft7 Ft8 Ft9
; Gt3 Gt4 Gt5 Gt6 Gt7 Gt8 Gt9 GtA
; Ft3 Ft4 Ft5 Ft6 Ft7 Ft8 Ft9 FtA
; Gt4 Gt5 Gt6 Gt7 Gt8 Gt9 GtA GtB
; Ft4 Ft5 Ft6 Ft7 Ft8 Ft9 FtA FtB
    pshufb      m1, m3, [off(intra8x9_vl1)]
    pshufb      m2, m0, [off(intra8x9_vl2)]
    pshufb      m3, m3, [off(intra8x9_vl3)]
    pshufb      m0, m0, [off(intra8x9_vl4)]
    add         r5, 0x90 ; r5 == rsp+padbase+0x180
    %define pred(i,j) [r5-0x180+i*0x40+j*0x10] ; 1 byte offsets
    mova pred(7,0), m1   ; [rsp+0x000001c0] / [esp+0x000001d0]
                         ; [r5+0x40]        / [r5+0x40]
    psadbw      m1, fenc02
    mova pred(7,1), m2   ; [rsp+0x000001d0] / [esp+0x000001e0]
                         ; [r5+0x50]        / [r5+0x50]
    psadbw      m2, fenc13
    mova pred(7,2), m3   ; [rsp+0x000001e0] / [esp+0x000001f0]
                         ; [r5+0x60]        / [r5+0x60]
    psadbw      m3, fenc46
    mova pred(7,3), m0   ; [rsp+0x000001f0] / [esp+0x00000200]
                         ; [r5+0x70]        / [r5+0x70]
    psadbw      m0, fenc57
    paddw       m1, m2
    paddw       m0, m3
    paddw       m0, m1
    MOVHL       m1, m0
    paddw       m0, m1
%if cpuflag(sse4)
    pextrw [r4+14], m0, 0
%else
    movd       r5d, m0                  ; here r5 is used as
    mov    [r4+14], r5w                 ; a temporary register
    lea         r5, [rsp+padbase+0x180] ; and then reset
%endif

; ddr
; Flt Ft0 Ft1 Ft2 Ft3 Ft4 Ft5 Ft6
; Fl0 Flt Ft0 Ft1 Ft2 Ft3 Ft4 Ft5
; Fl1 Fl0 Flt Ft0 Ft1 Ft2 Ft3 Ft4
; Fl2 Fl1 Fl0 Flt Ft0 Ft1 Ft2 Ft3
; Fl3 Fl2 Fl1 Fl0 Flt Ft0 Ft1 Ft2
; Fl4 Fl3 Fl2 Fl1 Fl0 Flt Ft0 Ft1
; Fl5 Fl4 Fl3 Fl2 Fl1 Fl0 Flt Ft0
; Fl6 Fl5 Fl4 Fl3 Fl2 Fl1 Fl0 Flt
    movu        m2, [r2+8]
    movu        m0, [r2+7]
    movu        m1, [r2+6]
    pavgb       m3, m2, m0              ; Gl6 Gl5 Gl4 Gl3 Gl2 Gl1 Gl0 Glt Gt0 Gt1 Gt2 Gt3 Gt4 Gt5 Gt6 Gt7
    PRED4x4_LOWPASS m0, m1, m2, m0, tmp ; Fl7 Fl6 Fl5 Fl4 Fl3 Fl2 Fl1 Fl0 Flt Ft0 Ft1 Ft2 Ft3 Ft4 Ft5 Ft6 ; PIC
    ; %undef rpicsave ; no more PIC in this function
    pshufb      m1, m0, [off(intra8x9_ddr1)]
    pshufb      m2, m0, [off(intra8x9_ddr2)]
    mova pred(4,0), m1   ; [rsp+0x00000100] / [esp+0x00000110]
                         ; [r5-0x80]        / [r5-0x80]
    psadbw      m1, fenc02
    mova pred(4,1), m2   ; [rsp+0x00000110] / [esp+0x00000120]
                         ; [r5-0x70]        / [r5-0x70]
    psadbw      m2, fenc13
    paddw       m1, m2
    pshufb      m2, m0, [off(intra8x9_ddr3)]
    mova pred(4,2), m2   ; [rsp+0x00000120] / [esp+0x00000130]
                         ; [r5-0x60]        / [r5-0x60]
    psadbw      m2, fenc46
    paddw       m1, m2
    pshufb      m2, m0, [off(intra8x9_ddr4)]
    mova pred(4,3), m2   ; [rsp+0x00000130] / [esp+0x00000140]
                         ; [r5-0x50]        / [r5-0x50]
    psadbw      m2, fenc57
    paddw       m1, m2
    MOVHL       m2, m1
    paddw       m1, m2
    movd    [r4+8], m1

    add         r0, 256
    %define off(m) (r0+m-(intra8x9_h1+256+128))

; vr
; Gt0 Gt1 Gt2 Gt3 Gt4 Gt5 Gt6 Gt7
; Flt Ft0 Ft1 Ft2 Ft3 Ft4 Ft5 Ft6
; Fl0 Gt0 Gt1 Gt2 Gt3 Gt4 Gt5 Gt6
; Fl1 Flt Ft0 Ft1 Ft2 Ft3 Ft4 Ft5
; Fl2 Fl0 Gt0 Gt1 Gt2 Gt3 Gt4 Gt5
; Fl3 Fl1 Flt Ft0 Ft1 Ft2 Ft3 Ft4
; Fl4 Fl2 Fl0 Gt0 Gt1 Gt2 Gt3 Gt4
; Fl5 Fl3 Fl1 Flt Ft0 Ft1 Ft2 Ft3
    movsd       m2, m3, m0 ; Fl7 Fl6 Fl5 Fl4 Fl3 Fl2 Fl1 Fl0 Gt0 Gt1 Gt2 Gt3 Gt4 Gt5 Gt6 Gt7
    pshufb      m1, m2, [off(intra8x9_vr1)]
    pshufb      m2, m2, [off(intra8x9_vr3)]
    mova pred(5,0), m1   ; [rsp+0x00000140] / [esp+0x00000150]
                         ; [r5-0x40]        / [r5-0x40]
    psadbw      m1, fenc02
    mova pred(5,2), m2   ; [rsp+0x00000160] / [esp+0x00000170]
                         ; [r5-0x20]        / [r5-0x20]
    psadbw      m2, fenc46
    paddw       m1, m2
    pshufb      m2, m0, [off(intra8x9_vr2)]
    mova pred(5,1), m2   ; [rsp+0x00000150] / [esp+0x00000160]
                         ; [r5-0x30]        / [r5-0x30]
    psadbw      m2, fenc13
    paddw       m1, m2
    pshufb      m2, m0, [off(intra8x9_vr4)]
    mova pred(5,3), m2   ; [rsp+0x00000170] / [esp+0x00000180]
                         ; [r5-0x10]        / [r5-0x10]
    psadbw      m2, fenc57
    paddw       m1, m2
    MOVHL       m2, m1
    paddw       m1, m2
    movd   [r4+10], m1

; hd
; Glt Flt Ft0 Ft1 Ft2 Ft3 Ft4 Ft5
; Gl0 Fl0 Glt Flt Ft0 Ft1 Ft2 Ft3
; Gl1 Fl1 Gl0 Fl0 Glt Flt Ft0 Ft1
; Gl2 Fl2 Gl1 Fl1 Gl0 Fl0 Glt Flt
; Gl3 Fl3 Gl2 Fl2 Gl1 Fl1 Gl0 Fl0
; Gl4 Fl4 Gl3 Fl3 Gl2 Fl2 Gl1 Fl1
; Gl5 Fl5 Gl4 Fl4 Gl3 Fl3 Gl2 Fl2
; Gl6 Fl6 Gl5 Fl5 Gl4 Fl4 Gl3 Fl3
    pshufd      m2, m3, q0001
%if cpuflag(sse4)
    pblendw     m2, m0, q3330 ; Gl2 Gl1 Gl0 Glt ___ Fl2 Fl1 Fl0 Flt Ft0 Ft1 Ft2 Ft3 Ft4 Ft5 ___
%else
    movss       m1, m0, m2
    SWAP        1, 2
%endif
    punpcklbw   m0, m3        ; Fl7 Gl6 Fl6 Gl5 Fl5 Gl4 Fl4 Gl3 Fl3 Gl2 Fl2 Gl1 Fl1 Gl0 Fl0 ___
    pshufb      m1, m2, [off(intra8x9_hd1)]
    pshufb      m2, m2, [off(intra8x9_hd2)]
    mova pred(6,0), m1   ; [rsp+0x00000180] / [esp+0x00000190]
                         ; [r5]             / [r5]
    psadbw      m1, fenc02
    mova pred(6,1), m2   ; [rsp+0x00000190] / [esp+0x000001a0]
                         ; [r5+0x10]        / [r5+0x10]
    psadbw      m2, fenc13
    paddw       m1, m2
    pshufb      m2, m0, [off(intra8x9_hd3)]
    pshufb      m3, m0, [off(intra8x9_hd4)]
    mova pred(6,2), m2   ; [rsp+0x000001a0] / [esp+0x000001b0]
                         ; [r5+0x20]        / [r5+0x20]
    psadbw      m2, fenc46
    mova pred(6,3), m3   ; [rsp+0x000001b0] / [esp+0x000001c0]
                         ; [r5+0x30]        / [r5+0x30]
    psadbw      m3, fenc57
    paddw       m1, m2
    paddw       m1, m3
    MOVHL       m2, m1
    paddw       m1, m2
    ; don't just store to [r4+12]. this is too close to the load of dqword [r4] and would cause a forwarding stall
    pslldq      m1, 12
    SWAP        3, 1

; hu
; Gl0 Fl1 Gl1 Fl2 Gl2 Fl3 Gl3 Fl4
; Gl1 Fl2 Gl2 Fl3 Gl3 Fl4 Gl4 Fl5
; Gl2 Fl3 Gl3 Gl3 Gl4 Fl5 Gl5 Fl6
; Gl3 Gl3 Gl4 Fl5 Gl5 Fl6 Gl6 Fl7
; Gl4 Fl5 Gl5 Fl6 Gl6 Fl7 Gl7 Gl7
; Gl5 Fl6 Gl6 Fl7 Gl7 Gl7 Gl7 Gl7
; Gl6 Fl7 Gl7 Gl7 Gl7 Gl7 Gl7 Gl7
; Gl7 Gl7 Gl7 Gl7 Gl7 Gl7 Gl7 Gl7
%if cpuflag(sse4)
    pinsrb      m0, [r2+7], 15 ; Gl7
%else
    movd        m1, [r2+7]
    pslldq      m0, 1
    palignr     m1, m0, 1
    SWAP        0, 1
%endif
    pshufb      m1, m0, [off(intra8x9_hu1)]
    pshufb      m2, m0, [off(intra8x9_hu2)]
    ;add        r5, 0x80 ; r5 == rsp+padbase+0x200
    sub         r5,-0x80 ; r5 == rsp+padbase+0x200
    %define pred(i,j) [r5-0x200+i*0x40+j*0x10] ; 1 byte offsets
    mova pred(8,0), m1   ; [rsp+0x00000200] / [esp+0x00000210]
                         ; [r5]             / [r5]
    psadbw      m1, fenc02
    mova pred(8,1), m2   ; [rsp+0x00000210] / [esp+0x00000220]
                         ; [r5+0x10]        / [r5+0x10]
    psadbw      m2, fenc13
    paddw       m1, m2
    pshufb      m2, m0, [off(intra8x9_hu3)]
    pshufb      m0, m0, [off(intra8x9_hu4)]
    mova pred(8,2), m2   ; [rsp+0x00000220] / [esp+0x00000230]
                         ; [r5+0x20]        / [r5+0x20]
    psadbw      m2, fenc46
    mova pred(8,3), m0   ; [rsp+0x00000230] / [esp+0x00000240]
                         ; [r5+0x30]        / [r5+0x30]
    psadbw      m0, fenc57
    paddw       m1, m2
    paddw       m1, m0
    MOVHL       m2, m1
    paddw       m1, m2
    movd       r2d, m1

    movu        m0, [r3]
    por         m3, [r4]
    paddw       m0, m3
    mova      [r4], m0
    movzx      r5d, word [r3+16]
    add        r2d, r5d
    mov    [r4+16], r2w

%if cpuflag(sse4)
    phminposuw m0, m0 ; v,h,dc,ddl,ddr,vr,hd,vl
    movd      eax, m0
%else
    ; 8x8 sad is up to 14 bits; +bitcosts and saturate -> 14 bits; pack with 2 bit index
    paddusw    m0, m0
    paddusw    m0, m0
    paddw      m0, [off(pw_s00112233)]
    MOVHL      m1, m0
    pminsw     m0, m1
    pshuflw    m1, m0, q0032
    pminsw     m0, m1
    movd      eax, m0
    ; repack with 3 bit index
    xor       eax, 0x80008000
    movzx     r3d, ax
    shr       eax, 15
    add       r3d, r3d
    or        eax, 1
    cmp       eax, r3d
    cmovg     eax, r3d
    ; reverse to phminposuw order
    mov       r3d, eax
    and       eax, 7
    shr       r3d, 3
    shl       eax, 16
    or        eax, r3d
%endif
    add       r2d, 8<<16
    cmp        ax, r2w
    cmovg     eax, r2d

    mov       r2d, eax
    shr       r2d, 16
    shl       r2d, 6
    add        r1, 4*FDEC_STRIDE
    mova       m0, [rsp+padbase+r2+0x00]
    mova       m1, [rsp+padbase+r2+0x10]
    mova       m2, [rsp+padbase+r2+0x20]
    mova       m3, [rsp+padbase+r2+0x30]
    movq   [r1+FDEC_STRIDE*-4], m0
    movhps [r1+FDEC_STRIDE*-2], m0
    movq   [r1+FDEC_STRIDE*-3], m1
    movhps [r1+FDEC_STRIDE*-1], m1
    movq   [r1+FDEC_STRIDE* 0], m2
    movhps [r1+FDEC_STRIDE* 2], m2
    movq   [r1+FDEC_STRIDE* 1], m3
    movhps [r1+FDEC_STRIDE* 3], m3
    PIC_END
    ADD       rsp, %%pad ; free rpicsave/pred/padbase area
    %undef  %%pad
    RET

%if ARCH_X86_64
;-----------------------------------------------------------------------------
; int intra_sa8d_x9_8x8( uint8_t *fenc, uint8_t *fdec, uint8_t edge[36], uint16_t *bitcosts, uint16_t *satds )
;-----------------------------------------------------------------------------
cglobal intra_sa8d_x9_8x8, 5,6,16
    %assign pad 0x2c0+0x10-gprsize-(stack_offset&15)
    %define fenc_buf rsp
    %define pred_buf rsp+0x80
    SUB        rsp, pad
    mova       m15, [hmul_8p]
    pxor        m8, m8
%assign %%i 0
%rep 8
    movddup     m %+ %%i, [r0+%%i*FENC_STRIDE]
    pmaddubsw   m9, m %+ %%i, m15
    punpcklbw   m %+ %%i, m8
    mova [fenc_buf+%%i*0x10], m9
%assign %%i %%i+1
%endrep

    ; save instruction size: avoid 4-byte memory offsets
    lea         r0, [intra8x9_h1+0x80]
    %define off(m) (r0+m-(intra8x9_h1+0x80))
    lea         r5, [pred_buf+0x80]

; v, h, dc
    HADAMARD8_2D 0, 1, 2, 3, 4, 5, 6, 7, 8
    pabsw      m11, m1
%assign %%i 2
%rep 6
    pabsw       m8, m %+ %%i
    paddw      m11, m8
%assign %%i %%i+1
%endrep

    ; 1D hadamard of edges
    movq        m8, [r2+7]
    movddup     m9, [r2+16]
    mova [r5-0x80], m9
    mova [r5-0x70], m9
    mova [r5-0x60], m9
    mova [r5-0x50], m9
    punpcklwd   m8, m8
    pshufb      m9, [intrax3_shuf]
    pmaddubsw   m8, [pb_pppm]
    pmaddubsw   m9, [pb_pppm]
    HSUMSUB2 psignw, m8, m9, m12, m13, m9, q1032, [pw_ppppmmmm]
    HSUMSUB2 psignw, m8, m9, m12, m13, m9, q2301, [pw_ppmmppmm]

    ; dc
    paddw      m10, m8, m9
    paddw      m10, [pw_8]
    pand       m10, [sw_f0]
    psrlw      m12, m10, 4
    psllw      m10, 2
    pxor       m13, m13
    pshufb     m12, m13
    mova [r5+0x00], m12
    mova [r5+0x10], m12
    mova [r5+0x20], m12
    mova [r5+0x30], m12

    ; differences
    psllw       m8, 3 ; left edge
    psubw       m8, m0
    psubw      m10, m0
    pabsw       m8, m8 ; 1x8 sum
    pabsw      m10, m10
    paddw       m8, m11
    paddw      m11, m10
    punpcklwd   m0, m1
    punpcklwd   m2, m3
    punpcklwd   m4, m5
    punpcklwd   m6, m7
    punpckldq   m0, m2
    punpckldq   m4, m6
    punpcklqdq  m0, m4 ; transpose
    psllw       m9, 3  ; top edge
    psrldq     m10, m11, 2 ; 8x7 sum
    psubw       m0, m9 ; 8x1 sum
    pabsw       m0, m0
    paddw      m10, m0

    phaddd     m10, m8 ; logically phaddw, but this is faster and it won't overflow
    psrlw      m11, 1
    psrlw      m10, 1

; store h
    movq        m3, [r2+7]
    pshufb      m0, m3, [off(intra8x9_h1)]
    pshufb      m1, m3, [off(intra8x9_h2)]
    pshufb      m2, m3, [off(intra8x9_h3)]
    pshufb      m3, m3, [off(intra8x9_h4)]
    mova [r5-0x40], m0
    mova [r5-0x30], m1
    mova [r5-0x20], m2
    mova [r5-0x10], m3

; ddl
    mova        m8, [r2+16]
    movu        m2, [r2+17]
    pslldq      m1, m8, 1
    pavgb       m9, m8, m2
    PRED4x4_LOWPASS m8, m1, m2, m8, m3
    pshufb      m0, m8, [off(intra8x9_ddl1)]
    pshufb      m1, m8, [off(intra8x9_ddl2)]
    pshufb      m2, m8, [off(intra8x9_ddl3)]
    pshufb      m3, m8, [off(intra8x9_ddl4)]
    add         r5, 0x40
    call .sa8d
    phaddd     m11, m0

; vl
    pshufb      m0, m9, [off(intra8x9_vl1)]
    pshufb      m1, m8, [off(intra8x9_vl2)]
    pshufb      m2, m9, [off(intra8x9_vl3)]
    pshufb      m3, m8, [off(intra8x9_vl4)]
    add         r5, 0x100
    call .sa8d
    phaddd     m10, m11
    mova       m12, m0

; ddr
    movu        m2, [r2+8]
    movu        m8, [r2+7]
    movu        m1, [r2+6]
    pavgb       m9, m2, m8
    PRED4x4_LOWPASS m8, m1, m2, m8, m3
    pshufb      m0, m8, [off(intra8x9_ddr1)]
    pshufb      m1, m8, [off(intra8x9_ddr2)]
    pshufb      m2, m8, [off(intra8x9_ddr3)]
    pshufb      m3, m8, [off(intra8x9_ddr4)]
    sub         r5, 0xc0
    call .sa8d
    mova       m11, m0

    add         r0, 0x100
    %define off(m) (r0+m-(intra8x9_h1+0x180))

; vr
    movsd       m2, m9, m8
    pshufb      m0, m2, [off(intra8x9_vr1)]
    pshufb      m1, m8, [off(intra8x9_vr2)]
    pshufb      m2, m2, [off(intra8x9_vr3)]
    pshufb      m3, m8, [off(intra8x9_vr4)]
    add         r5, 0x40
    call .sa8d
    phaddd     m11, m0

; hd
%if cpuflag(sse4)
    pshufd      m1, m9, q0001
    pblendw     m1, m8, q3330
%else
    pshufd      m2, m9, q0001
    movss       m1, m8, m2
%endif
    punpcklbw   m8, m9
    pshufb      m0, m1, [off(intra8x9_hd1)]
    pshufb      m1, m1, [off(intra8x9_hd2)]
    pshufb      m2, m8, [off(intra8x9_hd3)]
    pshufb      m3, m8, [off(intra8x9_hd4)]
    add         r5, 0x40
    call .sa8d
    phaddd      m0, m12
    phaddd     m11, m0

; hu
%if cpuflag(sse4)
    pinsrb      m8, [r2+7], 15
%else
    movd        m9, [r2+7]
    pslldq      m8, 1
    palignr     m9, m8, 1
    SWAP        8, 9
%endif
    pshufb      m0, m8, [off(intra8x9_hu1)]
    pshufb      m1, m8, [off(intra8x9_hu2)]
    pshufb      m2, m8, [off(intra8x9_hu3)]
    pshufb      m3, m8, [off(intra8x9_hu4)]
    add         r5, 0x80
    call .sa8d

    pmaddwd     m0, [pw_1]
    phaddw     m10, m11
    MOVHL       m1, m0
    paddw       m0, m1
    pshuflw     m1, m0, q0032
    pavgw       m0, m1
    pxor        m2, m2
    pavgw      m10, m2
    movd       r2d, m0

    movu        m0, [r3]
    paddw       m0, m10
    mova      [r4], m0
    movzx      r5d, word [r3+16]
    add        r2d, r5d
    mov    [r4+16], r2w

%if cpuflag(sse4)
    phminposuw m0, m0
    movd      eax, m0
%else
    ; 8x8 sa8d is up to 15 bits; +bitcosts and saturate -> 15 bits; pack with 1 bit index
    paddusw    m0, m0
    paddw      m0, [off(pw_s00001111)]
    MOVHL      m1, m0
    pminsw     m0, m1
    pshuflw    m1, m0, q0032
    mova       m2, m0
    pminsw     m0, m1
    pcmpgtw    m2, m1 ; 2nd index bit
    movd      r3d, m0
    movd      r4d, m2
    ; repack with 3 bit index
    xor       r3d, 0x80008000
    and       r4d, 0x00020002
    movzx     eax, r3w
    movzx     r5d, r4w
    shr       r3d, 16
    shr       r4d, 16
    lea       eax, [rax*4+r5]
    lea       r3d, [ r3*4+r4+1]
    cmp       eax, r3d
    cmovg     eax, r3d
    ; reverse to phminposuw order
    mov       r3d, eax
    and       eax, 7
    shr       r3d, 3
    shl       eax, 16
    or        eax, r3d
%endif
    add       r2d, 8<<16
    cmp        ax, r2w
    cmovg     eax, r2d

    mov       r2d, eax
    shr       r2d, 16
    shl       r2d, 6
    add        r1, 4*FDEC_STRIDE
    mova       m0, [pred_buf+r2+0x00]
    mova       m1, [pred_buf+r2+0x10]
    mova       m2, [pred_buf+r2+0x20]
    mova       m3, [pred_buf+r2+0x30]
    movq   [r1+FDEC_STRIDE*-4], m0
    movhps [r1+FDEC_STRIDE*-2], m0
    movq   [r1+FDEC_STRIDE*-3], m1
    movhps [r1+FDEC_STRIDE*-1], m1
    movq   [r1+FDEC_STRIDE* 0], m2
    movhps [r1+FDEC_STRIDE* 2], m2
    movq   [r1+FDEC_STRIDE* 1], m3
    movhps [r1+FDEC_STRIDE* 3], m3
    ADD       rsp, pad
    RET

ALIGN 16
.sa8d:
    %xdefine mret m0
    %xdefine fenc_buf fenc_buf+gprsize
    mova [r5+0x00], m0
    mova [r5+0x10], m1
    mova [r5+0x20], m2
    mova [r5+0x30], m3
    movddup     m4, m0
    movddup     m5, m1
    movddup     m6, m2
    movddup     m7, m3
    punpckhqdq  m0, m0
    punpckhqdq  m1, m1
    punpckhqdq  m2, m2
    punpckhqdq  m3, m3
    PERMUTE 0,4, 1,5, 2,0, 3,1, 4,6, 5,7, 6,2, 7,3
    pmaddubsw   m0, m15
    pmaddubsw   m1, m15
    psubw       m0, [fenc_buf+0x00]
    psubw       m1, [fenc_buf+0x10]
    pmaddubsw   m2, m15
    pmaddubsw   m3, m15
    psubw       m2, [fenc_buf+0x20]
    psubw       m3, [fenc_buf+0x30]
    pmaddubsw   m4, m15
    pmaddubsw   m5, m15
    psubw       m4, [fenc_buf+0x40]
    psubw       m5, [fenc_buf+0x50]
    pmaddubsw   m6, m15
    pmaddubsw   m7, m15
    psubw       m6, [fenc_buf+0x60]
    psubw       m7, [fenc_buf+0x70]
    HADAMARD8_2D_HMUL 0, 1, 2, 3, 4, 5, 6, 7, 13, 14
    paddw       m0, m1
    paddw       m0, m2
    paddw mret, m0, m3
    ret
%endif ; ARCH_X86_64
%endmacro ; INTRA8_X9

; in:  r0=pix, r1=stride, r2=stride*3, r3=tmp, m6=mask_ac4, m7=0
; out: [tmp]=hadamard4, m0=satd
INIT_MMX mmx2
cglobal hadamard_ac_4x4
%if HIGH_BIT_DEPTH
    mova      m0, [r0]
    mova      m1, [r0+r1]
    mova      m2, [r0+r1*2]
    mova      m3, [r0+r2]
%else ; !HIGH_BIT_DEPTH
    movh      m0, [r0]
    movh      m1, [r0+r1]
    movh      m2, [r0+r1*2]
    movh      m3, [r0+r2]
    punpcklbw m0, m7
    punpcklbw m1, m7
    punpcklbw m2, m7
    punpcklbw m3, m7
%endif ; HIGH_BIT_DEPTH
    HADAMARD4_2D 0, 1, 2, 3, 4
    mova [r3],    m0
    mova [r3+8],  m1
    mova [r3+16], m2
    mova [r3+24], m3
    ABSW      m0, m0, m4
    ABSW      m1, m1, m4
    pand      m0, m6
    ABSW      m2, m2, m4
    ABSW      m3, m3, m4
    paddw     m0, m1
    paddw     m2, m3
    paddw     m0, m2
    SAVE_MM_PERMUTATION
    ret

cglobal hadamard_ac_2x2max
    mova      m0, [r3+0x00]
    mova      m1, [r3+0x20]
    mova      m2, [r3+0x40]
    mova      m3, [r3+0x60]
    sub       r3, 8
    SUMSUB_BADC w, 0, 1, 2, 3, 4
    ABSW2 m0, m2, m0, m2, m4, m5
    ABSW2 m1, m3, m1, m3, m4, m5
    HADAMARD 0, max, 0, 2, 4, 5
    HADAMARD 0, max, 1, 3, 4, 5
%if HIGH_BIT_DEPTH
    pmaddwd   m0, m7
    pmaddwd   m1, m7
    paddd     m6, m0
    paddd     m6, m1
%else ; !HIGH_BIT_DEPTH
    paddw     m7, m0
    paddw     m7, m1
%endif ; HIGH_BIT_DEPTH
    SAVE_MM_PERMUTATION
    ret

%macro AC_PREP 2
%if HIGH_BIT_DEPTH
    pmaddwd %1, %2
%endif
%endmacro

%macro AC_PADD 3
%if HIGH_BIT_DEPTH
    AC_PREP %2, %3
    paddd   %1, %2
%else
    paddw   %1, %2
%endif ; HIGH_BIT_DEPTH
%endmacro

; in:  r0=pix, r1=stride, r2=stride*3, r3=tmp? r4=$$
; mid: m6=mask_ac4, m7=(HIGH_BIT_DEPTH ? pw_1 : 0)
; out: tmp[0:31]=hadamard4, [rsp+gprsize+8]=satd, [rsp+gprsize]=sa8d
cglobal hadamard_ac_8x8
%if i386pic
    %assign  picb  1
    %xdefine rpic  r4
    %xdefine lpic $$
%endif
    PIC_BEGIN r5, 1 ; no-op
    mova      m6, [pic(mask_ac4)] ; [(r4+(mask_ac4)-$$)]
%if HIGH_BIT_DEPTH
    mova      m7, [pic(pw_1)] ; [(r4+(pw_1)-$$)]
    PIC_END
%else
    PIC_END
    pxor      m7, m7
%endif ; HIGH_BIT_DEPTH
    call hadamard_ac_4x4_mmx2 ; in: r0..3,m6..7; out: tmp[0:31]
    add       r0, 4*SIZEOF_PIXEL
    add       r3, 32          ; r3=tmp+32
    mova      m5, m0
    AC_PREP   m5, m7
    call hadamard_ac_4x4_mmx2 ; tmp[32,63]
    lea       r0, [r0+4*r1]
    add       r3, 64          ; r3=tmp+96
    AC_PADD   m5, m0, m7
    call hadamard_ac_4x4_mmx2 ; tmp[96,127]
    sub       r0, 4*SIZEOF_PIXEL
    sub       r3, 32          ; r3=tmp+64
    AC_PADD   m5, m0, m7
    call hadamard_ac_4x4_mmx2 ; tmp[64,95]
    AC_PADD   m5, m0, m7
    sub       r3, 40          ; r3=tmp+24
    mova [rsp+gprsize+8], m5  ; save satd
%if HIGH_BIT_DEPTH
    pxor      m6, m6
%endif
%rep 3
    ; r3=tmp+24, r3=tmp+16, r3=tmp+8
    call hadamard_ac_2x2max_mmx2 ; decrements r3 by 8
%endrep
    ; r3=tmp
    mova      m0, [r3+0x00]
    mova      m1, [r3+0x20]
    mova      m2, [r3+0x40]
    mova      m3, [r3+0x60]
    SUMSUB_BADC w, 0, 1, 2, 3, 4
    HADAMARD 0, sumsub, 0, 2, 4, 5
    ABSW2 m1, m3, m1, m3, m4, m5
    ABSW2 m0, m2, m0, m2, m4, m5
    HADAMARD 0, max, 1, 3, 4, 5
%if HIGH_BIT_DEPTH
    PIC_BEGIN r5, 1 ; no-op
    pand      m0, [pic(mask_ac4)] ; [(r4+(mask_ac4)-$$)]
    PIC_END
    pmaddwd   m1, m7
    pmaddwd   m0, m7
    pmaddwd   m2, m7
    paddd     m6, m1
    paddd     m0, m2
    paddd     m6, m6
    paddd     m0, m6
    SWAP       0,  6
%else ; !HIGH_BIT_DEPTH
    pand      m6, m0
    paddw     m7, m1
    paddw     m6, m2
    paddw     m7, m7
    paddw     m6, m7
%endif ; BIT_DEPTH
    mova [rsp+gprsize], m6 ; save sa8d
    SWAP       0,  6
    SAVE_MM_PERMUTATION
%if i386pic
    %assign picb 0
    %undef  rpic
    %undef  lpic
%endif
    ret

%macro HADAMARD_AC_WXH_SUM_MMX 2 ; stack, PIC*[!HIGH_BIT_DEPTH]
    mova    m1, [rsp+1*mmsize]
%if HIGH_BIT_DEPTH
%if %1*%2 >= 128
    paddd   m0, [rsp+2*mmsize]
    paddd   m1, [rsp+3*mmsize]
%endif
%if %1*%2 == 256
    mova    m2, [rsp+4*mmsize]
    paddd   m1, [rsp+5*mmsize]
    paddd   m2, [rsp+6*mmsize]
    mova    m3, m0
    paddd   m1, [rsp+7*mmsize]
    paddd   m0, m2
%endif
    psrld   m0, 1
    HADDD   m0, m2
    psrld   m1, 1
    HADDD   m1, m3
%else ; !HIGH_BIT_DEPTH
%if %1*%2 >= 128
    paddusw m0, [rsp+2*mmsize]
    paddusw m1, [rsp+3*mmsize]
%endif
%if %1*%2 == 256
    mova    m2, [rsp+4*mmsize]
    paddusw m1, [rsp+5*mmsize]
    paddusw m2, [rsp+6*mmsize]
    mova    m3, m0
    paddusw m1, [rsp+7*mmsize]
    pxor    m3, m2
    PIC_BEGIN r4
    pand    m3, [pic(pw_1)]
    PIC_END
    pavgw   m0, m2
    psubusw m0, m3
    HADDUW  m0, m2
%else
    psrlw   m0, 1
    HADDW   m0, m2 ; PIC*
%endif
    psrlw   m1, 1
    HADDW   m1, m3 ; PIC*
%endif ; BIT_DEPTH
%endmacro

%macro HADAMARD_AC_WXH_MMX 2
cglobal pixel_hadamard_ac_%1x%2, 2,4
    %define rpicsave ; safe to push/pop rpic
    PIC_BEGIN r4, 1, $$
    CHECK_REG_COLLISION "rpic","edx:eax" ; check for collision with retval
    %assign pad 15 & -(gprsize + stack_offset) ; complement to x16
    %assign %%n16 1
    sub  rsp, %%n16*16 + 128 + pad
    %define ysub r1
    FIX_STRIDES r1
    lea  r2, [r1*3]
    lea  r3, [rsp+16]
    call hadamard_ac_8x8_mmx2 ; in: r0..3,r4=$$; out: rsp[0:15],rsp[16:143]
%if %2==16
    %define ysub r2
    lea  r0, [r0+r1*4]
    sub  rsp, 16
    %assign %%n16 %%n16+1
    call hadamard_ac_8x8_mmx2
%endif
%if %1==16
    neg  ysub
    sub  rsp, 16
    %assign %%n16 %%n16+1
    lea  r0, [r0+ysub*4+8*SIZEOF_PIXEL]
    neg  ysub
    call hadamard_ac_8x8_mmx2
%if %2==16
    lea  r0, [r0+r1*4]
    sub  rsp, 16
    %assign %%n16 %%n16+1
    call hadamard_ac_8x8_mmx2
%endif
%endif
    ; PIC will trigger 2 times in HADAMARD_AC_WXH_SUM_MMX:
    HADAMARD_AC_WXH_SUM_MMX %1, %2 ; stack, PIC*
    movd edx, m0
    movd eax, m1
    shr  edx, 1
%if ARCH_X86_64
    shl  rdx, 32
    add  rax, rdx ; retval in edx:eax/rax(edx clobbered)
%endif
    add  rsp, %%n16*16 + 128 + pad
    %undef %%n
    ; If rpic was eax/edx and saved in PIC_BEGIN, it gets restored here in
    ; PIC_END instead of passing retval to caller. Thus we have
    ; CHECK_REG_COLLISION at the top of the function to check for this
    ; screwup.
    ; Another two solutions are:
    ; 1. have PIC_ALLOC/FREE around and PIC_BEGIN/END inside `sub rsp/add rsp'
    ;    block
    ; 2. modify PIC_END to accept optional `restore_rpic' parameter and
    ;    place `PIC_END 0' here instead of default `PIC_END'.
    PIC_END
    RET
%endmacro ; HADAMARD_AC_WXH_MMX

HADAMARD_AC_WXH_MMX 16, 16
HADAMARD_AC_WXH_MMX  8, 16
HADAMARD_AC_WXH_MMX 16,  8
HADAMARD_AC_WXH_MMX  8,  8

%macro LOAD_INC_8x4W_SSE2 5 ; r0..r2
%if HIGH_BIT_DEPTH
    movu      m%1, [r0]
    movu      m%2, [r0+r1]
    movu      m%3, [r0+r1*2]
    movu      m%4, [r0+r2]
%ifidn %1, 0
    lea       r0, [r0+r1*4]
%endif
%else ; !HIGH_BIT_DEPTH
    movh      m%1, [r0]
    movh      m%2, [r0+r1]
    movh      m%3, [r0+r1*2]
    movh      m%4, [r0+r2]
%ifidn %1, 0
    lea       r0, [r0+r1*4]
%endif
    punpcklbw m%1, m%5
    punpcklbw m%2, m%5
    punpcklbw m%3, m%5
    punpcklbw m%4, m%5
%endif ; HIGH_BIT_DEPTH
%endmacro

%macro LOAD_INC_8x4W_SSSE3 5 ; r0..r2
    LOAD_DUP_4x8P %3, %4, %1, %2, [r0+r1*2], [r0+r2], [r0], [r0+r1]
%ifidn %1, 0
    lea       r0, [r0+r1*4]
%endif
    HSUMSUB %1, %2, %3, %4, %5
%endmacro

%macro HADAMARD_AC_SSE2 0
; in:  r0=pix, r1=stride, r2=stride*3, r4=$$
; out: m0,[esp+mmsize]=sa8d, [esp+2*mmsize]=satd, r0+=stride*4
cglobal hadamard_ac_8x8
%if i386pic
    %assign  picb  1
    %xdefine rpic  r4
    %xdefine lpic $$
%endif
%if ARCH_X86_64
    %define spill0 m8
    %define spill1 m9
    %define spill2 m10
%else
    %define spill0 [rsp+gprsize] ; esp+retaddr
    %define spill1 [rsp+gprsize+mmsize]
    %define spill2 [rsp+gprsize+mmsize*2]
%endif
%if HIGH_BIT_DEPTH
    %define vertical 1
%elif cpuflag(ssse3) && notcpuflag(atom)
    %define vertical 0
    ;LOAD_INC loads sumsubs
    PIC_BEGIN ; no-op
    mova      m7, [pic(hmul_8p)]
    PIC_END
%else
    %define vertical 1
    ;LOAD_INC only unpacks to words
    pxor      m7, m7
%endif
    LOAD_INC_8x4W 0, 1, 2, 3, 7 ; r0..r2
%if vertical
    HADAMARD4_2D_SSE 0, 1, 2, 3, 4
%else
    HADAMARD4_V 0, 1, 2, 3, 4
%endif
    mova  spill0, m1
    SWAP 1, 7
    LOAD_INC_8x4W 4, 5, 6, 7, 1 ; r0..r2
%if vertical
    HADAMARD4_2D_SSE 4, 5, 6, 7, 1
%else
    HADAMARD4_V 4, 5, 6, 7, 1
    ; FIXME SWAP
    mova      m1, spill0
    mova      spill0, m6
    mova      spill1, m7
    HADAMARD 1, sumsub, 0, 1, 6, 7 ; PIC*
    HADAMARD 1, sumsub, 2, 3, 6, 7 ; PIC*
    mova      m6, spill0
    mova      m7, spill1
    mova      spill0, m1
    mova      spill1, m0
    HADAMARD 1, sumsub, 4, 5, 1, 0 ; PIC*
    HADAMARD 1, sumsub, 6, 7, 1, 0 ; PIC*
    mova      m0, spill1
%endif
    mova  spill1, m2
    mova  spill2, m3
    ABSW      m1, m0, m0
    ABSW      m2, m4, m4
    ABSW      m3, m5, m5
    paddw     m1, m2
    SUMSUB_BA w, 0, 4
    PIC_BEGIN ; no-op
%if vertical
    pand      m1, [pic(mask_ac4)]
%else
    pand      m1, [pic(mask_ac4b)]
%endif
    AC_PREP   m1, [pic(pw_1)]
    ABSW      m2, spill0
    AC_PADD   m1, m3, [pic(pw_1)]
    ABSW      m3, spill1
    AC_PADD   m1, m2, [pic(pw_1)]
    ABSW      m2, spill2
    AC_PADD   m1, m3, [pic(pw_1)]
    ABSW      m3, m6, m6
    AC_PADD   m1, m2, [pic(pw_1)]
    ABSW      m2, m7, m7
    AC_PADD   m1, m3, [pic(pw_1)]
    AC_PADD   m1, m2, [pic(pw_1)]
    PIC_END
    paddw     m3, m7, spill2
    psubw     m7, spill2
    mova  [rsp+gprsize+mmsize*2], m1 ; save satd
    paddw     m2, m6, spill1
    psubw     m6, spill1
    paddw     m1, m5, spill0
    psubw     m5, spill0
    %assign %%x 2
%if vertical
    %assign %%x 4
%endif
    mova  spill1, m4
    HADAMARD %%x, amax, 3, 7, 4 ; PIC*
    HADAMARD %%x, amax, 2, 6, 7, 4 ; PIC*
    mova      m4, spill1
    HADAMARD %%x, amax, 1, 5, 6, 7 ; PIC*
    HADAMARD %%x, sumsub, 0, 4, 5, 6 ; PIC*
    PIC_BEGIN ; no-op
    AC_PREP   m2, [pic(pw_1)]
    AC_PADD   m2, m3, [pic(pw_1)]
    AC_PADD   m2, m1, [pic(pw_1)]
%if HIGH_BIT_DEPTH
    paddd     m2, m2
%else
    paddw     m2, m2
%endif ; HIGH_BIT_DEPTH
    ABSW      m4, m4, m7
    pand      m0, [pic(mask_ac8)]
    ABSW      m0, m0, m7
    AC_PADD   m2, m4, [pic(pw_1)]
    AC_PADD   m2, m0, [pic(pw_1)]
    PIC_END
    mova [rsp+gprsize+mmsize], m2 ; save sa8d
    SWAP       0, 2
    SAVE_MM_PERMUTATION
%if i386pic
    %assign picb 0
    %undef  rpic
    %undef  lpic
%endif
    ret

HADAMARD_AC_WXH_SSE2 16, 16
HADAMARD_AC_WXH_SSE2 16,  8
%if mmsize <= 16
HADAMARD_AC_WXH_SSE2  8, 16
HADAMARD_AC_WXH_SSE2  8,  8
%endif
%endmacro ; HADAMARD_AC_SSE2

%macro HADAMARD_AC_WXH_SUM_SSE2 2 ; stack, PIC*[!HIGH_BIT_DEPTH]
    mova    m1, [rsp+2*mmsize]
%if HIGH_BIT_DEPTH
%if %1*%2 >= 128
    paddd   m0, [rsp+3*mmsize]
    paddd   m1, [rsp+4*mmsize]
%endif
%if %1*%2 == 256
    paddd   m0, [rsp+5*mmsize]
    paddd   m1, [rsp+6*mmsize]
    paddd   m0, [rsp+7*mmsize]
    paddd   m1, [rsp+8*mmsize]
    psrld   m0, 1
%endif
    HADDD  xm0, xm2
    HADDD  xm1, xm3
%else ; !HIGH_BIT_DEPTH
%if %1*%2*16/mmsize >= 128
    paddusw m0, [rsp+3*mmsize]
    paddusw m1, [rsp+4*mmsize]
%endif
%if %1*%2*16/mmsize == 256
    paddusw m0, [rsp+5*mmsize]
    paddusw m1, [rsp+6*mmsize]
    paddusw m0, [rsp+7*mmsize]
    paddusw m1, [rsp+8*mmsize]
    psrlw   m0, 1
%endif
%if mmsize==32
    vextracti128 xm2, m0, 1
    vextracti128 xm3, m1, 1
    paddusw xm0, xm2
    paddusw xm1, xm3
%endif
    HADDUW xm0, xm2
    HADDW  xm1, xm3 ; PIC*
%endif ; BIT_DEPTH
%endmacro

; struct { int satd, int sa8d; } pixel_hadamard_ac_16x16( uint8_t *pix, int stride )
; DECL_PIXELS( uint64_t, hadamard_ac, sse2,  ( pixel *pix, intptr_t i_stride ))
%macro HADAMARD_AC_WXH_SSE2 2
cglobal pixel_hadamard_ac_%1x%2, 2,4,11
    %define rpicsave ; safe to push/pop rpic
    PIC_BEGIN r4, 1, $$
    CHECK_REG_COLLISION "rpic","edx:eax" ; check for collision with retval
    %define ysub r1
    FIX_STRIDES r1
    mov   r3, rsp
    and  rsp, ~(mmsize-1)
    sub  rsp, mmsize*3
    lea   r2, [r1*3]
    call hadamard_ac_8x8 ; in: r0..2,r4=$$; out: rsp[mm]=sa8d,rsp[2*mm]=satd
%if %2==16
    %define ysub r2
    lea   r0, [r0+r1*4]
    sub  rsp, mmsize*2
    call hadamard_ac_8x8
%endif
%if %1==16 && mmsize <= 16
    neg  ysub
    sub  rsp, mmsize*2
    lea   r0, [r0+ysub*4+8*SIZEOF_PIXEL]
    neg  ysub
    call hadamard_ac_8x8
%if %2==16
    lea   r0, [r0+r1*4]
    sub  rsp, mmsize*2
    call hadamard_ac_8x8 ; out: m0,rsp[mm]=sa8d,rsp[2*mm]=satd
%endif
%endif
    ; esp+0*mm +1*mm +2*mm +3*mm +4*mm +5*mm +6*mm +7*mm +8*mm
    ;    spill  sa8d  satd  sa8d  satd  sa8d  satd  sa8d  satd
    ; m0==[esp+1*mmsize] (bottommost sa8d in stack)
    HADAMARD_AC_WXH_SUM_SSE2 %1, %2 ; stack, PIC*[!HIGH_BIT_DEPTH]
    movd edx, xm0 ; sa8d?
    movd eax, xm1 ; satd?
    shr  edx, 2 - (%1*%2*16/mmsize >> 8)
    shr  eax, 1
%if ARCH_X86_64
    shl  rdx, 32
    add  rax, rdx
%endif
    mov  rsp, r3
    PIC_END
    RET
%endmacro ; HADAMARD_AC_WXH_SSE2

; instantiate satds

%if ARCH_X86_64 == 0 && HIGH_BIT_DEPTH == 0
cextern pixel_sa8d_8x8_internal_mmx2
INIT_MMX mmx2
SA8D
%endif

%define TRANS TRANS_SSE2
%define DIFFOP DIFF_UNPACK_SSE2
%define LOAD_INC_8x4W LOAD_INC_8x4W_SSE2
%define LOAD_SUMSUB_8x4P LOAD_DIFF_8x4P
%define LOAD_SUMSUB_16P  LOAD_SUMSUB_16P_SSE2
%define movdqa movaps ; doesn't hurt pre-nehalem, might as well save size
%define movdqu movups
%define punpcklqdq movlhps
INIT_XMM sse2
SA8D
SATDS_SSE2
%if ARCH_X86_64
SA8D_SATD
%endif
%if HIGH_BIT_DEPTH == 0
INTRA_SA8D_SSE2
%endif
INIT_MMX mmx2
INTRA_X3_MMX
INIT_XMM sse2
HADAMARD_AC_SSE2

%if HIGH_BIT_DEPTH == 0
INIT_XMM ssse3,atom
SATDS_SSE2
SA8D
HADAMARD_AC_SSE2
%if ARCH_X86_64
SA8D_SATD
%endif
%endif

%define DIFFOP DIFF_SUMSUB_SSSE3
%define LOAD_DUP_4x8P LOAD_DUP_4x8P_CONROE
%if HIGH_BIT_DEPTH == 0
%define LOAD_INC_8x4W LOAD_INC_8x4W_SSSE3
%define LOAD_SUMSUB_8x4P LOAD_SUMSUB_8x4P_SSSE3
%define LOAD_SUMSUB_16P  LOAD_SUMSUB_16P_SSSE3
%endif
INIT_XMM ssse3
SATDS_SSE2
SA8D
HADAMARD_AC_SSE2
%if ARCH_X86_64
SA8D_SATD
%endif
%if HIGH_BIT_DEPTH == 0
INTRA_X9
INTRA8_X9
%endif
%undef movdqa ; nehalem doesn't like movaps
%undef movdqu ; movups
%undef punpcklqdq ; or movlhps
%if HIGH_BIT_DEPTH == 0
INIT_MMX ssse3
INTRA_X3_MMX
%endif

%define TRANS TRANS_SSE4
%define LOAD_DUP_4x8P LOAD_DUP_4x8P_PENRYN
INIT_XMM sse4
SATDS_SSE2
SA8D
HADAMARD_AC_SSE2
%if ARCH_X86_64
SA8D_SATD
%endif
%if HIGH_BIT_DEPTH == 0
INTRA_X9
INTRA8_X9
%endif

; Sandy/Ivy Bridge and Bulldozer do movddup in the load unit, so
; it's effectively free.
%define LOAD_DUP_4x8P LOAD_DUP_4x8P_CONROE
INIT_XMM avx
SATDS_SSE2
SA8D
%if ARCH_X86_64
SA8D_SATD
%endif
%if HIGH_BIT_DEPTH == 0
INTRA_X9
INTRA8_X9
%endif
HADAMARD_AC_SSE2

%define TRANS TRANS_XOP
INIT_XMM xop
SATDS_SSE2
SA8D
%if ARCH_X86_64
SA8D_SATD
%endif
%if HIGH_BIT_DEPTH == 0
INTRA_X9
; no xop INTRA8_X9. it's slower than avx on bulldozer. dunno why.
%endif
HADAMARD_AC_SSE2


%if HIGH_BIT_DEPTH == 0
%define LOAD_SUMSUB_8x4P LOAD_SUMSUB8_16x4P_AVX2
%define LOAD_DUP_4x8P LOAD_DUP_4x16P_AVX2
%define TRANS TRANS_SSE4
INIT_YMM avx2
HADAMARD_AC_SSE2
%if ARCH_X86_64
SA8D_SATD
%endif

%macro LOAD_SUMSUB_8x8P_AVX2 7 ; 4*dst, 2*tmp, mul] ; r0..r5
    movq   xm%1, [r0]
    movq   xm%3, [r2]
    movq   xm%2, [r0+r1]
    movq   xm%4, [r2+r3]
    vinserti128 m%1, m%1, [r0+4*r1], 1
    vinserti128 m%3, m%3, [r2+4*r3], 1
    vinserti128 m%2, m%2, [r0+r4], 1
    vinserti128 m%4, m%4, [r2+r5], 1
    punpcklqdq m%1, m%1
    punpcklqdq m%3, m%3
    punpcklqdq m%2, m%2
    punpcklqdq m%4, m%4
    DIFF_SUMSUB_SSSE3 %1, %3, %2, %4, %7
    lea      r0, [r0+2*r1]
    lea      r2, [r2+2*r3]

    movq   xm%3, [r0]
    movq   xm%5, [r2]
    movq   xm%4, [r0+r1]
    movq   xm%6, [r2+r3]
    vinserti128 m%3, m%3, [r0+4*r1], 1
    vinserti128 m%5, m%5, [r2+4*r3], 1
    vinserti128 m%4, m%4, [r0+r4], 1
    vinserti128 m%6, m%6, [r2+r5], 1
    punpcklqdq m%3, m%3
    punpcklqdq m%5, m%5
    punpcklqdq m%4, m%4
    punpcklqdq m%6, m%6
    DIFF_SUMSUB_SSSE3 %3, %5, %4, %6, %7
%endmacro

%macro SATD_START_AVX2 2-3 0 ; r1, r3..r5, PIC
    FIX_STRIDES r1, r3
%if %3
    PIC_BEGIN r4, 0 ; r4 is reset afterwards, no need saving
    mova    %2, [pic(hmul_8p)] ; %2 is *mm reg (src is mem => dst is *mm reg)
    PIC_END
    lea     r4, [5*r1] ; r4 is reset here
    lea     r5, [5*r3]
%else
    PIC_BEGIN r4, 0
    mova    %2, [pic(hmul_16p)]
    PIC_END
    lea     r4, [3*r1]
    lea     r5, [3*r3]
%endif
    pxor    %1, %1
%endmacro

%define TRANS TRANS_SSE4
INIT_YMM avx2
cglobal pixel_satd_16x8_internal
    LOAD_SUMSUB_16x4P_AVX2 0, 1, 2, 3, 4, 5, 7, r0, r2, 1 ; r1, r3..r5
    SATD_8x4_SSE 0, 0, 1, 2, 3, 4, 5, 6 ; PIC*
    LOAD_SUMSUB_16x4P_AVX2 0, 1, 2, 3, 4, 5, 7, r0, r2, 0 ; r1, r3..r5
    SATD_8x4_SSE 0, 0, 1, 2, 3, 4, 5, 6 ; PIC*
    ret

cglobal pixel_satd_16x16, 4,6,8
    SATD_START_AVX2 m6, m7 ; r1, r3..r5, PIC
    call pixel_satd_16x8_internal
    lea  r0, [r0+4*r1]
    lea  r2, [r2+4*r3]
pixel_satd_16x8_internal:
    call pixel_satd_16x8_internal
    vextracti128 xm0, m6, 1
    paddw        xm0, xm6
    SATD_END_SSE2 xm0 ; PIC*, PIC_END*, eax, RET

cglobal pixel_satd_16x8, 4,6,8
    SATD_START_AVX2 m6, m7 ; r1, r3..r5, PIC
    jmp pixel_satd_16x8_internal

cglobal pixel_satd_8x8_internal
    LOAD_SUMSUB_8x8P_AVX2 0, 1, 2, 3, 4, 5, 7 ; r0..r5
    SATD_8x4_SSE 0, 0, 1, 2, 3, 4, 5, 6 ; PIC*
    ret

cglobal pixel_satd_8x16, 4,6,8
    SATD_START_AVX2 m6, m7, 1 ; r1, r3..r5, PIC
    call pixel_satd_8x8_internal
    lea  r0, [r0+2*r1]
    lea  r2, [r2+2*r3]
    lea  r0, [r0+4*r1]
    lea  r2, [r2+4*r3]
    call pixel_satd_8x8_internal
    vextracti128 xm0, m6, 1
    paddw        xm0, xm6
    SATD_END_SSE2 xm0 ; PIC*, PIC_END*, eax, RET

cglobal pixel_satd_8x8, 4,6,8
    SATD_START_AVX2 m6, m7, 1 ; r1, r3..r5, PIC
    call pixel_satd_8x8_internal
    vextracti128 xm0, m6, 1
    paddw        xm0, xm6
    SATD_END_SSE2 xm0 ; PIC*, PIC_END*, eax, RET

cglobal pixel_sa8d_8x8_internal
    LOAD_SUMSUB_8x8P_AVX2 0, 1, 2, 3, 4, 5, 7 ; r0..r5
    HADAMARD4_V 0, 1, 2, 3, 4
    HADAMARD 8, sumsub, 0, 1, 4, 5
    HADAMARD 8, sumsub, 2, 3, 4, 5
    HADAMARD 2, sumsub, 0, 1, 4, 5 ; PIC*
    HADAMARD 2, sumsub, 2, 3, 4, 5 ; PIC*
    HADAMARD 1, amax, 0, 1, 4, 5 ; PIC*
    HADAMARD 1, amax, 2, 3, 4, 5 ; PIC*
    paddw  m6, m0
    paddw  m6, m2
    ret

cglobal pixel_sa8d_8x8, 4,6,8
    SATD_START_AVX2 m6, m7, 1 ; r1, r3..r5, PIC
    call pixel_sa8d_8x8_internal
    vextracti128 xm1, m6, 1
    paddw xm6, xm1
    DESIGNATE_RPIC rax ; designate rax for no-save PIC as it's retval'ed later
    HADDW xm6, xm1 ; PIC*
    movd  eax, xm6
    add   eax, 1
    shr   eax, 1
    RET

cglobal intra_sad_x9_8x8, 5,6,8
    ; pred(0,0)..pred(8,1) -> [rsp]..[rsp+0x220]
    %define pred(i,j) [rsp+i*0x40+j*0x20]

    PUSH        r6
    mov         r6, rsp ; rsp0 -> tmp
    sub        rsp, (0x240+gprsize) ; alloc pred_area+rsp0m
    and        rsp, ~31 ; align 32
    mov [rsp+0x240], r6 ; tmp -> [rsp+0x240] (rsp0m)

    PIC_BEGIN r6, 0

    movu        m5, [r0+0*FENC_STRIDE]
    movu        m6, [r0+4*FENC_STRIDE]
    punpcklqdq  m5, [r0+2*FENC_STRIDE]
    punpcklqdq  m6, [r0+6*FENC_STRIDE]

    ; save instruction size: avoid 4-byte memory offsets
    PIC_BEGIN r0, 0 ; use r0 as PIC base to set r0 (don't save/restore r0)
    lea         r0, [pic(intra8x9_h1)+128]
    PIC_END
    %define off(m) (r0+m-(intra8x9_h1+128))
    ; r0 is used in off(m) macro in the same way as rpic in pic(m), but
    ; lpic==(intra8x9_h1+128) is .rodata-based and pic(m) would work only when
    ; `m' is in local .rodata; with external .rodata or any non-.rodata
    ; addresses it will generate "error: invalid effective address: impossible
    ; segment base multiplier"

    vpbroadcastq m0, [r2+16]
    psadbw      m4, m0, m5
    psadbw      m2, m0, m6
    mova pred(0,0), m0 ; pred(0,0): [rsp]
    mova pred(0,1), m0 ; pred(0,1): [rsp+0x20]
    paddw       m4, m2

    vpbroadcastq m1, [r2+7]
    pshufb      m3, m1, [off(intra8x9_h1)]
    pshufb      m2, m1, [off(intra8x9_h3)]
    mova pred(1,0), m3 ; [rsp+0x40]
    mova pred(1,1), m2 ; [rsp+0x60]
    psadbw      m3, m5
    psadbw      m2, m6
    paddw       m3, m2

    lea         r5, [rsp+0x100]
    %define pred(i,j) [r5-0x100+i*0x40+j*0x20]

    ; combine the first two
    pslldq      m3, 2
    por         m4, m3

    pxor        m2, m2
    psadbw      m0, m2
    psadbw      m1, m2
    paddw       m0, m1
    psrlw       m0, 3
    pavgw       m0, m2
    pshufb      m0, m2
    mova pred(2,0), m0 ; [rsp+0x00000080] / [r5-0x80]
    mova pred(2,1), m0 ; [rsp+0x000000a0] / [r5-0x60]
    psadbw      m3, m0, m5
    psadbw      m2, m0, m6
    paddw       m3, m2

    pslldq      m3, 4
    por         m4, m3

    vbroadcasti128 m0, [r2+16]
    vbroadcasti128 m2, [r2+17]
    pslldq      m1, m0, 1
    pavgb       m3, m0, m2
    PRED4x4_LOWPASS m0, m1, m2, m0, m7 ; PIC
    pshufb      m1, m0, [off(intra8x9_ddl1)]
    pshufb      m2, m0, [off(intra8x9_ddl3)]
    mova pred(3,0), m1 ; [rsp+0x000000c0] / [r5-0x40]
    mova pred(3,1), m2 ; [rsp+0x000000e0] / [r5-0x20]
    psadbw      m1, m5
    psadbw      m2, m6
    paddw       m1, m2

    pslldq      m1, 6
    por         m4, m1
    vextracti128 xm1, m4, 1
    paddw      xm4, xm1
    mova      [r4], xm4

    ; for later
    vinserti128 m7, m3, xm0, 1

    vbroadcasti128 m2, [r2+8]
    vbroadcasti128 m0, [r2+7]
    vbroadcasti128 m1, [r2+6]
    pavgb       m3, m2, m0
    PRED4x4_LOWPASS m0, m1, m2, m0, m4 ; PIC
    pshufb      m1, m0, [off(intra8x9_ddr1)]
    pshufb      m2, m0, [off(intra8x9_ddr3)]
    mova pred(4,0), m1 ; [rsp+0x00000100] / [r5]
    mova pred(4,1), m2 ; [rsp+0x00000120] / [r5+0x20]
    psadbw      m4, m1, m5
    psadbw      m2, m6
    paddw       m4, m2

    add         r0, 256 ; r0 now points to (intra8x9_h1+256+128)
    %define off(m) (r0+m-(intra8x9_h1+256+128))
    add         r5, 0xc0 ; r5 == (rsp+0x100) + 0xc0 == rsp+0x1c0
    %define pred(i,j) [r5-0x1c0+i*0x40+j*0x20]

    vpblendd    m2, m3, m0, 11110011b
    pshufb      m1, m2, [off(intra8x9_vr1)]
    pshufb      m2, m2, [off(intra8x9_vr3)]
    mova pred(5,0), m1 ; [rsp+0x00000140] / [r5-0x80]
    mova pred(5,1), m2 ; [rsp+0x00000160] / [r5-0x60]
    psadbw      m1, m5
    psadbw      m2, m6
    paddw       m1, m2

    pslldq      m1, 2
    por         m4, m1

    psrldq      m2, m3, 4
    pblendw     m2, m0, q3330
    punpcklbw   m0, m3
    pshufb      m1, m2, [off(intra8x9_hd1)]
    pshufb      m2, m0, [off(intra8x9_hd3)]
    mova pred(6,0), m1 ; [rsp+0x00000180] / [r5-0x40]
    mova pred(6,1), m2 ; [rsp+0x000001a0] / [r5-0x20]
    psadbw      m1, m5
    psadbw      m2, m6
    paddw       m1, m2

    pslldq      m1, 4
    por         m4, m1

    pshufb      m1, m7, [off(intra8x9_vl1)]
    pshufb      m2, m7, [off(intra8x9_vl3)]
    mova pred(7,0), m1 ; [rsp+0x000001c0] / [r5]
    mova pred(7,1), m2 ; [rsp+0x000001e0] / [r5+0x20]
    psadbw      m1, m5
    psadbw      m2, m6
    paddw       m1, m2

    pslldq      m1, 6
    por         m4, m1
    vextracti128 xm1, m4, 1
    paddw      xm4, xm1
    mova       xm3, [r4]
    SBUTTERFLY qdq, 3, 4, 7
    paddw      xm3, xm4

    pslldq      m1, m0, 1
    vpbroadcastd m0, [r2+7]
    palignr     m0, m1, 1
    pshufb      m1, m0, [off(intra8x9_hu1)]
    pshufb      m2, m0, [off(intra8x9_hu3)]
    mova pred(8,0), m1 ; [rsp+0x00000200] / [r5+0x40]
    mova pred(8,1), m2 ; [rsp+0x00000220] / [r5+0x60]
    psadbw      m1, m5
    psadbw      m2, m6
    paddw       m1, m2
    vextracti128 xm2, m1, 1
    paddw      xm1, xm2
    MOVHL      xm2, xm1
    paddw      xm1, xm2
    movd       r2d, xm1

    paddw      xm3, [r3]
    mova      [r4], xm3
    add        r2w, word [r3+16]
    mov    [r4+16], r2w

    phminposuw xm3, xm3
    movd       r3d, xm3
    add        r2d, 8<<16
    cmp        r3w, r2w
    cmovg      r3d, r2d

    mov        r2d, r3d
    shr         r3, 16
    shl         r3, 6
    add         r1, 4*FDEC_STRIDE
    mova       xm0, [rsp+r3+0x00]
    mova       xm1, [rsp+r3+0x10]
    mova       xm2, [rsp+r3+0x20]
    mova       xm3, [rsp+r3+0x30]
    movq   [r1+FDEC_STRIDE*-4], xm0
    movhps [r1+FDEC_STRIDE*-2], xm0
    movq   [r1+FDEC_STRIDE*-3], xm1
    movhps [r1+FDEC_STRIDE*-1], xm1
    movq   [r1+FDEC_STRIDE* 0], xm2
    movhps [r1+FDEC_STRIDE* 2], xm2
    movq   [r1+FDEC_STRIDE* 1], xm3
    movhps [r1+FDEC_STRIDE* 3], xm3
    PIC_END
    mov        rsp, [rsp+0x240]
    POP         r6
    mov        eax, r2d
    RET

%macro SATD_AVX512_LOAD4 2 ; size, opmask ; r0..r3
    vpbroadcast%1 m0, [r0]
    vpbroadcast%1 m0 {%2}, [r0+2*r1]
    vpbroadcast%1 m2, [r2]
    vpbroadcast%1 m2 {%2}, [r2+2*r3]
    add           r0, r1
    add           r2, r3
    vpbroadcast%1 m1, [r0]
    vpbroadcast%1 m1 {%2}, [r0+2*r1]
    vpbroadcast%1 m3, [r2]
    vpbroadcast%1 m3 {%2}, [r2+2*r3]
%endmacro

%macro SATD_AVX512_LOAD8 5 ; size, halfreg, opmask1, opmask2, opmask3 ; r0..r5
    vpbroadcast%1 %{2}0, [r0]
    vpbroadcast%1 %{2}0 {%3}, [r0+2*r1]
    vpbroadcast%1 %{2}2, [r2]
    vpbroadcast%1 %{2}2 {%3}, [r2+2*r3]
    vpbroadcast%1    m0 {%4}, [r0+4*r1]
    vpbroadcast%1    m2 {%4}, [r2+4*r3]
    vpbroadcast%1    m0 {%5}, [r0+2*r4]
    vpbroadcast%1    m2 {%5}, [r2+2*r5]
    vpbroadcast%1 %{2}1, [r0+r1]
    vpbroadcast%1 %{2}1 {%3}, [r0+r4]
    vpbroadcast%1 %{2}3, [r2+r3]
    vpbroadcast%1 %{2}3 {%3}, [r2+r5]
    lea              r0, [r0+4*r1]
    lea              r2, [r2+4*r3]
    vpbroadcast%1    m1 {%4}, [r0+r1]
    vpbroadcast%1    m3 {%4}, [r2+r3]
    vpbroadcast%1    m1 {%5}, [r0+r4]
    vpbroadcast%1    m3 {%5}, [r2+r5]
%endmacro

%macro SATD_AVX512_PACKED 0
    DIFF_SUMSUB_SSSE3 0, 2, 1, 3, 4
    SUMSUB_BA      w, 0, 1, 2
    SBUTTERFLY   qdq, 0, 1, 2
    SUMSUB_BA      w, 0, 1, 2
    HMAXABSW2         0, 1, 2, 3
%endmacro

%macro SATD_AVX512_END 0-1 0 ; sa8d ; rax/eax, rdx/edx, RET
    vpaddw         m0 {k1}{z}, m1 ; zero-extend to dwords
%if ARCH_X86_64
%if mmsize == 64
    vextracti32x8 ym1, m0, 1
    paddd         ym0, ym1
%endif
%if mmsize >= 32
    vextracti128  xm1, ym0, 1
    paddd        xmm0, xm0, xm1
%endif
    punpckhqdq   xmm1, xmm0, xmm0
    paddd        xmm0, xmm1
    movq          rax, xmm0
    rorx          rdx, rax, 32
%if %1
    lea           eax, [rax+rdx+1]
    shr           eax, 1
%else
    add           eax, edx
%endif
%else ; ARCH
    HADDD          m0, m1
    movd          eax, xm0
%if %1
    inc           eax
    shr           eax, 1
%endif
%endif ; ARCH
    RET
%endmacro

%macro HMAXABSW2 4 ; a, b, tmp1, tmp2
    pabsw     m%1, m%1
    pabsw     m%2, m%2
    psrldq    m%3, m%1, 2
    psrld     m%4, m%2, 16
    pmaxsw    m%1, m%3
    pmaxsw    m%2, m%4
%endmacro

INIT_ZMM avx512
cglobal pixel_satd_16x8_internal
    PIC_BEGIN r4, 0
    vbroadcasti64x4 m6, [pic(hmul_16p)]
    PIC_END
    kxnorb           k2, k2, k2
    mov             r4d, 0x55555555
    knotw            k2, k2
    kmovd            k1, r4d
    lea              r4, [3*r1]
    lea              r5, [3*r3]
satd_16x8_avx512:
    vbroadcasti128  ym0,      [r0]
    vbroadcasti32x4  m0 {k2}, [r0+4*r1] ; 0 0 4 4
    vbroadcasti128  ym4,      [r2]
    vbroadcasti32x4  m4 {k2}, [r2+4*r3]
    vbroadcasti128  ym2,      [r0+2*r1]
    vbroadcasti32x4  m2 {k2}, [r0+2*r4] ; 2 2 6 6
    vbroadcasti128  ym5,      [r2+2*r3]
    vbroadcasti32x4  m5 {k2}, [r2+2*r5]
    DIFF_SUMSUB_SSSE3 0, 4, 2, 5, 6
    vbroadcasti128  ym1,      [r0+r1]
    vbroadcasti128  ym4,      [r2+r3]
    vbroadcasti128  ym3,      [r0+r4]
    vbroadcasti128  ym5,      [r2+r5]
    lea              r0, [r0+4*r1]
    lea              r2, [r2+4*r3]
    vbroadcasti32x4  m1 {k2}, [r0+r1] ; 1 1 5 5
    vbroadcasti32x4  m4 {k2}, [r2+r3]
    vbroadcasti32x4  m3 {k2}, [r0+r4] ; 3 3 7 7
    vbroadcasti32x4  m5 {k2}, [r2+r5]
    DIFF_SUMSUB_SSSE3 1, 4, 3, 5, 6
    HADAMARD4_V       0, 1, 2, 3, 4
    HMAXABSW2         0, 2, 4, 5
    HMAXABSW2         1, 3, 4, 5
    paddw            m4, m0, m2 ; m1
    paddw            m2, m1, m3 ; m0
    ret

cglobal pixel_satd_8x8_internal
    PIC_BEGIN r4, 0
    vbroadcasti64x4 m4, [pic(hmul_16p)]
    PIC_END
    mov     r4d, 0x55555555
    kmovd    k1, r4d   ; 01010101
    kshiftlb k2, k1, 5 ; 10100000
    kshiftlb k3, k1, 4 ; 01010000
    lea      r4, [3*r1]
    lea      r5, [3*r3]
satd_8x8_avx512:
    SATD_AVX512_LOAD8 q, ym, k1, k2, k3 ; 2 0 2 0 6 4 6 4 ; r0..r5
    SATD_AVX512_PACKED                  ; 3 1 3 1 7 5 7 5
    ret

cglobal pixel_satd_16x8, 4,6
    call pixel_satd_16x8_internal_avx512
    jmp satd_zmm_avx512_end

cglobal pixel_satd_16x16, 4,6
    call pixel_satd_16x8_internal_avx512
    lea      r0, [r0+4*r1]
    lea      r2, [r2+4*r3]
    paddw    m7, m0, m1
    call satd_16x8_avx512
    paddw    m1, m7
    jmp satd_zmm_avx512_end

cglobal pixel_satd_8x8, 4,6
    call pixel_satd_8x8_internal_avx512
satd_zmm_avx512_end:
    SATD_AVX512_END ; rax/eax, rdx/edx, RET

cglobal pixel_satd_8x16, 4,6
    call pixel_satd_8x8_internal_avx512
    lea      r0, [r0+4*r1]
    lea      r2, [r2+4*r3]
    paddw    m5, m0, m1
    call satd_8x8_avx512
    paddw    m1, m5
    jmp satd_zmm_avx512_end

INIT_YMM avx512
cglobal pixel_satd_4x8_internal
    PIC_BEGIN r4, 0
    vbroadcasti128 m4, [pic(hmul_4p)]
    PIC_END
    mov     r4d, 0x55550c
    kmovd    k2, r4d   ; 00001100
    kshiftlb k3, k2, 2 ; 00110000
    kshiftlb k4, k2, 4 ; 11000000
    kshiftrd k1, k2, 8 ; 01010101
    lea      r4, [3*r1]
    lea      r5, [3*r3]
satd_4x8_avx512:
    SATD_AVX512_LOAD8 d, xm, k2, k3, k4 ; 0 0 2 2 4 4 6 6 ; r0..r5
satd_ymm_avx512:                        ; 1 1 3 3 5 5 7 7
    SATD_AVX512_PACKED
    ret

cglobal pixel_satd_8x4, 4,5
    PIC_BEGIN r4, 0
    mova     m4, [pic(hmul_16p)]
    PIC_END
    mov     r4d, 0x5555
    kmovw    k1, r4d
    SATD_AVX512_LOAD4 q, k1 ; 2 0 2 0 ; r0..r3
    call satd_ymm_avx512    ; 3 1 3 1
    jmp satd_ymm_avx512_end2

cglobal pixel_satd_4x8, 4,6
    call pixel_satd_4x8_internal_avx512
satd_ymm_avx512_end:
%if ARCH_X86_64 == 0
    pop     r5d
    %assign regs_used 5
%endif
satd_ymm_avx512_end2:
    SATD_AVX512_END ; rax/eax, rdx/edx, RET

cglobal pixel_satd_4x16, 4,6
    call pixel_satd_4x8_internal_avx512
    lea      r0, [r0+4*r1]
    lea      r2, [r2+4*r3]
    paddw    m5, m0, m1
    call satd_4x8_avx512
    paddw    m1, m5
    jmp satd_ymm_avx512_end

INIT_XMM avx512
cglobal pixel_satd_4x4, 4,5
    PIC_BEGIN r4, 0
    mova     m4, [pic(hmul_4p)]
    PIC_END
    mov     r4d, 0x550c
    kmovw    k2, r4d
    kshiftrw k1, k2, 8
    SATD_AVX512_LOAD4 d, k2 ; 0 0 2 2 ; r0..r3
    SATD_AVX512_PACKED      ; 1 1 3 3
    SWAP      0, 1
    SATD_AVX512_END ; rax/eax, rdx/edx, RET

INIT_ZMM avx512
cglobal pixel_sa8d_8x8, 4,6
    PIC_BEGIN r4, 0
    vbroadcasti64x4 m4, [pic(hmul_16p)]
    PIC_END
    mov     r4d, 0x55555555
    kmovd    k1, r4d   ; 01010101
    kshiftlb k2, k1, 5 ; 10100000
    kshiftlb k3, k1, 4 ; 01010000
    lea      r4, [3*r1]
    lea      r5, [3*r3]
    SATD_AVX512_LOAD8 q, ym, k1, k2, k3 ; 2 0 2 0 6 4 6 4 ; r0..r5
    DIFF_SUMSUB_SSSE3 0, 2, 1, 3, 4     ; 3 1 3 1 7 5 7 5
    SUMSUB_BA      w, 0, 1, 2
    SBUTTERFLY   qdq, 0, 1, 2
    SUMSUB_BA      w, 0, 1, 2
    shufps        m2, m0, m1, q2020
    shufps        m1, m0, m1, q3131
    SUMSUB_BA      w, 2, 1, 0
    vshufi32x4    m0, m2, m1, q1010
    vshufi32x4    m1, m2, m1, q3232
    SUMSUB_BA      w, 0, 1, 2
    HMAXABSW2      0, 1, 2, 3
    SATD_AVX512_END 1 ; rax/eax, rdx/edx, RET

%endif ; HIGH_BIT_DEPTH

;=============================================================================
; SSIM
;=============================================================================

;-----------------------------------------------------------------------------
; void pixel_ssim_4x4x2_core( const uint8_t *pix1, intptr_t stride1,
;                             const uint8_t *pix2, intptr_t stride2, int sums[2][4] )
;-----------------------------------------------------------------------------
%macro SSIM_ITER 1 ; r0..r3
%if HIGH_BIT_DEPTH
    movu      m4, [r0+(%1&1)*r1]
    movu      m5, [r2+(%1&1)*r3]
%elif cpuflag(avx)
    pmovzxbw  m4, [r0+(%1&1)*r1]
    pmovzxbw  m5, [r2+(%1&1)*r3]
%else
    movq      m4, [r0+(%1&1)*r1]
    movq      m5, [r2+(%1&1)*r3]
    punpcklbw m4, m7
    punpcklbw m5, m7
%endif
%if %1==1
    lea       r0, [r0+r1*2]
    lea       r2, [r2+r3*2]
%endif
%if %1 == 0 && cpuflag(avx)
    SWAP       0, 4
    SWAP       1, 5
    pmaddwd   m4, m0, m0
    pmaddwd   m5, m1, m1
    pmaddwd   m6, m0, m1
%else
%if %1 == 0
    mova      m0, m4
    mova      m1, m5
%else
    paddw     m0, m4
    paddw     m1, m5
%endif
    pmaddwd   m6, m4, m5
    pmaddwd   m4, m4
    pmaddwd   m5, m5
%endif
    ACCUM  paddd, 2, 4, %1
    ACCUM  paddd, 3, 6, %1
    paddd     m2, m5
%endmacro

%macro SSIM 0
%if HIGH_BIT_DEPTH
cglobal pixel_ssim_4x4x2_core, 4,4,7
    FIX_STRIDES r1, r3
%else
cglobal pixel_ssim_4x4x2_core, 4,4,7+notcpuflag(avx)
%if notcpuflag(avx)
    pxor      m7, m7
%endif
%endif
    SSIM_ITER 0 ; r0..r3
    SSIM_ITER 1
    SSIM_ITER 2
    SSIM_ITER 3
%if UNIX64
    DECLARE_REG_TMP 4
%else
    DECLARE_REG_TMP 0
    mov       t0, r4mp
%endif
%if cpuflag(ssse3)
    phaddw    m0, m1
    PIC_BEGIN r3, 0 ; r1..r3 not used anymore in this function
    CHECK_REG_COLLISION "rpic","t0"
    pmaddwd   m0, [pic(pw_1)]
    PIC_END
    phaddd    m2, m3
%else
    PIC_BEGIN r3, 0
    CHECK_REG_COLLISION "rpic","t0"
    mova      m4, [pic(pw_1)]
    PIC_END
    pmaddwd   m0, m4
    pmaddwd   m1, m4
    packssdw  m0, m1
    shufps    m1, m2, m3, q2020
    shufps    m2, m3, q3131
    pmaddwd   m0, m4
    paddd     m2, m1
%endif
    shufps    m1, m0, m2, q2020
    shufps    m0, m2, q3131
    mova    [t0], m1
    mova [t0+16], m0
    RET

;-----------------------------------------------------------------------------
; float pixel_ssim_end( int sum0[5][4], int sum1[5][4], int width )
;-----------------------------------------------------------------------------
cglobal pixel_ssim_end4, 2,3
    mov      r2d, r2m
    mova      m0, [r0+ 0]
    mova      m1, [r0+16]
    mova      m2, [r0+32]
    mova      m3, [r0+48]
    mova      m4, [r0+64]
    paddd     m0, [r1+ 0]
    paddd     m1, [r1+16]
    paddd     m2, [r1+32]
    paddd     m3, [r1+48]
    paddd     m4, [r1+64]
    paddd     m0, m1
    paddd     m1, m2
    paddd     m2, m3
    paddd     m3, m4
    TRANSPOSE4x4D  0, 1, 2, 3, 4 ; m0..4

    PIC_BEGIN r1, 0 ; r0,1 aren't used anymore, don't save

;   s1=m0, s2=m1, ss=m2, s12=m3
%if BIT_DEPTH == 10
    cvtdq2ps  m0, m0
    cvtdq2ps  m1, m1
    cvtdq2ps  m2, m2
    cvtdq2ps  m3, m3
    mulps     m4, m0, m1  ; s1*s2
    mulps     m0, m0      ; s1*s1
    mulps     m1, m1      ; s2*s2
    PIC_BEGIN
    mulps     m2, [pic(pf_64)] ; ss*64
    mulps     m3, [pic(pf_128)] ; s12*128
    addps     m4, m4      ; s1*s2*2
    addps     m0, m1      ; s1*s1 + s2*s2
    subps     m2, m0      ; vars
    subps     m3, m4      ; covar*2
    movaps    m1, [pic(ssim_c1)]
    addps     m4, m1      ; s1*s2*2 + ssim_c1
    addps     m0, m1      ; s1*s1 + s2*s2 + ssim_c1
    movaps    m1, [pic(ssim_c2)]
    PIC_END
    addps     m2, m1      ; vars + ssim_c2
    addps     m3, m1      ; covar*2 + ssim_c2
%else
    pmaddwd   m4, m1, m0  ; s1*s2
    pslld     m1, 16
    por       m0, m1
    pmaddwd   m0, m0  ; s1*s1 + s2*s2
    pslld     m4, 1
    pslld     m3, 7
    pslld     m2, 6
    psubd     m3, m4  ; covar*2
    psubd     m2, m0  ; vars
    PIC_BEGIN
    mova      m1, [pic(ssim_c1)]
    paddd     m0, m1
    paddd     m4, m1
    mova      m1, [pic(ssim_c2)]
    PIC_END
    paddd     m3, m1
    paddd     m2, m1
    cvtdq2ps  m0, m0  ; (float)(s1*s1 + s2*s2 + ssim_c1)
    cvtdq2ps  m4, m4  ; (float)(s1*s2*2 + ssim_c1)
    cvtdq2ps  m3, m3  ; (float)(covar*2 + ssim_c2)
    cvtdq2ps  m2, m2  ; (float)(vars + ssim_c2)
%endif
    mulps     m4, m3
    mulps     m0, m2
    divps     m4, m0  ; ssim

    cmp       r2d, 4
    je .skip ; faster only if this is the common case; remove branch if we use ssim on a macroblock level
    neg       r2

%if ARCH_X86_64
    lea       r3, [mask_ff + 16]
    %xdefine %%mask r3
%else
    %define %%mask pic(mask_ff) + 16
%endif
%if cpuflag(avx)
    PIC_BEGIN
    andps     m4, [%%mask + r2*4]
    PIC_END
%else
    PIC_BEGIN
    movups    m0, [%%mask + r2*4]
    PIC_END
    andps     m4, m0
%endif

.skip:
    PIC_END
    movhlps   m0, m4
    addps     m0, m4
%if cpuflag(ssse3)
    movshdup  m4, m0
%else
    pshuflw   m4, m0, q0032
%endif
    addss     m0, m4
%if ARCH_X86_64 == 0
    movss    r0m, m0  ; r0m gets destroyed
    fld     dword r0m ; to push xmm0 to st(0)
%endif
    RET
%endmacro ; SSIM

INIT_XMM sse2
SSIM
INIT_XMM avx
SSIM

;-----------------------------------------------------------------------------
; int pixel_asd8( pixel *pix1, intptr_t stride1, pixel *pix2, intptr_t stride2, int height );
;-----------------------------------------------------------------------------
%macro ASD8 0
cglobal pixel_asd8, 5,5
    pxor     m0, m0
    pxor     m1, m1
.loop:
%if HIGH_BIT_DEPTH
    paddw    m0, [r0]
    paddw    m1, [r2]
    paddw    m0, [r0+2*r1]
    paddw    m1, [r2+2*r3]
    lea      r0, [r0+4*r1]
    paddw    m0, [r0]
    paddw    m1, [r2+4*r3]
    lea      r2, [r2+4*r3]
    paddw    m0, [r0+2*r1]
    paddw    m1, [r2+2*r3]
    lea      r0, [r0+4*r1]
    lea      r2, [r2+4*r3]
%else
    movq     m2, [r0]
    movq     m3, [r2]
    movhps   m2, [r0+r1]
    movhps   m3, [r2+r3]
    lea      r0, [r0+2*r1]
    psadbw   m2, m1
    psadbw   m3, m1
    movq     m4, [r0]
    movq     m5, [r2+2*r3]
    lea      r2, [r2+2*r3]
    movhps   m4, [r0+r1]
    movhps   m5, [r2+r3]
    lea      r0, [r0+2*r1]
    paddw    m0, m2
    psubw    m0, m3
    psadbw   m4, m1
    psadbw   m5, m1
    lea      r2, [r2+2*r3]
    paddw    m0, m4
    psubw    m0, m5
%endif
    sub     r4d, 4
    jg .loop
%if HIGH_BIT_DEPTH
    psubw    m0, m1
    DESIGNATE_RPIC rax ; designate rax for no-save PIC as it's retval'ed later
    HADDW    m0, m1 ; PIC*
    DESIGNATE_RPIC     ; clear designation
    ABSD     m1, m0
%else
    MOVHL    m1, m0
    paddw    m0, m1
    ABSW     m1, m0
%endif
    movd    eax, m1
    RET
%endmacro

INIT_XMM sse2
ASD8
INIT_XMM ssse3
ASD8
%if HIGH_BIT_DEPTH
INIT_XMM xop
ASD8
%endif

;=============================================================================
; Successive Elimination ADS
;=============================================================================

%macro ADS_START 0 ; r0d, r4, r5/r5d/r5m, r6
%if UNIX64
    movsxd  r5, r5d
%else
    mov    r5d, r5m
%endif
    mov    r0d, r5d
    lea     r6, [r4+r5+(mmsize-1)]
    and     r6, ~(mmsize-1)
    shl     r2d,  1
%endmacro

%macro ADS_END 1-2 .loop ; unroll_size, loop_label ; r0d, r1, r3..r5, r6, jmp .loop/adv_mvs_
    add     r1, 2*%1
    add     r3, 2*%1
    add     r6, %1
    sub    r0d, %1
    jg %2
    WIN64_RESTORE_XMM_INTERNAL
%if mmsize==32
    vzeroupper
%endif
    lea     r6, [r4+r5+(mmsize-1)]
    and     r6, ~(mmsize-1)
%if cpuflag(ssse3)
    jmp ads_mvs_ssse3 ; RET 0,7,0
%else
    jmp ads_mvs_mmx ; RET 0,7,0
%endif
%endmacro

;-----------------------------------------------------------------------------
; int pixel_ads4( int enc_dc[4], uint16_t *sums, int delta,
;                 uint16_t *cost_mvx, int16_t *mvs, int width, int thresh )
;-----------------------------------------------------------------------------
%if HIGH_BIT_DEPTH

%macro ADS_XMM 0
%if ARCH_X86_64
cglobal pixel_ads4, 5,7,9
%else
cglobal pixel_ads4, 5,7,8
%endif
%if mmsize >= 32
    vpbroadcastd m7, [r0+ 0]
    vpbroadcastd m6, [r0+ 4]
    vpbroadcastd m5, [r0+ 8]
    vpbroadcastd m4, [r0+12]
%else
    mova      m4, [r0]
    pshufd    m7, m4, 0
    pshufd    m6, m4, q1111
    pshufd    m5, m4, q2222
    pshufd    m4, m4, q3333
%endif
%if ARCH_X86_64
    SPLATD    m8, r6m
%endif
    ADS_START ; r0d, r4, r5/r5d/r5m, r6
.loop:
%if cpuflag(avx)
    pmovzxwd  m0, [r1]
    pmovzxwd  m1, [r1+16]
%else
    movh      m0, [r1]
    movh      m1, [r1+16]
    pxor      m3, m3
    punpcklwd m0, m3
    punpcklwd m1, m3
%endif
    psubd     m0, m7
    psubd     m1, m6
    ABSD      m0, m0, m2
    ABSD      m1, m1, m3
%if cpuflag(avx)
    pmovzxwd  m2, [r1+r2]
    pmovzxwd  m3, [r1+r2+16]
    paddd     m0, m1
%else
    movh      m2, [r1+r2]
    movh      m3, [r1+r2+16]
    paddd     m0, m1
    pxor      m1, m1
    punpcklwd m2, m1
    punpcklwd m3, m1
%endif
    psubd     m2, m5
    psubd     m3, m4
    ABSD      m2, m2, m1
    ABSD      m3, m3, m1
    paddd     m0, m2
    paddd     m0, m3
%if cpuflag(avx)
    pmovzxwd  m1, [r3]
%else
    movh      m1, [r3]
    pxor      m3, m3
    punpcklwd m1, m3
%endif
    paddd     m0, m1
%if ARCH_X86_64
    psubd     m1, m8, m0
%else
    SPLATD    m1, r6m
    psubd     m1, m0
%endif
    packssdw  m1, m1
%if mmsize == 32
    vpermq    m1, m1, q3120
    packuswb  m1, m1
    movq    [r6], xm1
%else
    packuswb  m1, m1
    movd    [r6], m1
%endif
    ADS_END mmsize/4 ; r0d, r1, r3..r5, r6, jmp .loop/adv_mvs_

cglobal pixel_ads2, 5,7,8
%if mmsize >= 32
    vpbroadcastd m7, [r0+0]
    vpbroadcastd m6, [r0+4]
    vpbroadcastd m5, r6m
%else
    movq      m6, [r0]
    movd      m5, r6m
    pshufd    m7, m6, 0
    pshufd    m6, m6, q1111
    pshufd    m5, m5, 0
%endif
    pxor      m4, m4
    ADS_START ; r0d, r4, r5/r5d/r5m, r6
.loop:
%if cpuflag(avx)
    pmovzxwd  m0, [r1]
    pmovzxwd  m1, [r1+r2]
    pmovzxwd  m2, [r3]
%else
    movh      m0, [r1]
    movh      m1, [r1+r2]
    movh      m2, [r3]
    punpcklwd m0, m4
    punpcklwd m1, m4
    punpcklwd m2, m4
%endif
    psubd     m0, m7
    psubd     m1, m6
    ABSD      m0, m0, m3
    ABSD      m1, m1, m3
    paddd     m0, m1
    paddd     m0, m2
    psubd     m1, m5, m0
    packssdw  m1, m1
%if mmsize == 32
    vpermq    m1, m1, q3120
    packuswb  m1, m1
    movq    [r6], xm1
%else
    packuswb  m1, m1
    movd    [r6], m1
%endif
    ADS_END mmsize/4 ; r0d, r1, r3..r5, r6, jmp .loop/adv_mvs_

cglobal pixel_ads1, 5,7,8
%if mmsize >= 32
    vpbroadcastd m7, [r0]
    vpbroadcastd m6, r6m
%else
    movd      m7, [r0]
    movd      m6, r6m
    pshufd    m7, m7, 0
    pshufd    m6, m6, 0
%endif
    pxor      m5, m5
    ADS_START ; r0d, r4, r5/r5d/r5m, r6
.loop:
    movu      m1, [r1]
    movu      m3, [r3]
    punpcklwd m0, m1, m5
    punpckhwd m1, m5
    punpcklwd m2, m3, m5
    punpckhwd m3, m5
    psubd     m0, m7
    psubd     m1, m7
    ABSD      m0, m0, m4
    ABSD      m1, m1, m4
    paddd     m0, m2
    paddd     m1, m3
    psubd     m2, m6, m0
    psubd     m3, m6, m1
    packssdw  m2, m3
    packuswb  m2, m2
%if mmsize == 32
    vpermq    m2, m2, q3120
    mova    [r6], xm2
%else
    movq    [r6], m2
%endif
    ADS_END mmsize/2 ; r0d, r1, r3..r5, r6, jmp .loop/adv_mvs_
%endmacro

INIT_XMM sse2
ADS_XMM
INIT_XMM ssse3
ADS_XMM
INIT_XMM avx
ADS_XMM
INIT_YMM avx2
ADS_XMM

%else ; !HIGH_BIT_DEPTH

%macro ADS_XMM 0
%if ARCH_X86_64 && mmsize == 16
cglobal pixel_ads4, 5,7,12
%elif ARCH_X86_64 && mmsize != 8
cglobal pixel_ads4, 5,7,9
%else
cglobal pixel_ads4, 5,7,8
%endif
    test dword r6m, 0xffff0000
%if mmsize >= 32
    vpbroadcastw m7, [r0+ 0]
    vpbroadcastw m6, [r0+ 4]
    vpbroadcastw m5, [r0+ 8]
    vpbroadcastw m4, [r0+12]
%elif mmsize == 16
    mova       m4, [r0]
    pshuflw    m7, m4, 0
    pshuflw    m6, m4, q2222
    pshufhw    m5, m4, 0
    pshufhw    m4, m4, q2222
    punpcklqdq m7, m7
    punpcklqdq m6, m6
    punpckhqdq m5, m5
    punpckhqdq m4, m4
%else
    mova      m6, [r0]
    mova      m4, [r0+8]
    pshufw    m7, m6, 0
    pshufw    m6, m6, q2222
    pshufw    m5, m4, 0
    pshufw    m4, m4, q2222
%endif
    jnz .nz
    ADS_START ; r0d, r4, r5/r5d/r5m, r6
%if ARCH_X86_64 && mmsize == 16
    movu     m10, [r1]
    movu     m11, [r1+r2]
    SPLATW    m8, r6m
.loop:
    psubw     m0, m10, m7
    movu     m10, [r1+16]
    psubw     m1, m10, m6
    ABSW      m0, m0, m2
    ABSW      m1, m1, m3
    psubw     m2, m11, m5
    movu     m11, [r1+r2+16]
    paddw     m0, m1
    psubw     m3, m11, m4
    movu      m9, [r3]
    ABSW      m2, m2, m1
    ABSW      m3, m3, m1
    paddw     m0, m2
    paddw     m0, m3
    paddusw   m0, m9
    psubusw   m1, m8, m0
%else
%if ARCH_X86_64 && mmsize != 8
    SPLATW    m8, r6m
%endif
.loop:
    movu      m0, [r1]
    movu      m1, [r1+16]
    psubw     m0, m7
    psubw     m1, m6
    ABSW      m0, m0, m2
    ABSW      m1, m1, m3
    movu      m2, [r1+r2]
    movu      m3, [r1+r2+16]
    psubw     m2, m5
    psubw     m3, m4
    paddw     m0, m1
    ABSW      m2, m2, m1
    ABSW      m3, m3, m1
    paddw     m0, m2
    paddw     m0, m3
    movu      m2, [r3]
%if ARCH_X86_64 && mmsize != 8
    mova      m1, m8
%else
    SPLATW    m1, r6m
%endif
    paddusw   m0, m2
    psubusw   m1, m0
%endif ; ARCH
    packsswb  m1, m1
%if mmsize == 32
    vpermq    m1, m1, q3120
    mova    [r6], xm1
%else
    movh    [r6], m1
%endif
    ADS_END mmsize/2 ; r0d, r1, r3..r5, r6, jmp .loop/adv_mvs_
.nz:
    ADS_START ; r0d, r4, r5/r5d/r5m, r6
%if ARCH_X86_64 && mmsize == 16
    movu     m10, [r1]
    movu     m11, [r1+r2]
    SPLATD    m8, r6m
.loop_nz:
    psubw     m0, m10, m7
    movu     m10, [r1+16]
    psubw     m1, m10, m6
    ABSW      m0, m0, m2
    ABSW      m1, m1, m3
    psubw     m2, m11, m5
    movu     m11, [r1+r2+16]
    paddw     m0, m1
    psubw     m3, m11, m4
    movu      m9, [r3]
    ABSW      m2, m2, m1
    ABSW      m3, m3, m1
    paddw     m0, m2
    paddw     m0, m3
    pxor      m3, m3
    mova      m2, m0
    mova      m1, m9
    punpcklwd m0, m3
    punpcklwd m9, m3
    punpckhwd m2, m3
    punpckhwd m1, m3
    paddd     m0, m9
    paddd     m2, m1
    psubd     m1, m8, m0
    psubd     m3, m8, m2
    packssdw  m1, m3
    packuswb  m1, m1
%else
%if ARCH_X86_64 && mmsize != 8
    SPLATD    m8, r6m
%endif
.loop_nz:
    movu      m0, [r1]
    movu      m1, [r1+16]
    psubw     m0, m7
    psubw     m1, m6
    ABSW      m0, m0, m2
    ABSW      m1, m1, m3
    movu      m2, [r1+r2]
    movu      m3, [r1+r2+16]
    psubw     m2, m5
    psubw     m3, m4
    paddw     m0, m1
    ABSW      m2, m2, m1
    ABSW      m3, m3, m1
    paddw     m0, m2
    paddw     m0, m3
%if mmsize == 32
    movu      m1, [r3]
%else
    movh      m1, [r3]
%endif
    pxor      m3, m3
    mova      m2, m0
    punpcklwd m0, m3
    punpcklwd m1, m3
    punpckhwd m2, m3
    paddd     m0, m1
%if mmsize == 32
    movu      m1, [r3]
    punpckhwd m1, m3
%else
    movh      m1, [r3+mmsize/2]
    punpcklwd m1, m3
%endif
    paddd     m2, m1
%if ARCH_X86_64 && mmsize != 8
    mova      m1, m8
%else
    SPLATD    m1, r6m
%endif
    mova      m3, m1
    psubd     m1, m0
    psubd     m3, m2
    packssdw  m1, m3
    packuswb  m1, m1
%endif ; ARCH
%if mmsize == 32
    vpermq    m1, m1, q3120
    mova    [r6], xm1
%else
    movh    [r6], m1
%endif
    ADS_END mmsize/2, .loop_nz ; r0d, r1, r3..r5, r6, jmp .loop_nz/adv_mvs_

cglobal pixel_ads2, 5,7,8
    test dword r6m, 0xffff0000
%if mmsize >= 32
    vpbroadcastw m7, [r0+0]
    vpbroadcastw m6, [r0+4]
%elif mmsize == 16
    movq       m6, [r0]
    pshuflw    m7, m6, 0
    pshuflw    m6, m6, q2222
    punpcklqdq m7, m7
    punpcklqdq m6, m6
%else
    mova      m6, [r0]
    pshufw    m7, m6, 0
    pshufw    m6, m6, q2222
%endif
    jnz .nz
    ADS_START ; r0d, r4, r5/r5d/r5m, r6
    SPLATW    m5, r6m
.loop:
    movu      m0, [r1]
    movu      m1, [r1+r2]
    movu      m2, [r3]
    psubw     m0, m7
    psubw     m1, m6
    ABSW      m0, m0, m3
    ABSW      m1, m1, m4
    paddw     m0, m1
    paddusw   m0, m2
    psubusw   m1, m5, m0
    packsswb  m1, m1
%if mmsize == 32
    vpermq    m1, m1, q3120
    mova    [r6], xm1
%else
    movh    [r6], m1
%endif
    ADS_END mmsize/2 ; r0d, r1, r3..r5, r6, jmp .loop/adv_mvs_
.nz:
    ADS_START ; r0d, r4, r5/r5d/r5m, r6
    SPLATD    m5, r6m
    pxor      m4, m4
.loop_nz:
    movu      m0, [r1]
    movu      m1, [r1+r2]
    movu      m2, [r3]
    psubw     m0, m7
    psubw     m1, m6
    ABSW      m0, m0, m3
    ABSW      m1, m1, m3
    paddw     m0, m1
    punpckhwd m3, m2, m4
    punpckhwd m1, m0, m4
    punpcklwd m2, m4
    punpcklwd m0, m4
    paddd     m1, m3
    paddd     m0, m2
    psubd     m3, m5, m1
    psubd     m2, m5, m0
    packssdw  m2, m3
    packuswb  m2, m2
%if mmsize == 32
    vpermq    m2, m2, q3120
    mova    [r6], xm2
%else
    movh    [r6], m2
%endif
    ADS_END mmsize/2, .loop_nz ; r0d, r1, r3..r5, r6, jmp .loop_nz/adv_mvs_

cglobal pixel_ads1, 5,7,8
    test dword r6m, 0xffff0000
    SPLATW    m7, [r0]
    jnz .nz
    ADS_START ; r0d, r4, r5/r5d/r5m, r6
    SPLATW    m6, r6m
.loop:
    movu      m0, [r1]
    movu      m1, [r1+mmsize]
    movu      m2, [r3]
    movu      m3, [r3+mmsize]
    psubw     m0, m7
    psubw     m1, m7
    ABSW      m0, m0, m4
    ABSW      m1, m1, m5
    paddusw   m0, m2
    paddusw   m1, m3
    psubusw   m4, m6, m0
    psubusw   m5, m6, m1
    packsswb  m4, m5
%if mmsize == 32
    vpermq    m4, m4, q3120
%endif
    mova    [r6], m4
    ADS_END mmsize ; r0d, r1, r3..r5, r6, jmp .loop/adv_mvs_
.nz:
    ADS_START ; r0d, r4, r5/r5d/r5m, r6
    SPLATD    m6, r6m
    pxor      m5, m5
.loop_nz:
    movu      m0, [r1]
    movu      m1, [r1+mmsize]
    movu      m2, [r3]
    psubw     m0, m7
    psubw     m1, m7
    ABSW      m0, m0, m3
    ABSW      m1, m1, m4
    punpckhwd m3, m2, m5
    punpckhwd m4, m0, m5
    punpcklwd m2, m5
    punpcklwd m0, m5
    paddd     m4, m3
    paddd     m0, m2
    psubd     m3, m6, m4
    movu      m4, [r3+mmsize]
    psubd     m2, m6, m0
    packssdw  m2, m3
    punpckhwd m0, m1, m5
    punpckhwd m3, m4, m5
    punpcklwd m1, m5
    punpcklwd m4, m5
    paddd     m0, m3
    paddd     m1, m4
    psubd     m3, m6, m0
    psubd     m4, m6, m1
    packssdw  m4, m3
    packuswb  m2, m4
%if mmsize == 32
    vpermq    m2, m2, q3120
%endif
    mova    [r6], m2
    ADS_END mmsize, .loop_nz ; r0d, r1, r3..r5, r6, jmp .loop_nz/adv_mvs_
%endmacro

INIT_MMX mmx2
ADS_XMM
INIT_XMM sse2
ADS_XMM
INIT_XMM ssse3
ADS_XMM
INIT_XMM avx
ADS_XMM
INIT_YMM avx2
ADS_XMM

%endif ; HIGH_BIT_DEPTH

; int pixel_ads_mvs( int16_t *mvs, uint8_t *masks, int width )
; {
;     int nmv=0, i, j;
;     *(uint32_t*)(masks+width) = 0;
;     for( i=0; i<width; i+=8 )
;     {
;         uint64_t mask = *(uint64_t*)(masks+i);
;         if( !mask ) continue;
;         for( j=0; j<8; j++ )
;             if( mask & (255<<j*8) )
;                 mvs[nmv++] = i+j;
;     }
;     return nmv;
; }

%macro TEST 1 ; r0/r0d, r1w/r1d, r2d, r3b/r3d, r4
    mov     [r4+r0*2], r1w
    test    r2d, 0xff<<(%1*8)
    setne   r3b
    add     r0d, r3d
    inc     r1d
%endmacro

INIT_MMX mmx
cglobal pixel_ads_mvs, 0,7,0
ads_mvs_mmx:
    ; mvs = r4
    ; masks = r6
    ; width = r5
    ; clear last block in case width isn't divisible by 8. (assume divisible by 4, so clearing 4 bytes is enough.)
    xor     r0d, r0d
    xor     r1d, r1d
    mov     [r6+r5], r0d
    jmp .loopi
ALIGN 16
.loopi0:
    add     r1d, 8
    cmp     r1d, r5d
    jge .end
.loopi:
    mov     r2,  [r6+r1]
%if ARCH_X86_64
    test    r2,  r2
%else
    mov     r3,  r2
    or     r3d, [r6+r1+4]
%endif
    jz .loopi0
    xor     r3d, r3d
    TEST 0 ; r0/r0d, r1w/r1d, r2d, r3b/r3d, r4
    TEST 1
    TEST 2
    TEST 3
%if ARCH_X86_64
    shr     r2,  32
%else
    mov     r2d, [r6+r1]
%endif
    TEST 0
    TEST 1
    TEST 2
    TEST 3
    cmp     r1d, r5d
    jl .loopi
.end:
    movifnidn eax, r0d
    RET

INIT_XMM ssse3
cglobal pixel_ads_mvs, 0,7,0
ads_mvs_ssse3:
    PIC_BEGIN r1, 0, $$
    mova      m3, [pic(pw_8)]
    mova      m4, [pic(pw_76543210)]
    pxor      m5, m5
    add       r5, r6
    xor      r0d, r0d ; nmv
    mov     [r5], r0d
    PIC64_LEA r1, $$ ; PIC64 isn't necessary for pw_8/pw_76543210 above
.loop:
    movh      m0, [r6]
    pcmpeqb   m0, m5
    pmovmskb r2d, m0
    xor      r2d, 0xffff                         ; skipping if r2d is zero is slower (branch mispredictions)
    movzx    r3d, byte [r2+pic(popcnt_table)]    ; popcnt
    add      r2d, r2d
    ; shuffle counters based on mv mask
    pshufb    m2, m4, [r2*8+pic(ads_mvs_shuffle)]
    movu [r4+r0*2], m2
    add      r0d, r3d
    paddw     m4, m3                             ; {i*8+0, i*8+1, i*8+2, i*8+3, i*8+4, i*8+5, i*8+6, i*8+7}
    add       r6, 8
    cmp       r6, r5
    jl .loop
    %assign pic64 0
    PIC_END
    movifnidn eax, r0d
    RET
