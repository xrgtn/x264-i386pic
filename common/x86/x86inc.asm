;*****************************************************************************
;* x86inc.asm: x264asm abstraction layer
;*****************************************************************************
;* Copyright (C) 2005-2023 x264 project
;*
;* Authors: Loren Merritt <lorenm@u.washington.edu>
;*          Henrik Gramner <henrik@gramner.com>
;*          Anton Mitrofanov <BugMaster@narod.ru>
;*          Fiona Glaser <fiona@x264.com>
;*
;* Permission to use, copy, modify, and/or distribute this software for any
;* purpose with or without fee is hereby granted, provided that the above
;* copyright notice and this permission notice appear in all copies.
;*
;* THE SOFTWARE IS PROVIDED "AS IS" AND THE AUTHOR DISCLAIMS ALL WARRANTIES
;* WITH REGARD TO THIS SOFTWARE INCLUDING ALL IMPLIED WARRANTIES OF
;* MERCHANTABILITY AND FITNESS. IN NO EVENT SHALL THE AUTHOR BE LIABLE FOR
;* ANY SPECIAL, DIRECT, INDIRECT, OR CONSEQUENTIAL DAMAGES OR ANY DAMAGES
;* WHATSOEVER RESULTING FROM LOSS OF USE, DATA OR PROFITS, WHETHER IN AN
;* ACTION OF CONTRACT, NEGLIGENCE OR OTHER TORTIOUS ACTION, ARISING OUT OF
;* OR IN CONNECTION WITH THE USE OR PERFORMANCE OF THIS SOFTWARE.
;*****************************************************************************

; This is a header file for the x264ASM assembly language, which uses
; NASM/YASM syntax combined with a large number of macros to provide easy
; abstraction between different calling conventions (x86_32, win64, linux64).
; It also has various other useful features to simplify writing the kind of
; DSP functions that are most often used in x264.

; Unlike the rest of x264, this file is available under an ISC license, as it
; has significant usefulness outside of x264 and we want it to be available
; to the largest audience possible.  Of course, if you modify it for your own
; purposes to add a new feature, we strongly encourage contributing a patch
; as this feature might be useful for others as well.  Send patches or ideas
; to x264-devel@videolan.org .

%ifndef private_prefix
    %define private_prefix x264
%endif

%ifndef public_prefix
    %define public_prefix private_prefix
%endif

%ifndef STACK_ALIGNMENT
    %if ARCH_X86_64
        %define STACK_ALIGNMENT 16
    %else
        %define STACK_ALIGNMENT 4
    %endif
%endif

%define WIN64  0
%define UNIX64 0
%if ARCH_X86_64
    %ifidn __OUTPUT_FORMAT__,win32
        %define WIN64  1
    %elifidn __OUTPUT_FORMAT__,win64
        %define WIN64  1
    %elifidn __OUTPUT_FORMAT__,x64
        %define WIN64  1
    %else
        %define UNIX64 1
    %endif
%endif

%define FORMAT_ELF 0
%define FORMAT_MACHO 0
%ifidn __OUTPUT_FORMAT__,elf
    %define FORMAT_ELF 1
%elifidn __OUTPUT_FORMAT__,elf32
    %define FORMAT_ELF 1
%elifidn __OUTPUT_FORMAT__,elf64
    %define FORMAT_ELF 1
%elifidn __OUTPUT_FORMAT__,macho
    %define FORMAT_MACHO 1
%elifidn __OUTPUT_FORMAT__,macho32
    %define FORMAT_MACHO 1
%elifidn __OUTPUT_FORMAT__,macho64
    %define FORMAT_MACHO 1
%endif

%ifdef PREFIX
    %define mangle(x) _ %+ x
%else
    %define mangle(x) x
%endif

; Use VEX-encoding even in non-AVX functions
%ifndef FORCE_VEX_ENCODING
    %define FORCE_VEX_ENCODING 0
%endif

%macro SECTION_RODATA 0-1 16
    %ifidn __OUTPUT_FORMAT__,win32
        SECTION .rdata align=%1
    %elif WIN64
        SECTION .rdata align=%1
    %else
        SECTION .rodata align=%1
    %endif
%endmacro

; Set i386pic from -DPIC option before PIC gets twisted.
%if %isdef(PIC) && ARCH_X86_64==0
    %assign i386pic 1
%else
    %assign i386pic 0
%endif
%assign amd64pic 0

%if ARCH_X86_64
    %define PIC 1 ; always use PIC on x86-64
    default rel
%elifidn __OUTPUT_FORMAT__,win32
    %define PIC 0 ; PIC isn't used on 32-bit Windows
%elifndef PIC
    %define PIC 0
%endif

%define HAVE_PRIVATE_EXTERN 1
%ifdef __NASM_VER__
    %use smartalign
    %if __NASM_VERSION_ID__ < 0x020e0000 ; 2.14
        %define HAVE_PRIVATE_EXTERN 0
    %endif
%endif

; Macros to eliminate most code duplication between x86_32 and x86_64:
; Currently this works only for leaf functions which load all their arguments
; into registers at the start, and make no other use of the stack. Luckily that
; covers most of x264's asm.

; PROLOGUE:
; %1 = number of arguments. loads them from stack if needed.
; %2 = number of registers used. pushes callee-saved regs if needed.
; %3 = number of xmm registers used. pushes callee-saved xmm regs if needed.
; %4 = (optional) stack size to be allocated. The stack will be aligned before
;      allocating the specified stack size. If the required stack alignment is
;      larger than the known stack alignment the stack will be manually aligned
;      and an extra register will be allocated to hold the original stack
;      pointer (to not invalidate r0m etc.). To prevent the use of an extra
;      register as stack pointer, request a negative stack size.
; %4+/%5+ = list of names to define to registers
; PROLOGUE can also be invoked by adding the same options to cglobal

; e.g.
; cglobal foo, 2,3,7,0x40, dst, src, tmp
; declares a function (foo) that automatically loads two arguments (dst and
; src) into registers, uses one additional register (tmp) plus 7 vector
; registers (m0-m6) and allocates 0x40 bytes of stack space.

; TODO Some functions can use some args directly from the stack. If they're the
; last args then you can just not declare them, but if they're in the middle
; we need more flexible macro.

; RET:
; Pops anything that was pushed by PROLOGUE, and returns.

; registers:
; rN and rNq are the native-size register holding function argument N
; rNd, rNw, rNb are dword, word, and byte size
; rNh is the high 8 bits of the word size
; rNm is the original location of arg N (a register or on the stack), dword
; rNmp is native size

%macro DECLARE_REG 2-3
    %define r%1q %2
    %define r%1d %2d
    %define r%1w %2w
    %define r%1b %2b
    %define r%1h %2h
    %define %2q %2
    %if %0 == 2
        %define r%1m  %2d
        %define r%1mp %2
    %elif ARCH_X86_64 ; memory
        %define r%1m [rstk + stack_offset + %3]
        %define r%1mp qword r %+ %1 %+ m
    %else
        %define r%1m [rstk + stack_offset + %3]
        %define r%1mp dword r %+ %1 %+ m
    %endif
    %define r%1  %2
%endmacro

%macro DECLARE_REG_SIZE 3
    %define r%1q r%1
    %define e%1q r%1
    %define r%1d e%1
    %define e%1d e%1
    %define r%1w %1
    %define e%1w %1
    %define r%1h %3
    %define e%1h %3
    %define r%1b %2
    %define e%1b %2
    %if ARCH_X86_64 == 0
        %define r%1 e%1
    %endif
%endmacro

DECLARE_REG_SIZE ax, al, ah
DECLARE_REG_SIZE bx, bl, bh
DECLARE_REG_SIZE cx, cl, ch
DECLARE_REG_SIZE dx, dl, dh
DECLARE_REG_SIZE si, sil, null
DECLARE_REG_SIZE di, dil, null
DECLARE_REG_SIZE bp, bpl, null

; t# defines for when per-arch register allocation is more complex than just function arguments

%macro DECLARE_REG_TMP 1-*
    %assign %%i 0
    %rep %0
        CAT_XDEFINE t, %%i, r%1
        %assign %%i %%i+1
        %rotate 1
    %endrep
%endmacro

%macro DECLARE_REG_TMP_SIZE 0-*
    %rep %0
        %define t%1q t%1 %+ q
        %define t%1d t%1 %+ d
        %define t%1w t%1 %+ w
        %define t%1h t%1 %+ h
        %define t%1b t%1 %+ b
        %rotate 1
    %endrep
%endmacro

DECLARE_REG_TMP_SIZE 0,1,2,3,4,5,6,7,8,9,10,11,12,13,14

%if ARCH_X86_64
    %define gprsize 8
%else
    %define gprsize 4
%endif

%macro LEA 2
%if ARCH_X86_64
    lea %1, [%2]
%elif PIC
    call $+5 ; special-cased to not affect the RSB on most CPU:s
    pop %1
    add %1, (%2)-$+1
%else
    mov %1, %2
%endif
%endmacro

; Repeats an instruction/operation for multiple arguments.
; Example usage: "REPX {psrlw x, 8}, m0, m1, m2, m3"
%macro REPX 2-* ; operation, args
    %xdefine %%f(x) %1
    %rep %0 - 1
        %rotate 1
        %%f(%1)
    %endrep
%endmacro

%macro PUSH 1
    push %1
    %ifidn rstk, rsp
        %assign stack_offset stack_offset+gprsize
    %endif
%endmacro

%macro POP 1
    pop %1
    %ifidn rstk, rsp
        %assign stack_offset stack_offset-gprsize
    %endif
%endmacro

%macro PUSH_IF_USED 1-*
    %rep %0
        %if %1 < regs_used
            PUSH r%1
        %endif
        %rotate 1
    %endrep
%endmacro

%macro POP_IF_USED 1-*
    %rep %0
        %if %1 < regs_used
            pop r%1
        %endif
        %rotate 1
    %endrep
%endmacro

%macro LOAD_IF_USED 1-*
    %rep %0
        %if %1 < num_args
            mov r%1, r %+ %1 %+ mp
        %endif
        %rotate 1
    %endrep
%endmacro

%macro SUB 2
    sub %1, %2
    %ifidn %1, rstk
        %assign stack_offset stack_offset+(%2)
    %endif
%endmacro

%macro ADD 2
    add %1, %2
    %ifidn %1, rstk
        %assign stack_offset stack_offset-(%2)
    %endif
%endmacro

%macro movifnidn 2
    %ifnidn %1, %2
        mov %1, %2
    %endif
%endmacro

%if ARCH_X86_64 == 0
    %define movsxd movifnidn
%endif

%macro movsxdifnidn 2
    %ifnidn %1, %2
        movsxd %1, %2
    %endif
%endmacro

%macro ASSERT 1
    %if (%1) == 0
        %error assertion ``%1'' failed
    %endif
%endmacro

%macro DEFINE_ARGS 0-*
    %ifdef n_arg_names
        %assign %%i 0
        %rep n_arg_names
            CAT_UNDEF arg_name %+ %%i, q
            CAT_UNDEF arg_name %+ %%i, d
            CAT_UNDEF arg_name %+ %%i, w
            CAT_UNDEF arg_name %+ %%i, h
            CAT_UNDEF arg_name %+ %%i, b
            CAT_UNDEF arg_name %+ %%i, m
            CAT_UNDEF arg_name %+ %%i, mp
            CAT_UNDEF arg_name, %%i
            %assign %%i %%i+1
        %endrep
    %endif

    %xdefine %%stack_offset stack_offset
    %undef stack_offset ; so that the current value of stack_offset doesn't get baked in by xdefine
    %assign %%i 0
    %rep %0
        %ifnempty %1
            %xdefine %1q r %+ %%i %+ q
            %xdefine %1d r %+ %%i %+ d
            %xdefine %1w r %+ %%i %+ w
            %xdefine %1h r %+ %%i %+ h
            %xdefine %1b r %+ %%i %+ b
            %xdefine %1m r %+ %%i %+ m
            %xdefine %1mp r %+ %%i %+ mp
            CAT_XDEFINE arg_name, %%i, %1
        %endif
        %assign %%i %%i+1
        %rotate 1
    %endrep
    %xdefine stack_offset %%stack_offset
    %if %0
        %assign n_arg_names %0
    %else
        %undef n_arg_names
    %endif
%endmacro

; PIC macros:
; * i386pic          i386 PIC flag:
;                    0  no PIC used (pic(a) produces (a), PIC_BEGIN/END and
;                       PIC_ALLOC/FREE are no-op)
;                    1  enable PIC_BEGIN/END and PIC_ALLOC/FREE and expand
;                       pic(a) into (rpic+(a)-lpic)
; * amd64pic         amd64 PIC flag for pic() macro:
;                    0  pic(a) expands to (a)
;                    1  pic(a) expands to (rpic64+(a)-lpic64)
;                    NOTE:
;                    * i386pic is set once and for whole compilation unit
;                    * amd64pic is reset to 0 at the beginning of each function
;                      (in cglobal_internal macro)
;                    * i386pic and amd64pic are mutually exclusive.
; * pic(abs_addr)    expands to (rpic+(abs_addr)-lpic) if i386pic is set;
;                    expands to (rpic64+(abs_addr)-lpic64) if amd64pic is set;
;                    expands to (abs_addr) otherwize.
; * PIC_BEGIN        stores previous value of rpic on stack/in rpicsave and
;                    initializes rpic if it isn't already initialized (possibly
;                    using lpiccache etc).
;                    Expands to nothing if i386pic is not set.
; * PIC_END          restores previous rpic and undefines rpic if not inside
;                    outer PIC_BEGIN/PIC_END block.
;                    Expands to nothing if i386pic is not set.
; * picb             PIC_BEGIN/PIC_END balance counter.
; * rpic             gen-purpose register used as base reg for lpic-relative
;                    addressing; after initialization by PIC_BEGIN, rpic
;                    contains address of .lpicN label generated by that macro
;                    (or address of its 3rd parameter).
; * rpicsave         Specifies location used for storing value in rpic register
;                    before initializing it for i386 PIC memory addressing. By
;                    default rpicsave is undefined in each `cglobal' function;
;                    to enable i386 PIC you must explicitly define rpicsave as
;                    empty or use PIC_ALLOC_RPICSAVE in each procedure.
;                    * empty  use `PUSH rpic' to save and `POP rpic' to restore
;                             saved value of rpic;
;                    * [mem]  use `mov rpicsave, rpic' to save,
;                             `mov rpic, rpicsave' to restore;
;                    * undef  generate "unsafe to push rpic" %error when
;                             PIC_BEGIN tries to save rpic
; * rpicsf           "rpic saved" flag:
;                    0  rpic hasn't been saved in PIC_BEGIN and doesn't need
;                       restoring in PIC_END;
;                    1  rpic has been saved in PIC_BEGIN and must be restored
;                       in corresponding PIC_END.
; * lpic             label used to initialize rpic.
; * lpiccache        lpic cache location (e.g. [rstk+stack_offset-N]), if
;                    defined.
; * lpiccf           "lpic cached" flag.
; * dpic             "designated" no-save register for next top PIC_BEGIN/END
;                    block
; * dpiclf           dpic loaded flag: set when dpic contains lpic address
; * picallocd        indicates how PIC_ALLOC allocated memory; necessary for
;                    PIC_FREE to correctly free it.
; * NEXT_LPIC        generates unique label in ..@lpicN or ..@lpicN_XXX format
;                    and puts the result in next_lpic xdef.
; * lpicno_xxx       current/latest .lpic number per function/module etc.
; * PIC64_LEA        initializes rpic64/lpic64 and sets amd64pic flag.
; * rpic64           rpic for amd64 mode.
; * lpic64           lpic for amd64 mode.
; * PIC_CONTEXT_PUSH saves PIC context on macro stack:
;                    * picb
;                    * rpic
;                    * rpicsave
;                    * rpicsf
;                    * lpic
;                    * lpiccache
;                    * lpiccf
;                    * dpic
;                    * dpicf
;                    * picallocd
;                    * rstk (rpicsave/lpiccache locations can be defined
;                      relative to rstk+stack_offset/size/size_padded)
;                    * stack_offset (PUSH/POP rpic can modify stack_offset,
;                      therefore it's included in PIC conext; also see rstk)
;                    * stack_size (see rstk)
;                    * stack_size_padded (see rstk)
; * PIC_CONTEXT_POP  restores PIC context previously saved by PIC_CONTEXT_PUSH.
;                    Note that global_lpicno/foo_lpicno are not part of PIC
;                    context (lpic is enough); while rpic64 and lpic64 do not
;                    have limiting structure like BEGIN/END blocks over them
;                    and thus do not require context push/pop hack.

%define pic(a) %cond(i386pic, (rpic+(a)-lpic),\
                     %cond(amd64pic, (rpic64+(a)-lpic64), (a)))
%assign  picb 0
%assign  lpiccf 0
%xdefine picallocd 0

; PIC_CONTEXT_PUSH/POP macro pair is useful when code returns or jumps out from
; inside of PIC_BEGIN/END block, e.g. if function has several RETs:
;     cglobal foo, 5,6,7
;         PIC_BEGIN r6 ; single PIC block for the whole foo()
;         ...
;         jnz .ret2
;         ..
;         RET ; error: unbalanced PIC_BEGIN/PIC_END (1) at end of foo
;     .ret2:
;         ...
;         PIC_END
;         RET
; Typically the problem above can be somehow solved by splitting and narrowing
; PIC block at the expense of runtime speed, like this:
;     cglobal foo, 5,6,7
;         PIC_BEGIN
;         ...       ; 1st block
;         PIC_END
;         jnz .ret2
;         PIC_BEGIN
;         ...       ; 2nd block
;         PIC_END
;         RET
;     .ret2:
;         PIC_BEGIN
;         ...       ; 3rd block
;         PIC_END
;         RET
; Sometimes PIC block splitting is undesirable, like when the `jnz .ret2' op is
; inside of a loop -- splitting like shown above will produce
; pop/jnz/push/call/pop sequence instead of just jnz, end these extra 4 ops
; (pop/push/call/pop) will be repeated many times with the loop. In such case
; we can use the following hack instead:
;     cglobal foo, 5,6,7   ; stack_offset=12
;         PIC_BEGIN r6     ; PUSH r6, stack_offset=16
;         ...
;         jnz .ret2
;         ..
;         PIC_CONTEXT_PUSH ; save PIC context before PIC_END
;         PIC_END          ; POP r6, picb=0
;         RET              ; pop r5, pop r4, pop r3, ret
;         PIC_CONTEXT_POP  ; make it look like the above PIC_END didn't happen:
;     .ret2:               ; picb==1, stack_offset==15, etc
;         ...
;         PIC_END
;         RET
%macro PIC_CONTEXT_PUSH 0
    %push pic_context
    ; Assume that rpicsave and lpiccache are defined WRT rstk/rsp and
    ; stack_offset/stack_size/stack_size_padded -- avoid expansion of
    ; rstk+stack_xxx into reg+numeric-value-at-this-moment by undefining these
    ; params, xdef-ing context-local copies with params unexpanded, then
    ; restoring params:
    STK_CONTEXT_STORE_UNDEF
    %assign %$picb picb
    %ifdef rpic
        %xdefine %$rpic rpic
    %endif
    %ifdef rpicsave
        %xdefine %$rpicsave rpicsave
    %endif
    %ifdef rpicsf
        %assign %$rpicsf rpicsf
    %endif
    %ifdef lpic
        %xdefine %$lpic lpic
    %endif
    %ifdef lpiccache
        %xdefine %$lpiccache lpiccache
    %endif
    %ifdef lpiccf
        %xdefine %$lpiccf lpiccf
    %endif
    %ifdef dpic
        %xdefine %$dpic dpic
    %endif
    %ifdef dpiclf
        %xdefine %$dpiclf dpiclf
    %endif
    %xdefine %$picallocd picallocd
    ; restore rstk/stack_params:
    STK_CONTEXT_LOAD
%endmacro
%macro PIC_CONTEXT_POP 0
    ; Assume that %$rpicsave and %$lpiccache are defined WRT
    ; rstk/rsp+stack_offset/stack_size/stack_size_padded -- avoid expansion of
    ; rstk+stack_xxx into reg+numeric-value-at-this-moment by undefining these
    ; params first and restoring them from context-local copies last:
    STK_CONTEXT_UNDEF
    %assign picb %$picb
    %ifdef %$rpic
        %xdefine rpic %$rpic
    %else
        %undef rpic
    %endif
    %ifdef %$rpicsave
        %xdefine rpicsave %$rpicsave
    %else
        %undef rpicsave
    %endif
    %ifdef %$rpicsf
        %assign rpicsf %$rpicsf
    %else
        %undef rpicsf
    %endif
    %ifdef %$lpic
        %xdefine lpic %$lpic
    %else
        %undef lpic
    %endif
    %ifdef %$lpiccache
        %xdefine lpiccache %$lpiccache
    %else
        %undef lpiccache
    %endif
    %ifdef %$lpiccf
        %xdefine lpiccf %$lpiccf
    %else
        %undef lpiccf
    %endif
    %ifdef %$dpic
        %xdefine dpic %$dpic
    %else
        %undef dpic
    %endif
    %ifdef %$dpiclf
        %xdefine dpiclf %$dpiclf
    %else
        %undef dpiclf
    %endif
    %xdefine picallocd %$picallocd
    ; restore rstk/stack_params last:
    STK_CONTEXT_LOAD
    %pop pic_context
%endmacro

; PIC_BEGIN [reg[, fsave[, label]]]
; Initialize PIC block to use reg as rpic, or select rpic automatically (r2
; if regs_used < 3 or r5 otherwize). NOTE: if dpic is defined beforehand,
; dpic register will be used for rpic, overriding reg parameter and
; auto-selection.
; If fsave flag is given, use it to override rpicsf which is decided
; automatically (typically rpicsf=0 when regs_used < 3).
; If label parameter is given, initialize rpic with its address instead of
; address of .lpicN label.
; If rpicsf is not set (is zero), don't save current contents of rpic register;
; otherwize:
; * if rpicsave has been defined beforehand and is not empty, use rpicsave to
;   save current contents of rpic register to;
; * if rpicsave is empty, push current rpic contents to stack;
; * if rpicsave is undef, generate %error.
; If lpiccf has been set beforehand, load previous lpic label address from
; lpiccache and don't perform call/pop initialization.
%macro PIC_BEGIN 0-3
    %if i386pic
        %if picb == 0
            %assign %%rpic_auto 1
            %if %0 >= 1
                %ifnempty %1
                    %assign %%rpic_auto 0
                %endif
            %endif
            ; cglobal foo_asm, 0,0,0,a,b,c,d,e in fact uses 5 registers (a:r0,
            ; b:r1 etc), it just doesn't do push/pop for them. Number of
            ; "register aliases" is indicated in n_arg_names
            %ifnum n_arg_names
                %assign %%narg n_arg_names
            %else
                %assign %%narg 0
            %endif
            %ifdef dpic ; designated no-save rpic present
                %xdefine rpic dpic
                %assign rpicsf 0
            %elif %%rpic_auto == 0
                %xdefine rpic %1
                %assign rpicsf 1
            %elifndef regs_used ; unknown number of regs used
                %xdefine rpic r5 ; edi on i386
                %assign rpicsf 1
            %elif %%narg == 0
                %if regs_used < 3
                    %xdefine rpic r2 ; edx on i386
                    %assign rpicsf 0 ; r2 is /scratch register/
                %else
                    %xdefine rpic r5
                    %assign rpicsf 1
                %endif
            %elif regs_used < 3 && n_arg_names < 3
                %xdefine rpic r2
                %assign rpicsf 1 ; force saving, as ABI may be custom/asm
            %else ; many regs used
                %xdefine rpic r5
                %assign rpicsf 1
            %endif
            ; override rpicsf if fsave is present:
            %if %0 >=2
                %ifnempty %2
                    ; ignore %2 if using dpic
                    %ifndef dpic
                        %xdefine rpicsf %2
                    %endif
                %endif
            %endif
            %if rpicsf
                %ifndef rpicsave
                    %error %strcat("unsafe to push rpic in ", \
                        current_function)
                %elifempty rpicsave
                    PUSH rpic
                %else
                    mov rpicsave, rpic
                %endif
            %endif
            %assign %%lpicchanged 0
            %ifndef dpic
                %assign %%dpiclf 0
            %elifndef dpiclf
                %assign %%dpiclf 0
            %elif dpiclf==0
                %assign %%dpiclf 0
            %else
                %assign %%dpiclf 1
            %endif
            %if %%dpiclf
                ; do nothing (rpic==dpic and dpic is already loaded)
            %elif lpiccf
                ; load rpic from lpiccache
                movifnidn rpic, lpiccache
            %else
                ; init rpic by call+pop sequence
                NEXT_LPIC
                %xdefine lpic next_lpic
                %assign %%lpicchanged 1
                call lpic
lpic:           pop rpic
            %endif
            %if %0 >= 3
                ; add rpic, (%3) - lpic
                sub rpic, lpic - (%3)
                %xdefine lpic (%3)
                %assign %%lpicchanged 1
            %endif
            %if %%lpicchanged
                %ifdef lpiccache
                    ; Update lpiccache:
                    %ifnidn lpiccache, rpic
                        ; Prohibit cases like rpic:r6, lpiccache:[r6]
                        CHECK_REG_COLLISION "rpic","lpiccache"
                        mov lpiccache, rpic
                    %endif
                    %assign lpiccf 1
                %endif
            %endif
            %ifdef dpic
                %assign dpiclf 1
            %endif
        %endif
        %assign picb picb+1
    %endif
%endmacro
; PIC_END closes current PIC_BEGIN/END block and decrements picb.
; When closing last (topmost) block:
; * PIC_END updates lpiccache if it's defined and lpiccf is unset, and
;   sets lpiccf flag after update;
; * if dpic is defined as the same register as rpic, sets dpiclf flag;
; * restores previous value of register used for rpic, if rpicsf is set:
;   - if dpic is defined as the same register as rpic when restoring rpic,
;     unsets dpiclf;
; * if lpiccf or dpiclf is set, keeps lpic defined:
;   - otherwize (if both are unset) undefines lpic;
; * undefines rpic and rpicsf;
; * leaves dpic without changes.
%macro PIC_END 0
    %if i386pic
        %assign picb picb-1
        %if picb < 0
            %error %strcat(%?, " not matched by PIC_BEGIN in ",\
                %str(current_function))
            %assign picb 0 ; silence further PIC error messages
        %elif picb == 0
            %ifdef lpiccache
                %if !lpiccf ; if not cached / cache invalid:
                    ; Update lpiccache:
                    %ifnidn lpiccache, rpic
                        ; Prohibit cases like rpic:r6, lpiccache:[r6]
                        CHECK_REG_COLLISION "rpic","lpiccache"
                        mov lpiccache, rpic
                    %endif
                    %assign lpiccf 1
                %endif
            %else
                %assign lpiccf 0
            %endif
            %assign %%dpiclf -1 ; -1 inicates "undef"
            %ifidn dpic, rpic
                %assign %%dpiclf 1
            %endif
            %if rpicsf
                %ifndef rpicsave
                    ; %error %strcat("unsafe to pop rpic in ", \
                    ;    current_function)
                %elifempty rpicsave
                    POP rpic
                %else
                    mov rpic, rpicsave
                %endif
                %ifidn rpic, lpiccache
                    ; restoring into lpiccache invalidates cache; having
                    ; rpicsf set while rpic==lpiccache is an error:
                    %error %strcat("rpicsf set while rpic=lpiccache=", \
                        lpiccache)
                %endif
                %ifidn dpic, rpic
                    %assign %%dpiclf 0
                %endif
            %endif
            %if !lpiccf && %%dpiclf != 1
                %undef lpic
            %endif
            %undef rpic
            %undef rpicsf
            ; commit %%dpiclf (local) to dpiclf (global):
            %if %%dpiclf == 1
                %assign dpiclf 1
            %elif %%dpiclf == 0
                %assign dpiclf 0
            %else
                %undef dpiclf
            %endif
        %endif
    %endif
%endmacro

%macro DESIGNATE_RPIC 0-2
    %if i386pic
        %if picb > 0
            %error %strcat(%?, " inside PIC_BEGIN/PIC_END block in ",\
                %str(current_function))
        %endif
        %if %0 >= 1
            ; designate %1 register for no-save rpic
            %ifnid %1
                %error %strcat("invalid register name: ", %1)
            %endif
            %ifndef reg_id_of_%1
                %error %strcat("not a register name: ", %1)
            %endif
            %xdefine dpic %1
            %assign dpiclf 0
            %if %0 >= 2
                %ifnempty %2
                    %ifnum %2 ; set "dpic loaded" flag
                        %if %2 > 0
                            %assign dpiclf 1
                        %endif
                    %else ; set lpic and dpiclf
                        %xdefine lpic (%2)
                        %assign dpiclf 1
                    %endif
                %endif
            %endif
        %else
            ; unset designated register
            %undef dpic
            %undef dpiclf
        %endif
    %endif
%endmacro

%macro NEXT_LPIC 0 ; returns label name in next_lpic xdef
    %undef next_lpic
    %if %isnidn(%str(current_function),"current_function") && \
            %isid(current_function)
        ; current_function is defined and expands to ID
        %ifndef lpicno_%[current_function]
            ; first ..@lpic label in this function: assign no=0 to label inside
            ; the function and fid=inc(lpicfid) to the function:
            %assign lpicno_%[current_function] 0
            %ifndef lpicfid
                %assign lpicfid 0
            %else
                %assign lpicfid lpicfid+1
            %endif
            %assign lpicfid_%[current_function] lpicfid
        %else
            %assign lpicno_%[current_function] lpicno_%[current_function]+1
        %endif
        %xdefine next_lpic \
            ..@lpic%[lpicfid_%[current_function]]_%[lpicno_%[current_function]]
    %else
        %ifndef lpicno_
            %assign lpicno_ 0
        %else
            %assign lpicno_ lpicno_+1
        %endif
        %xdefine next_lpic ..@lpic_%[lpicno_]
    %endif
%endmacro

; Stack after Windows 64 PROLOGUE J,K,M,N ; stk_align / reqrd_align
;  PROLOGUE 8,12,9,-16 ; 16/16       ;  PROLOGUE 8,12,9,-16 ; 16/32
;  0x..F8: arg7                      ;  0x..F8: arg7
;  0x..F0: arg6                      ;  0x..F0: arg6
;  0x..E8: arg5                      ;  0x..E8: arg5
;  0x..E0: arg4                      ;  0x..E0: arg4
;  0x..D8: ;;xmm;;--+                ;  0x..D8: ;;xmm;;--+
;  0x..D0: ;;;7;;;  +--shadow/pad    ;  0x..D0: ;;;7;;;  +--shadow/pad
;  0x..C8: ,,xmm,,  |    (32)        ;  0x..C8: ,,xmm,,  |   (32)
;  0x..C0: ,,,6,,,_-+___align16      ;  0x..C0: ,,,6,,,_-+__align16
;  0x..B8: retaddr                   ;  0x..B8: retaddr
;  0x..B0: r4     ----+              ;  0x..B0: r4     --+
;  0x..A8: r5         |              ;  0x..A8: r5       |
;  0x..A0: r6         |  stack_      ;  0x..A0: r6       |  stack_
;  0x..98: r7         +--offset      ;  0x..98: r7       +--offset
;  0x..90: r8         |  (136)       ;  0x..90: r8       |   (64)
;  0x..88: r9         |              ;  0x..88: r9       |
;  0x..80: r10        |              ;  0x..80: r10      |
;  0x..78: r11        |              ;  0x..78: r11    --+  <~~~~~~+
;  0x..70: !!!!!!!--+ |              ;  0x..70: ???????             \
;  0x..68: ::xmm::  | |              ;  0x..68: ???????             /
;  0x..60: :::8:::  | | stack_siz    ;  0x..60: ???????_____align32 \
;  0x..58: .......  +---e_padded     ;  0x..58: !!!!!!!--+          /
;  0x..50: ..sha..  | |  (72)        ;  0x..50: rstkm  ~~|~0x..78~~+
;  0x..48: ..dow..  | |              ;  0x..48: ::xmm::  |
;  0x..40: .......__|___align16      ;  0x..40: :::8:::  |  stack_siz
;  0x..38: ==stk==  | |              ;  0x..38: .......  +--e_padded
;  0x..30: ==sz===--+-+              ;  0x..30: ..sha..  |   (96)
;                                    ;  0x..28: ..dow..  |
;                                    ;  0x..20: .......__|__align32
;                                    ;  0x..18: ==stk==  |
;                                    ;  0x..10: ==sz===--+
%macro PIC_ALLOC 0-1
    %if i386pic
        ASSERT ((stack_size_padded) >= (stack_size))
        %if picb > 0
            %error %strcat(%?, " inside PIC_BEGIN/PIC_END block in ",\
                %str(current_function))
        %elif %sel(1, %[picallocd]) != 0
            %error %strcat(%?, " in non-zero PIC_ALLOC state (",\
                picallocd, "), in ", %str(current_function))
        %endif
        ; Estimate required stack %%wpad (used on WIN64)
        %assign %%wpad 0
        %assign %%nxmmresv 0  ; reserved space for xmm regs
        %assign %%nxmmpush 0  ; actually "pushed" xmm regs
        %if WIN64 && (mmsize != 8)
            %if (stack_size > 0) && (xmm_regs_used > 8)
                %assign %%nxmmresv xmm_regs_used - 8
                %if xmm_regs_used > (8 + high_mm_regs)
                    %assign %%nxmmpush xmm_regs_used - (8 + high_mm_regs)
                %endif
            %elif (stack_size == 0) && (xmm_regs_used > (8 + high_mm_regs))
                %assign %%nxmmresv xmm_regs_used - (8 + high_mm_regs)
                %assign %%nxmmpush xmm_regs_used - (8 + high_mm_regs)
            %endif
        %endif
        %if WIN64 && ((stack_size > 0) || (%%nxmmpush > 0))
            %assign %%wpad 16*%%nxmmresv + 32
        %endif
        ; rpicsave, lpiccache or both:
        %if %0 == 0
            %assign %%qmk 3           ; requested alloc mask
            %assign %%qsz 2*(gprsize) ; requested alloc size
        %elifidn %1,"rpicsave"
            %assign %%qmk 1
            %assign %%qsz 1*(gprsize)
        %elifidn %1,"lpiccache"
            %assign %%qmk 2
            %assign %%qsz 1*(gprsize)
        %else
            %assign %%qmk 0
            %assign %%qsz 0*(gprsize)
            %error %strcat("Invalid ", %?," %1 parameter: ", %1)
        %endif
        %if ((stack_size) > 0) && \
                ((required_stack_alignment) > (STACK_ALIGNMENT))
            ; aligned to reqrd_align and rsp stored in rstkm
            ; TODO: try placing sv/cache (in this order):
            ; - in !!!!!!!-gap, if there's enough space
            ; - inflating !!!!!!!-gap and using it, moving saved xmm
            ;   if necessary
            ; - inflating stack_size area and placing sv/cache area
            ;   near its top
            ;%fatal %strcat(%?, " can't alloc w/rstkm")
            ASSERT 0 == (\
                    ((stack_size_padded)-(stack_size)) &\
                    ((required_stack_alignment)-1)\
                )
            %assign  %%asz    (%%qsz+(required_stack_alignment)-1) &\
                ~((required_stack_alignment)-1)
            %assign  %%szw    (stack_size)+%%wpad   ; stack_size_w_win64pad
            %assign  %%szm    -1                    ; stack_size_w_rstkm
            %assign  %%szp    (stack_size_padded)
            %assign  %%rstkmi -1                    ; rstkm reg_id / -1
            %xdefine %%rstkms %str(rstkm)           ; stringified rstkm
            %xdefine %%rstkml %strlen(%%rstkms)     ; rstkm string length
            ; If rstkm looks like register_name:
            %ifid rstkm
                %ifdef reg_id_of_%[rstkm]
                    %assign %%rstkmi reg_id_of_%[rstkm]
                %endif
                %assign %%szm %%szw
            %endif
            ; If rstkm looks like [memory reference]:
            %if %isidni(%substr(%%rstkms,1,1), "[") && \
                    %isidni(%substr(%%rstkms,%%rstkml,1), "]")
                %xdefine %%rstkmp %substr(%%rstkms, 2, -2) ; strip "[" & "]"
                ; Check rstkm for 1x linearity WRT esp:
                %xdefine %%linear 0 ; false
                %iassign esp      0
                %xdefine %%szm0   %tok(%%rstkmp)
                %ifnum %%szm0
                    %rep 1
                        %xdefine %%linear 0 ; false
                        %iassign esp      esp+gprsize
                        %xdefine %%szm1   %tok(%%rstkmp)
                        %ifnnum %%szm1
                            %exitrep
                        %elif ((%%szm1) - (%%szm0)) != esp
                            %exitrep
                        %endif
                        %xdefine %%linear 1 ; true
                    %endrep
                %endif
                %if %%linear
                    %assign %%szm (%%szm0)+(gprsize)
                %endif
                %undef esp
            %endif
            %xdefine %%err ""
            %if %%szm < 0
                %xdefine %%err "invalid/unsupported rstkm"
            %elif %%szm < %%szw
                %xdefine %%err "stack_size w/rstkm < stack_size[+win64pad]"
            %elif %%szm > (stack_size_padded)
                %xdefine %%err "stack_size w/rstkm > stack_size_padded"
            %elif %%qsz <= ((stack_size_padded) - %%szw) ; %%qsz <= gap
                ; TODO
                ;%xdefine %%err "allocating in gap"
                %assign %%ao2 (gprsize)
                %assign %%ao  2*(gprsize)
                %xdefine picallocd 7,%%qmk,0     ; state,mask,rsp_decrement
                STK_CONTEXT_PUSH_UNDEF ; rsp & stack_size_padded as sym refs:
                %if   %%qmk == 1
                    %xdefine rpicsave  [rsp+stack_size_padded-%%ao2]
                %elif %%qmk == 2
                    %xdefine lpiccache [rsp+stack_size_padded-%%ao2]
                %elif %%qmk == 3
                    %xdefine rpicsave  [rsp+stack_size_padded-%%ao]
                    %xdefine lpiccache [rsp+stack_size_padded-%%ao2]
                %endif
                STK_CONTEXT_POP        ; restore, pop stk_context
            %else
                ; TODO
                ;%xdefine %%err %strcat("inflating stack_size_padded",\
                    " by ", %%asz)
                %assign %%ao2 (stack_size_padded)-(stack_size)+(gprsize)
                %assign %%ao  (stack_size_padded)-(stack_size)+2*(gprsize)
                SUB rsp, %%asz                   ; rsp decremented by %%asz
                %assign stack_size_padded (stack_size_padded)+%%asz
                %xdefine picallocd 8,%%qmk,%%asz ; state,mask,rsp_decrement
                STK_CONTEXT_PUSH_UNDEF ; rsp & stack_size_padded as sym refs:
                %if %%qmk==1
                    %xdefine rpicsave  [rsp+stack_size_padded-%%ao2]
                %elif %%qmk==2
                    %xdefine lpiccache [rsp+stack_size_padded-%%ao2]
                %elif %%qmk==3
                    %xdefine rpicsave  [rsp+stack_size_padded-%%ao]
                    %xdefine lpiccache [rsp+stack_size_padded-%%ao2]
                %endif
                STK_CONTEXT_POP        ; restore, pop stk_context
            %endif
            STK_CONTEXT_PUSH_UNDEF ; push/undef to report sym refs in %error
            %ifnidn %%err, ""
                %error %strcat(\
                    `\n  `, %?, ": ", %%err,\
                    `\n  in `, current_function, "():",\
                    `\n     stack_size: `, %$stack_size,\
                    `\n     stack_size_w_win64pad: `, %%szw,\
                    `\n     stack_size_w_rstkm: `, %%szm,\
                    `\n     stack_size_padded: `, %$stack_size_padded,\
                    `\n     stack_offset: `, %$stack_offset,\
                    `\n     stack_alignment: `,\
                        %$STACK_ALIGNMENT,\
                    `\n     mmsize: `, %$mmsize,\
                    `\n     required_stack_alignment: `,\
                        %$required_stack_alignment,\
                    `\n     rsp: `, %$rsp,\
                    `\n     rstk: `, %$rstk,\
                    `\n     rstkm: `, %$rstkm)
            %endif
            STK_CONTEXT_POP        ; restore, pop stk_context
        %else
            ; aligned to stk_align or not aligned at all
            ASSERT %isidn(rstk, rsp)
            %assign %%asz %cond((STACK_ALIGNMENT) > %%qsz,\
                (STACK_ALIGNMENT), %%qsz)
            %if (stack_size_padded-stack_size-%%wpad) >= %%qsz
                ; !!!!!!!-gap is already large enough to hold %%qsz bytes
                %assign %%ao stack_offset-(stack_size_padded)+%%qsz
                %xdefine picallocd 1,%%qmk,0
            %elif stack_size_padded == 0
                ; no stack_size, no pad, unaligned -- create pad, don't align:
                %assign %%ao stack_offset-(stack_size_padded)+%%qsz
                SUB rsp, %%qsz
                %assign stack_size_padded %%qsz
                %xdefine picallocd 2,%%qmk,%%qsz
            %elif %%nxmmpush == 0
                ; non-empty pad, but no xmm regs to move -- inflate
                ; !!!!!!!-gap at the top of stack pad:
                %assign %%ao stack_offset-(stack_size_padded)+%%qsz
                SUB rsp, %%asz
                %assign stack_size_padded stack_size_padded+%%asz
                %xdefine picallocd 3,%%qmk,%%asz
            %elif stack_size > 0
                ; WIN64, xmm regs pushed, non-empty stack_size area,
                ; rqrd_align <= stk_align -- inflate stack_size, so that xmm
                ; regs are left untouched:
                %assign %%ao stack_offset-(stack_size)+%%qsz
                SUB rsp, %%asz
                %assign stack_size_padded stack_size_padded+%%asz
                %assign stack_size stack_size+%%asz
                %xdefine picallocd 4,%%qmk,%%asz
            %elif required_stack_alignment > STACK_ALIGNMENT
                ; WIN64, nxmmpush > 0, initial stack_size is 0 and inflating it
                ; forces switch to rstk/rstkm model, with unknown at compile
                ; time shift of xmm save area (so xmm regs would need to be
                ; pushed/saved again).
                ; Here we extend wpad and place rpicsave/lpiccache area at its
                ; bottom, temporarily invalidating [rsp+stack_size+32+i*16]
                ; references to xmm save area, until PIC_FREE
                %assign %%ao stack_offset-(stack_size)-32
                SUB rsp, %%asz
                %assign stack_size_padded stack_size_padded+%%asz
                %xdefine picallocd 5,%%qmk,%%asz
            %else ; rqrd_align <= stk_align
                ; WIN64, nxmmpush > 0, initial stack_size==0 but inflating it
                ; won't switch to rstk/rstkm model.
                %assign %%ao stack_offset-(stack_size)+%%qsz
                SUB rsp, %%asz
                %assign stack_size_padded stack_size_padded+%%asz
                %assign stack_size %%asz
                %xdefine picallocd 6,%%qmk,%%asz
            %endif
            ; %%ao is distance from start (bottom) or rpicsave/lpiccache area
            ; to retaddr (return address pushed to stack by caller);
            ; %%ao2 is 1 slot above %%ao, so it's 1 regsize closer to retaddr:
            %assign %%ao2 %%ao-(gprsize)
            ; xdefine rpicsave/lpiccache as macros with 'unexpanded' rstk and
            ; stack_offset parameters (trick is for rstk and stack_offset to be
            ; undefined at the moment when rpicsave/lpiccache are being
            ; xdef-ed: this way it becomes impossible to expand
            ; rstk/stack_offset tokens any further, so they are left as-is):
            STK_CONTEXT_PUSH_UNDEF ; sz/ln, stack_offset/size/padded, rsp/stk/m
            %if   %%qmk == 1
                %xdefine rpicsave  [rstk+stack_offset-%%ao]
            %elif %%qmk == 2
                %xdefine lpiccache [rstk+stack_offset-%%ao]
            %elif %%qmk == 3
                %xdefine rpicsave  [rstk+stack_offset-%%ao]
                %xdefine lpiccache [rstk+stack_offset-%%ao2]
            %endif
            STK_CONTEXT_POP ; sz/ln, stack_offset/size/padded, rsp/stk/m
        %endif
    %endif
%endmacro

%macro PIC_FREE 0
    %if i386pic
        ASSERT (stack_size_padded >= stack_size)
        %if picb > 0
            %error %strcat(%?, " inside PIC_BEGIN/PIC_END block in ",\
                %str(current_function))
        %endif
        %macro %%LIST_LEN 0-*
            %assign %?_result %0
        %endmacro
        %%LIST_LEN picallocd
        %xdefine %%picallocd %sel(1, %[picallocd])
        %if %%LIST_LEN_result == 3
            %xdefine %%decr  %sel(3, %[picallocd]) ; rsp decr/incr
        %else
            %xdefine %%decr  ""
        %endif
        %ifnnum %%picallocd
            %error %strcat(%?, ": invalid PIC_ALLOC state (",\
                picallocd, "), in ", %str(current_function))
        %elifnnum %%decr
            %error %strcat(%?, ": invalid PIC_ALLOC decrement (",\
                picallocd, "), in ", %str(current_function))
        %elif %%picallocd == 1
            ; nothing to do
        %elif %%picallocd == 2
            ADD rsp, %%decr
            %assign stack_size_padded 0
        %elif %%picallocd == 3
            ADD rsp, %%decr
            %assign stack_size_padded stack_size_padded-%%decr
        %elif %%picallocd == 4
            ADD rsp, %%decr
            %assign stack_size_padded stack_size_padded-%%decr
            %assign stack_size        stack_size       -%%decr
        %elif %%picallocd == 5
            ADD rsp, %%decr
            %assign stack_size_padded stack_size_padded-%%decr
        %elif %%picallocd == 6
            ADD rsp, %%decr
            %assign stack_size_padded stack_size_padded-%%decr
            %assign stack_size        0
        %elif %%picallocd == 7
            ; nothing to do
        %elif %%picallocd == 8
            ADD rsp, %%decr
            %assign stack_size_padded stack_size_padded-%%decr
        %else
            %error %strcat(%?, ": invalid PIC_ALLOC state (",\
                picallocd, "), in ", %str(current_function))
        %endif
        %undef   rpicsave
        %undef   lpiccache
        %assign  lpiccf 0
        %xdefine picallocd 0
    %endif
%endmacro

; BRANCH_TARGET xdefines last_branch_adr to point to current location in
; source.
; It's used to manually mark branch target (location/label) before RET macro,
; and if there were some real ops/bytes generated (PIC_END/FREE macros expanded
; or epilogue code inserted) between it and `ret' op, then this `ret' won't get
; prefixed by `rep'.
; Typical usage:
;     ...
; .ret:
;     BRANCH_TARGET
;     PIC_END
;     PIC_FREE
;     RET
; See also: BRANCH_INSTR, RET, AUTO_REP_RET
%macro BRANCH_TARGET 0
    %if notcpuflag(ssse3)
        %%branch_instr equ $
        %xdefine last_branch_adr %%branch_instr
    %endif
%endmacro

; Because x86_64 doesn't support [rip+index_reg*N+offset] addressing mode,
; separate general purpose register needs to be used as base reg for indexed
; PIC memory access. PIC64_LEA helps to initialize rpic64/lpic64 and set
; amd64pic flag for pic() macro to produce rpic64-based address.
%macro PIC64_LEA 2 ; reg, label
    %if ARCH_X86_64
        %xdefine rpic64 %1
        %xdefine lpic64 (%2)
        %assign amd64pic 1
        ;%ifdef PIC ; DEFAULT REL
        ;    lea rpic64, [lpic64]
        ;%else
            lea rpic64, [rip+lpic64-$]
        ;%endif
    %endif
%endmacro

%macro DECLARE_REG_ID 1-*
    %assign %%i 0
    %rep %0
        %xdefine reg_id_of_%1 %%i
        ;%assign %%p2 1<<%%i
        ;%xdefine reg_2p_id_of_%1 %%p2
        %assign %%i %%i+1
        %rotate 1
    %endrep
%endmacro
DECLARE_REG_ID rax, rcx, rdx, rbx, rsp, rbp, rsi, rdi, R8, R9, R10, R11, R12, R13, R14, R15
DECLARE_REG_ID eax, ecx, edx, ebx, esp, ebp, esi, edi, R8d, R9d, R10d, R11d, R12d, R13d, R14d, R15d
DECLARE_REG_ID ax, cx, dx, bx, sp, bp, si, di, R8w, R9w, R10w, R11w, R12w, R13w, R14w, R15w
DECLARE_REG_ID al, cl, dl, bl, spl, bpl, sil, dil, R8b, R9b, R10b, R11b, R12b, R13b, R14b, R15b
DECLARE_REG_ID ah, ch, dh, bh

%macro CHECK_REG_COLLISION_I 3-4 ; reg, arg[i], i, arg[i].word
    %xdefine %%r %1
    %xdefine %%rt %tok(%%r)
    %xdefine %%rs %str(%%rt)
    %xdefine %%rz %%rs
    %if %isnidn(%%r, %%rt) && %isnidn(%%r, %%rs)
        %xdefine %%rz %strcat(%%r, "=", %%rs)
    %endif
    %xdefine %%rid -1
    %ifid %%rt
        %ifdef reg_id_of_%[%%rt]
            %xdefine %%rid reg_id_of_%[%%rt]
        %endif
    %endif

    %xdefine %%a %2
    %xdefine %%at %tok(%%a)
    %xdefine %%as %str(%%at)
    %xdefine %%az %%as
    %if %isnidn(%%a, %%at) && %isnidn(%%a, %%as)
        %xdefine %%az %strcat(%%a, "=", %%as)
    %endif

    %xdefine %%w %%2
    %if %0 >= 4
        %xdefine %%w %4
    %endif
    %xdefine %%wt %tok(%%w)
    %xdefine %%ws %str(%%wt)
    %xdefine %%wid -2
    %ifid %%wt
        %ifdef reg_id_of_%[%%wt]
            %xdefine %%wid reg_id_of_%[%%wt]
        %endif
    %endif

    %if %isidn(%%r, %%w) || %isidn(%%rt, %%wt) || %%rid==%%wid
        %error %strcat(%%rz, " collision with %", %3, ": ", %%az)
    %elif picb > 0
        %if rpicsf && %isempty(rpicsave) && %%wid==reg_id_of_rsp
            ; Modify stack_offset and 'expand' arg[i] again. Then check
            ; if expansion of arg[i] depends on stack_offset or not.
            %xdefine %%so stack_offset
            %assign stack_offset stack_offset-gprsize
            %xdefine %%bt %tok(%%a)
            ; %%at is original expansion of arg[i], %%bt - new one.
            %ifidn %%bt, %%at
                ; If arg[i] expansion doesn't depend on stack_offset, then
                ; PUSH/POP rsp screws it.
                %error %strcat("rpic push/pop collision with %", %3, ": ", %%az)
            %endif
            ; restore stack_offset
            %xdefine stack_offset %%so
        %endif
    %endif
%endmacro

%macro CHECK_REG_COLLISION 1-*  ; reg[, arg1[, arg2]...]
    %xdefine %%r %1
    %xdefine %%rt %tok(%%r)
    %ifid %%rt
        %rotate 1
        %assign %%i 1
        %rep %0-1
            %xdefine %%a %1          ; arg[i])
            %xdefine %%at %tok(%%a)  ; tok(arg[i])
            %xdefine %%as %str(%%at) ; str(tok(arg[i]))
            CHECK_REG_COLLISION_I %%r, %%a, %%i
            ; split arg[i] into words and check each one
            %xdefine %%w ""          ; word
            %assign %%j 1
            %rep %strlen(%%as)
                %xdefine %%c %substr(%%as, %%j, 1)       ; char
                %if ("a"<=%%c && %%c<="z") || ("A"<=%%c && %%c<="Z") \
                        || ("0"<=%%c && %%c<="9") \
                        || "_"==%%c || "$"==%%c
                    %xdefine %%w %strcat(%%w, %%c) ; append char to word
                %else
                    %ifnidn %%w, ""
                        CHECK_REG_COLLISION_I %%r, %%a, %%i, %%w
                    %endif
                    %xdefine %%w ""
                %endif
                %assign %%j %%j+1
            %endrep
            %ifnidn %%w, ""
                CHECK_REG_COLLISION_I %%r, %%a, %%i, %%w
            %endif
            %rotate 1
            %assign %%i %%i+1
        %endrep
    %endif
%endmacro

%macro STK_CONTEXT_STORE_UNDEF 0-1 10
    ; 1. gprsize
    %ifdef gprsize
        %xdefine %$gprsize gprsize
    %endif
    %if (%1) >= 1
        %undef  gprsize
    %endif
    ; 2. STACK_ALIGNMENT
    %ifdef STACK_ALIGNMENT
        %xdefine %$STACK_ALIGNMENT STACK_ALIGNMENT
    %endif
    %if (%1) >= 2
        %undef  STACK_ALIGNMENT
    %endif
    ; 3. mmsize
    %ifdef mmsize
        %xdefine %$mmsize mmsize
    %endif
    %if (%1) >= 3
        %undef  mmsize
    %endif
    ; 4. required_stack_alignment
    %ifdef required_stack_alignment
        %xdefine %$required_stack_alignment required_stack_alignment
    %endif
    %if (%1) >= 4
        %undef  required_stack_alignment
    %endif
    ; 5. stack_offset
    %ifdef stack_offset
        %xdefine %$stack_offset stack_offset
    %endif
    %if (%1) >= 5
        %undef  stack_offset
    %endif
    ; 6. stack_size
    %ifdef stack_size
        %xdefine %$stack_size stack_size
    %endif
    %if (%1) >= 6
        %undef  stack_size
    %endif
    ; 7. stack_size_padded
    %ifdef stack_size_padded
        %xdefine %$stack_size_padded stack_size_padded
    %endif
    %if (%1) >= 7
        %undef  stack_size_padded
    %endif
    ; 8. rsp
    %ifdef rsp
        %xdefine %$rsp rsp
    %endif
    %if (%1) >= 8
        %undef  rsp
    %endif
    ; 9. rstk
    %ifdef rstk
        %xdefine %$rstk rstk
    %endif
    %if (%1) >= 9
        %undef  rstk
    %endif
    ; 10. rstkm
    %ifdef rstkm
        %xdefine %$rstkm rstkm
    %endif
    %if (%1) >= 10
        %undef  rstkm
    %endif
%endmacro
%macro STK_CONTEXT_UNDEF 0-1 10
    %if (%1) >= 1
        %undef  gprsize
    %endif
    %if (%1) >= 2
        %undef  STACK_ALIGNMENT
    %endif
    %if (%1) >= 3
        %undef  mmsize
    %endif
    %if (%1) >= 4
        %undef  required_stack_alignment
    %endif
    %if (%1) >= 5
        %undef  stack_offset
    %endif
    %if (%1) >= 6
        %undef  stack_size
    %endif
    %if (%1) >= 7
        %undef  stack_size_padded
    %endif
    %if (%1) >= 8
        %undef  rsp
    %endif
    %if (%1) >= 9
        %undef  rstk
    %endif
    %if (%1) >= 10
        %undef  rstkm
    %endif
%endmacro
%macro STK_CONTEXT_LOAD 0-1 10 ; shouldn't be used w/o STK_CONTEXT_UNDEF
    ; 10. rstkm
    %if (%1) >= 10
        %ifdef %$rstkm
            %xdefine rstkm %$rstkm
        %endif
    %endif
    ; 9. rstk
    %if (%1) >= 9
        %ifdef %$rstk
            %xdefine rstk %$rstk
        %endif
    %endif
    ; 8. rsp
    %if (%1) >= 8
        %ifdef %$rsp
            %xdefine rsp %$rsp
        %endif
    %endif
    ; 7. stack_size_padded
    %if (%1) >= 7
        %ifdef %$stack_size_padded
            %xdefine stack_size_padded %$stack_size_padded
        %endif
    %endif
    ; 6. stack_size
    %if (%1) >= 6
        %ifdef %$stack_size
            %xdefine stack_size %$stack_size
        %endif
    %endif
    ; 5. stack_offset
    %if (%1) >= 5
        %ifdef %$stack_offset
            %xdefine stack_offset %$stack_offset
        %endif
    %endif
    ; 4. required_stack_alignment
    %if (%1) >= 4
        %ifdef %$required_stack_alignment
            %xdefine required_stack_alignment %$required_stack_alignment
        %endif
    %endif
    ; 3. mmsize
    %if (%1) >= 3
        %ifdef %$mmsize
            %xdefine mmsize %$mmsize
        %endif
    %endif
    ; 2. STACK_ALIGNMENT
    %if (%1) >= 2
        %ifdef %$STACK_ALIGNMENT
            %xdefine STACK_ALIGNMENT %$STACK_ALIGNMENT
        %endif
    %endif
    ; 1. gprsize
    %if (%1) >= 1
        %ifdef %$gprsize
            %xdefine gprsize %$gprsize
        %endif
    %endif
%endmacro
%macro STK_CONTEXT_PUSH_UNDEF 0-1 10
    %push stk_context
    STK_CONTEXT_STORE_UNDEF %1
%endmacro
%macro STK_CONTEXT_POP 0-1 10
    STK_CONTEXT_LOAD %1
    %pop stk_context
%endmacro

; Define GLOBL_LBL to make all labels prefixed by LBL visible in objdump:
%macro LBL 1+
    %ifdef GLOBL_LBL
        %defstr %%s %1
        %assign %%l %strlen(%%s)
        %ifidn %substr(%%s, %%l, 1),":"
            %ifidn %substr(%%s, 1, 1),"."
                ; generate global name in function.label format:
                %xdefine %%g %strcat(\
                    %str(current_function), %substr(%%s, 1, %%l-1))
            %else
                %xdefine %%g %substr(%%s, 1, %%l-1)
            %endif
            global %tok(%%g)
        %endif
    %endif
    %1
%endmacro
; end of PIC macros

%define required_stack_alignment ((mmsize + 15) & ~15)
%define vzeroupper_required (mmsize > 16 && (ARCH_X86_64 == 0 || xmm_regs_used > 16 || notcpuflag(avx512)))
%define high_mm_regs (16*cpuflag(avx512))

; Large stack allocations on Windows need to use stack probing in order
; to guarantee that all stack memory is committed before accessing it.
; This is done by ensuring that the guard page(s) at the end of the
; currently committed pages are touched prior to any pages beyond that.
%if WIN64
    %assign STACK_PROBE_SIZE 8192
%elifidn __OUTPUT_FORMAT__, win32
    %assign STACK_PROBE_SIZE 4096
%else
    %assign STACK_PROBE_SIZE 0
%endif

%macro PROBE_STACK 1 ; stack_size
    %if STACK_PROBE_SIZE
        %assign %%i STACK_PROBE_SIZE
        %rep %1 / STACK_PROBE_SIZE
            mov eax, [rsp-%%i]
            %assign %%i %%i+STACK_PROBE_SIZE
        %endrep
    %endif
%endmacro

%macro ALLOC_STACK 0-2 0, 0 ; stack_size, n_xmm_regs (for win64 only)
    %ifnum %1
        %if %1 != 0
            %assign %%pad 0
            %assign stack_size %1
            %if stack_size < 0
                %assign stack_size -stack_size
            %endif
            %if WIN64
                %assign %%pad %%pad + 32 ; shadow space
                %if mmsize != 8
                    %assign xmm_regs_used %2
                    %if xmm_regs_used > 8
                        %assign %%pad %%pad + (xmm_regs_used-8)*16 ; callee-saved xmm registers
                    %endif
                %endif
            %endif
            %if required_stack_alignment <= STACK_ALIGNMENT
                ; maintain the current stack alignment
                %assign stack_size_padded stack_size + %%pad + ((-%%pad-stack_offset-gprsize) & (STACK_ALIGNMENT-1))
                PROBE_STACK stack_size_padded
                SUB rsp, stack_size_padded
            %else
                %assign %%reg_num (regs_used - 1)
                %xdefine rstk r %+ %%reg_num
                ; align stack, and save original stack location directly above
                ; it, i.e. in [rsp+stack_size_padded], so we can restore the
                ; stack in a single instruction (i.e. mov rsp, rstk or mov
                ; rsp, [rsp+stack_size_padded])
                %if %1 < 0 ; need to store rsp on stack
                    %xdefine rstkm [rsp + stack_size + %%pad]
                    %assign %%pad %%pad + gprsize
                %else ; can keep rsp in rstk during whole function
                    %xdefine rstkm rstk
                %endif
                %assign stack_size_padded stack_size + ((%%pad + required_stack_alignment-1) & ~(required_stack_alignment-1))
                PROBE_STACK stack_size_padded
                mov rstk, rsp
                and rsp, ~(required_stack_alignment-1)
                sub rsp, stack_size_padded
                movifnidn rstkm, rstk
            %endif
            WIN64_PUSH_XMM
        %endif
    %endif
%endmacro

%macro SETUP_STACK_POINTER 0-1 0
    %ifnum %1
        %if %1 != 0 && required_stack_alignment > STACK_ALIGNMENT
            %if %1 > 0
                ; Reserve an additional register for storing the original stack pointer, but avoid using
                ; eax/rax for this purpose since it can potentially get overwritten as a return value.
                %assign regs_used (regs_used + 1)
                %if ARCH_X86_64 && regs_used == 7
                    %assign regs_used 8
                %elif ARCH_X86_64 == 0 && regs_used == 1
                    %assign regs_used 2
                %endif
            %endif
            %if ARCH_X86_64 && regs_used < 5 + UNIX64 * 3
                ; Ensure that we don't clobber any registers containing arguments. For UNIX64 we also preserve r6 (rax)
                ; since it's used as a hidden argument in vararg functions to specify the number of vector registers used.
                %assign regs_used 5 + UNIX64 * 3
            %endif
        %endif
    %endif
%endmacro

%if WIN64 ; Windows x64 ;=================================================

DECLARE_REG 0,  rcx
DECLARE_REG 1,  rdx
DECLARE_REG 2,  R8
DECLARE_REG 3,  R9
DECLARE_REG 4,  R10, 40
DECLARE_REG 5,  R11, 48
DECLARE_REG 6,  rax, 56
DECLARE_REG 7,  rdi, 64
DECLARE_REG 8,  rsi, 72
DECLARE_REG 9,  rbx, 80
DECLARE_REG 10, rbp, 88
DECLARE_REG 11, R14, 96
DECLARE_REG 12, R15, 104
DECLARE_REG 13, R12, 112
DECLARE_REG 14, R13, 120

%macro PROLOGUE 2-5+ 0, 0 ; #args, #regs, #xmm_regs, [stack_size,] arg_names...
    %assign num_args %1
    %assign regs_used %2
    ASSERT regs_used >= num_args
    SETUP_STACK_POINTER %4
    ASSERT regs_used <= 15
    PUSH_IF_USED 7, 8, 9, 10, 11, 12, 13, 14
    ALLOC_STACK %4, %3
    %if mmsize != 8 && stack_size == 0
        WIN64_SPILL_XMM %3
    %endif
    LOAD_IF_USED 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14
    %if %0 > 4
        %ifnum %4
            DEFINE_ARGS %5
        %else
            DEFINE_ARGS %4, %5
        %endif
    %elifnnum %4
        DEFINE_ARGS %4
    %endif
%endmacro

%macro WIN64_PUSH_XMM 0
    ; Use the shadow space to store XMM6 and XMM7, the rest needs stack space allocated.
    %if xmm_regs_used > 6 + high_mm_regs
        movaps [rstk + stack_offset +  8], xmm6
    %endif
    %if xmm_regs_used > 7 + high_mm_regs
        movaps [rstk + stack_offset + 24], xmm7
    %endif
    %assign %%xmm_regs_on_stack xmm_regs_used - high_mm_regs - 8
    %if %%xmm_regs_on_stack > 0
        %assign %%i 8
        %rep %%xmm_regs_on_stack
            movaps [rsp + (%%i-8)*16 + stack_size + 32], xmm %+ %%i
            %assign %%i %%i+1
        %endrep
    %endif
%endmacro

%macro WIN64_SPILL_XMM 1
    %assign xmm_regs_used %1
    ASSERT xmm_regs_used <= 16 + high_mm_regs
    %assign %%xmm_regs_on_stack xmm_regs_used - high_mm_regs - 8
    %if %%xmm_regs_on_stack > 0
        ; Allocate stack space for callee-saved xmm registers plus shadow space and align the stack.
        %assign %%pad %%xmm_regs_on_stack*16 + 32
        %assign stack_size_padded %%pad + ((-%%pad-stack_offset-gprsize) & (STACK_ALIGNMENT-1))
        SUB rsp, stack_size_padded
    %endif
    WIN64_PUSH_XMM
%endmacro

%macro WIN64_RESTORE_XMM_INTERNAL 0
    %assign %%pad_size 0
    %assign %%xmm_regs_on_stack xmm_regs_used - high_mm_regs - 8
    %if %%xmm_regs_on_stack > 0
        %assign %%i xmm_regs_used - high_mm_regs
        %rep %%xmm_regs_on_stack
            %assign %%i %%i-1
            movaps xmm %+ %%i, [rsp + (%%i-8)*16 + stack_size + 32]
        %endrep
    %endif
    %if stack_size_padded > 0
        %if stack_size > 0 && required_stack_alignment > STACK_ALIGNMENT
            mov rsp, rstkm
        %else
            add rsp, stack_size_padded
            %assign %%pad_size stack_size_padded
        %endif
    %endif
    %if xmm_regs_used > 7 + high_mm_regs
        movaps xmm7, [rsp + stack_offset - %%pad_size + 24]
    %endif
    %if xmm_regs_used > 6 + high_mm_regs
        movaps xmm6, [rsp + stack_offset - %%pad_size +  8]
    %endif
%endmacro

%macro WIN64_RESTORE_XMM 0
    WIN64_RESTORE_XMM_INTERNAL
    %assign stack_offset (stack_offset-stack_size_padded)
    %assign stack_size_padded 0
    %assign xmm_regs_used 0
%endmacro

%define has_epilogue regs_used > 7 || stack_size > 0 || vzeroupper_required || xmm_regs_used > 6+high_mm_regs

%macro RET 0
    WIN64_RESTORE_XMM_INTERNAL
    POP_IF_USED 14, 13, 12, 11, 10, 9, 8, 7
    %if vzeroupper_required
        vzeroupper
    %endif
    AUTO_REP_RET
%endmacro

%elif ARCH_X86_64 ; *nix x64 ;=============================================

DECLARE_REG 0,  rdi
DECLARE_REG 1,  rsi
DECLARE_REG 2,  rdx
DECLARE_REG 3,  rcx
DECLARE_REG 4,  R8
DECLARE_REG 5,  R9
DECLARE_REG 6,  rax, 8
DECLARE_REG 7,  R10, 16
DECLARE_REG 8,  R11, 24
DECLARE_REG 9,  rbx, 32
DECLARE_REG 10, rbp, 40
DECLARE_REG 11, R14, 48
DECLARE_REG 12, R15, 56
DECLARE_REG 13, R12, 64
DECLARE_REG 14, R13, 72

%macro PROLOGUE 2-5+ 0, 0 ; #args, #regs, #xmm_regs, [stack_size,] arg_names...
    %assign num_args %1
    %assign regs_used %2
    %assign xmm_regs_used %3
    ASSERT regs_used >= num_args
    SETUP_STACK_POINTER %4
    ASSERT regs_used <= 15
    PUSH_IF_USED 9, 10, 11, 12, 13, 14
    ALLOC_STACK %4
    LOAD_IF_USED 6, 7, 8, 9, 10, 11, 12, 13, 14
    %if %0 > 4
        %ifnum %4
            DEFINE_ARGS %5
        %else
            DEFINE_ARGS %4, %5
        %endif
    %elifnnum %4
        DEFINE_ARGS %4
    %endif
%endmacro

%define has_epilogue regs_used > 9 || stack_size > 0 || vzeroupper_required

%macro RET 0
    %if stack_size_padded > 0
        %if stack_size > 0 && required_stack_alignment > STACK_ALIGNMENT
            mov rsp, rstkm
        %else
            add rsp, stack_size_padded
        %endif
    %endif
    POP_IF_USED 14, 13, 12, 11, 10, 9
    %if vzeroupper_required
        vzeroupper
    %endif
    AUTO_REP_RET
%endmacro

%else ; X86_32 ;==============================================================

DECLARE_REG 0, eax, 4
DECLARE_REG 1, ecx, 8
DECLARE_REG 2, edx, 12
DECLARE_REG 3, ebx, 16
DECLARE_REG 4, esi, 20
DECLARE_REG 5, edi, 24
DECLARE_REG 6, ebp, 28
%define rsp esp

%macro DECLARE_ARG 1-*
    %rep %0
        %define r%1m [rstk + stack_offset + 4*%1 + 4]
        %define r%1mp dword r%1m
        %rotate 1
    %endrep
%endmacro

DECLARE_ARG 7, 8, 9, 10, 11, 12, 13, 14

%macro PROLOGUE 2-5+ 0, 0 ; #args, #regs, #xmm_regs, [stack_size,] arg_names...
    %assign num_args %1
    %assign regs_used %2
    ASSERT regs_used >= num_args
    %if num_args > 7
        %assign num_args 7
    %endif
    %if regs_used > 7
        %assign regs_used 7
    %endif
    SETUP_STACK_POINTER %4
    ASSERT regs_used <= 7
    PUSH_IF_USED 3, 4, 5, 6
    ALLOC_STACK %4
    LOAD_IF_USED 0, 1, 2, 3, 4, 5, 6
    %if %0 > 4
        %ifnum %4
            DEFINE_ARGS %5
        %else
            DEFINE_ARGS %4, %5
        %endif
    %elifnnum %4
        DEFINE_ARGS %4
    %endif
%endmacro

%define has_epilogue regs_used > 3 || stack_size > 0 || vzeroupper_required

%macro RET 0
    %if stack_size_padded > 0
        %if stack_size > 0 && required_stack_alignment > STACK_ALIGNMENT
            mov rsp, rstkm
        %else
            add rsp, stack_size_padded
        %endif
    %endif
    POP_IF_USED 6, 5, 4, 3
    %if vzeroupper_required
        vzeroupper
    %endif
    AUTO_REP_RET
%endmacro

%endif ;======================================================================

%if WIN64 == 0
    %macro WIN64_SPILL_XMM 1
    %endmacro
    %macro WIN64_RESTORE_XMM_INTERNAL 0
    %endmacro
    %macro WIN64_RESTORE_XMM 0
    %endmacro
    %macro WIN64_PUSH_XMM 0
    %endmacro
%endif

; On AMD cpus <=K10, an ordinary ret is slow if it immediately follows either
; a branch or a branch target. So switch to a 2-byte form of ret in that case.
; We can automatically detect "follows a branch", but not a branch target.
; (SSSE3 is a sufficient condition to know that your cpu doesn't have this problem.)
%define last_branch_adr $$
%macro AUTO_REP_RET 0
    %if picb != 0
        %error %strcat("unbalanced PIC_BEGIN/PIC_END (", picb,\
            ") at end of ", %str(current_function))
        %assign picb 0 ; silence further PIC error messages
    %endif
    %if %sel(1, %[picallocd]) != 0
        %error %strcat("invalid PIC_ALLOC state (", picallocd,\
            ") at end of ", %str(current_function))
        %xdefine picallocd 0 ; silence further PIC error messages
    %endif
    %if notcpuflag(ssse3)
        times ((last_branch_adr-$)>>31)+1 rep ; times 1 iff $ == last_branch_adr.
    %endif
    ret
    annotate_function_size
%endmacro

%macro BRANCH_INSTR 0-*
    %rep %0
        %macro %1 1-2 %1
            %2 %1
            %if notcpuflag(ssse3)
                %%branch_instr equ $
                %xdefine last_branch_adr %%branch_instr
            %endif
        %endmacro
        %rotate 1
    %endrep
%endmacro

BRANCH_INSTR jz, je, jnz, jne, jl, jle, jnl, jnle, jg, jge, jng, jnge, ja, jae, jna, jnae, jb, jbe, jnb, jnbe, jc, jnc, js, jns, jo, jno, jp, jnp

%macro TAIL_CALL 1-2 1 ; callee, is_nonadjacent
    %if has_epilogue
        call %1
        RET
    %elif %2
        jmp %1
    %endif
    annotate_function_size
%endmacro

;=============================================================================
; arch-independent part
;=============================================================================

%assign function_align 16

; Begin a function.
; Applies any symbol mangling needed for C linkage, and sets up a define such that
; subsequent uses of the function name automatically refer to the mangled version.
; Appends cpuflags to the function name if cpuflags has been specified.
; The "" empty default parameter is a workaround for nasm, which fails if SUFFIX
; is empty and we call cglobal_internal with just %1 %+ SUFFIX (without %2).
%macro cglobal 1-2+ "" ; name, [PROLOGUE args]
    cglobal_internal 1, %1 %+ SUFFIX, %2
%endmacro
%macro cvisible 1-2+ "" ; name, [PROLOGUE args]
    cglobal_internal 0, %1 %+ SUFFIX, %2
%endmacro
%macro cglobal_internal 2-3+
    %undef num_args
    %undef regs_used
    %undef rpicsave
    %undef lpiccache
    %assign lpiccf 0
    %undef dpic
    %undef dpiclf
    %assign amd64pic 0
    %undef rpic64
    %undef lpic64
    annotate_function_size
    %ifndef cglobaled_%2
        %if %1
            %xdefine %2 mangle(private_prefix %+ _ %+ %2)
        %else
            %xdefine %2 mangle(public_prefix %+ _ %+ %2)
        %endif
        %xdefine %2.skip_prologue %2 %+ .skip_prologue
        CAT_XDEFINE cglobaled_, %2, 1
    %endif
    %xdefine current_function %2
    %xdefine current_function_section __SECT__
    %if FORMAT_ELF
        %if %1
            global %2:function hidden
        %else
            global %2:function
        %endif
    %elif FORMAT_MACHO && HAVE_PRIVATE_EXTERN && %1
        global %2:private_extern
    %else
        global %2
    %endif
    align function_align
    %2:
    %if picb != 0
        %error %strcat("unbalanced PIC_BEGIN/PIC_END (", picb,\
            ") at start of ", %str(current_function))
        %assign picb 0 ; silence further PIC error messages
    %endif
    %if %sel(1, %[picallocd]) != 0
        %error %strcat("invalid PIC_ALLOC state (", picallocd,\
            ") at start of ", %str(current_function))
        %xdefine picallocd 0 ; silence further PIC error messages
    %endif
    RESET_MM_PERMUTATION        ; needed for x86-64, also makes disassembly somewhat nicer
    %xdefine rstk rsp           ; copy of the original stack pointer, used when greater alignment than the known stack alignment is required
    %assign stack_offset 0      ; stack pointer offset relative to the return address
    %assign stack_size 0        ; amount of stack space that can be freely used inside a function
    %assign stack_size_padded 0 ; total amount of allocated stack space, including space for callee-saved xmm registers on WIN64 and alignment padding
    %assign xmm_regs_used 0     ; number of XMM registers requested, used for dealing with callee-saved registers on WIN64 and vzeroupper
    DEFINE_ARGS ; DEFINE_ARGS without params undefines previous args
    %ifnidn %3, ""
        PROLOGUE %3
    %endif
%endmacro

; Create a global symbol from a local label with the correct name mangling and type
%macro cglobal_label 1
    %if FORMAT_ELF
        global current_function %+ %1:function hidden
    %elif FORMAT_MACHO && HAVE_PRIVATE_EXTERN
        global current_function %+ %1:private_extern
    %else
        global current_function %+ %1
    %endif
    %1:
%endmacro

%macro cextern 1
    %xdefine %1 mangle(private_prefix %+ _ %+ %1)
    CAT_XDEFINE cglobaled_, %1, 1
    extern %1
%endmacro

; like cextern, but without the prefix
%macro cextern_naked 1
    %ifdef PREFIX
        %xdefine %1 mangle(%1)
    %endif
    CAT_XDEFINE cglobaled_, %1, 1
    extern %1
%endmacro

%macro const 1-2+
    %xdefine %1 mangle(private_prefix %+ _ %+ %1)
    %if FORMAT_ELF
        global %1:data hidden
    %elif FORMAT_MACHO && HAVE_PRIVATE_EXTERN
        global %1:private_extern
    %else
        global %1
    %endif
    %1: %2
%endmacro

; This is needed for ELF, otherwise the GNU linker assumes the stack is executable by default.
%if FORMAT_ELF
    [SECTION .note.GNU-stack noalloc noexec nowrite progbits]
%endif

; Tell debuggers how large the function was.
; This may be invoked multiple times per function; we rely on later instances overriding earlier ones.
; This is invoked by RET and similar macros, and also cglobal does it for the previous function,
; but if the last function in a source file doesn't use any of the standard macros for its epilogue,
; then its size might be unspecified.
%macro annotate_function_size 0
    %ifdef __YASM_VER__
        %ifdef current_function
            %if FORMAT_ELF
                current_function_section
                %%ecf equ $
                size current_function %%ecf - current_function
                __SECT__
            %endif
        %endif
    %endif
%endmacro

; cpuflags

%assign cpuflags_mmx      (1<<0)
%assign cpuflags_mmx2     (1<<1) | cpuflags_mmx
%assign cpuflags_3dnow    (1<<2) | cpuflags_mmx
%assign cpuflags_3dnowext (1<<3) | cpuflags_3dnow
%assign cpuflags_sse      (1<<4) | cpuflags_mmx2
%assign cpuflags_sse2     (1<<5) | cpuflags_sse
%assign cpuflags_sse2slow (1<<6) | cpuflags_sse2
%assign cpuflags_lzcnt    (1<<7) | cpuflags_sse2
%assign cpuflags_sse3     (1<<8) | cpuflags_sse2
%assign cpuflags_ssse3    (1<<9) | cpuflags_sse3
%assign cpuflags_sse4     (1<<10)| cpuflags_ssse3
%assign cpuflags_sse42    (1<<11)| cpuflags_sse4
%assign cpuflags_aesni    (1<<12)| cpuflags_sse42
%assign cpuflags_gfni     (1<<13)| cpuflags_sse42
%assign cpuflags_avx      (1<<14)| cpuflags_sse42
%assign cpuflags_xop      (1<<15)| cpuflags_avx
%assign cpuflags_fma4     (1<<16)| cpuflags_avx
%assign cpuflags_fma3     (1<<17)| cpuflags_avx
%assign cpuflags_bmi1     (1<<18)| cpuflags_avx|cpuflags_lzcnt
%assign cpuflags_bmi2     (1<<19)| cpuflags_bmi1
%assign cpuflags_avx2     (1<<20)| cpuflags_fma3|cpuflags_bmi2
%assign cpuflags_avx512   (1<<21)| cpuflags_avx2 ; F, CD, BW, DQ, VL

%assign cpuflags_cache32  (1<<22)
%assign cpuflags_cache64  (1<<23)
%assign cpuflags_aligned  (1<<24) ; not a cpu feature, but a function variant
%assign cpuflags_atom     (1<<25)

; Returns a boolean value expressing whether or not the specified cpuflag is enabled.
%define    cpuflag(x) (((((cpuflags & (cpuflags_ %+ x)) ^ (cpuflags_ %+ x)) - 1) >> 31) & 1)
%define notcpuflag(x) (cpuflag(x) ^ 1)

; Takes an arbitrary number of cpuflags from the above list.
; All subsequent functions (up to the next INIT_CPUFLAGS) is built for the specified cpu.
; You shouldn't need to invoke this macro directly, it's a subroutine for INIT_MMX &co.
%macro INIT_CPUFLAGS 0-*
    %xdefine SUFFIX
    %undef cpuname
    %assign cpuflags 0

    %if %0 >= 1
        %rep %0
            %ifdef cpuname
                %xdefine cpuname cpuname %+ _%1
            %else
                %xdefine cpuname %1
            %endif
            %assign cpuflags cpuflags | cpuflags_%1
            %rotate 1
        %endrep
        %xdefine SUFFIX _ %+ cpuname

        %if cpuflag(avx)
            %assign avx_enabled 1
        %endif
        %if (mmsize == 16 && notcpuflag(sse2)) || (mmsize == 32 && notcpuflag(avx2))
            %define mova movaps
            %define movu movups
            %define movnta movntps
        %endif
        %if cpuflag(aligned)
            %define movu mova
        %elif cpuflag(sse3) && notcpuflag(ssse3)
            %define movu lddqu
        %endif
    %endif

    %if ARCH_X86_64 || cpuflag(sse2)
        %ifdef __NASM_VER__
            ALIGNMODE p6
        %else
            CPU amdnop
        %endif
    %else
        %ifdef __NASM_VER__
            ALIGNMODE nop
        %else
            CPU basicnop
        %endif
    %endif
%endmacro

; Merge mmx, sse*, and avx*
; m# is a simd register of the currently selected size
; xm# is the corresponding xmm register if mmsize >= 16, otherwise the same as m#
; ym# is the corresponding ymm register if mmsize >= 32, otherwise the same as m#
; zm# is the corresponding zmm register if mmsize >= 64, otherwise the same as m#
; (All 4 remain in sync through SWAP.)

%macro CAT_XDEFINE 3
    %xdefine %1%2 %3
%endmacro

%macro CAT_UNDEF 2
    %undef %1%2
%endmacro

%macro DEFINE_MMREGS 1 ; mmtype
    %assign %%prev_mmregs 0
    %ifdef num_mmregs
        %assign %%prev_mmregs num_mmregs
    %endif

    %assign num_mmregs 8
    %if ARCH_X86_64 && mmsize >= 16
        %assign num_mmregs 16
        %if cpuflag(avx512) || mmsize == 64
            %assign num_mmregs 32
        %endif
    %endif

    %assign %%i 0
    %rep num_mmregs
        CAT_XDEFINE m, %%i, %1 %+ %%i
        CAT_XDEFINE nn%1, %%i, %%i
        %assign %%i %%i+1
    %endrep
    %if %%prev_mmregs > num_mmregs
        %rep %%prev_mmregs - num_mmregs
            CAT_UNDEF m, %%i
            CAT_UNDEF nn %+ mmtype, %%i
            %assign %%i %%i+1
        %endrep
    %endif
    %xdefine mmtype %1
%endmacro

; Prefer registers 16-31 over 0-15 to avoid having to use vzeroupper
%macro AVX512_MM_PERMUTATION 0-1 0 ; start_reg
    %if ARCH_X86_64 && cpuflag(avx512)
        %assign %%i %1
        %rep 16-%1
            %assign %%i_high %%i+16
            SWAP %%i, %%i_high
            %assign %%i %%i+1
        %endrep
    %endif
%endmacro

%macro INIT_MMX 0-1+
    %assign avx_enabled 0
    %define RESET_MM_PERMUTATION INIT_MMX %1
    %define mmsize 8
    %define mova movq
    %define movu movq
    %define movh movd
    %define movnta movntq
    INIT_CPUFLAGS %1
    DEFINE_MMREGS mm
%endmacro

%macro INIT_XMM 0-1+
    %assign avx_enabled FORCE_VEX_ENCODING
    %define RESET_MM_PERMUTATION INIT_XMM %1
    %define mmsize 16
    %define mova movdqa
    %define movu movdqu
    %define movh movq
    %define movnta movntdq
    INIT_CPUFLAGS %1
    DEFINE_MMREGS xmm
    %if WIN64
        AVX512_MM_PERMUTATION 6 ; Swap callee-saved registers with volatile registers
    %endif
%endmacro

%macro INIT_YMM 0-1+
    %assign avx_enabled 1
    %define RESET_MM_PERMUTATION INIT_YMM %1
    %define mmsize 32
    %define mova movdqa
    %define movu movdqu
    %undef movh
    %define movnta movntdq
    INIT_CPUFLAGS %1
    DEFINE_MMREGS ymm
    AVX512_MM_PERMUTATION
%endmacro

%macro INIT_ZMM 0-1+
    %assign avx_enabled 1
    %define RESET_MM_PERMUTATION INIT_ZMM %1
    %define mmsize 64
    %define mova movdqa
    %define movu movdqu
    %undef movh
    %define movnta movntdq
    INIT_CPUFLAGS %1
    DEFINE_MMREGS zmm
    AVX512_MM_PERMUTATION
%endmacro

INIT_XMM

%macro DECLARE_MMCAST 1
    %define  mmmm%1   mm%1
    %define  mmxmm%1  mm%1
    %define  mmymm%1  mm%1
    %define  mmzmm%1  mm%1
    %define xmmmm%1   mm%1
    %define xmmxmm%1 xmm%1
    %define xmmymm%1 xmm%1
    %define xmmzmm%1 xmm%1
    %define ymmmm%1   mm%1
    %define ymmxmm%1 xmm%1
    %define ymmymm%1 ymm%1
    %define ymmzmm%1 ymm%1
    %define zmmmm%1   mm%1
    %define zmmxmm%1 xmm%1
    %define zmmymm%1 ymm%1
    %define zmmzmm%1 zmm%1
    %define xm%1 xmm %+ m%1
    %define ym%1 ymm %+ m%1
    %define zm%1 zmm %+ m%1
%endmacro

%assign i 0
%rep 32
    DECLARE_MMCAST i
    %assign i i+1
%endrep

; I often want to use macros that permute their arguments. e.g. there's no
; efficient way to implement butterfly or transpose or dct without swapping some
; arguments.
;
; I would like to not have to manually keep track of the permutations:
; If I insert a permutation in the middle of a function, it should automatically
; change everything that follows. For more complex macros I may also have multiple
; implementations, e.g. the SSE2 and SSSE3 versions may have different permutations.
;
; Hence these macros. Insert a PERMUTE or some SWAPs at the end of a macro that
; permutes its arguments. It's equivalent to exchanging the contents of the
; registers, except that this way you exchange the register names instead, so it
; doesn't cost any cycles.

%macro PERMUTE 2-* ; takes a list of pairs to swap
    %rep %0/2
        %xdefine %%tmp%2 m%2
        %rotate 2
    %endrep
    %rep %0/2
        %xdefine m%1 %%tmp%2
        CAT_XDEFINE nn, m%1, %1
        %rotate 2
    %endrep
%endmacro

%macro SWAP 2+ ; swaps a single chain (sometimes more concise than pairs)
    %ifnum %1 ; SWAP 0, 1, ...
        SWAP_INTERNAL_NUM %1, %2
    %else ; SWAP m0, m1, ...
        SWAP_INTERNAL_NAME %1, %2
    %endif
%endmacro

%macro SWAP_INTERNAL_NUM 2-*
    %rep %0-1
        %xdefine %%tmp m%1
        %xdefine m%1 m%2
        %xdefine m%2 %%tmp
        CAT_XDEFINE nn, m%1, %1
        CAT_XDEFINE nn, m%2, %2
        %rotate 1
    %endrep
%endmacro

%macro SWAP_INTERNAL_NAME 2-*
    %xdefine %%args nn %+ %1
    %rep %0-1
        %xdefine %%args %%args, nn %+ %2
        %rotate 1
    %endrep
    SWAP_INTERNAL_NUM %%args
%endmacro

; If SAVE_MM_PERMUTATION is placed at the end of a function, then any later
; calls to that function will automatically load the permutation, so values can
; be returned in mmregs.
%macro SAVE_MM_PERMUTATION 0-1
    %if %0
        %xdefine %%f %1_m
    %else
        %xdefine %%f current_function %+ _m
    %endif
    %assign %%i 0
    %rep num_mmregs
        %xdefine %%tmp m %+ %%i
        CAT_XDEFINE %%f, %%i, regnumof %+ %%tmp
        %assign %%i %%i+1
    %endrep
%endmacro

%macro LOAD_MM_PERMUTATION 0-1 ; name to load from
    %if %0
        %xdefine %%f %1_m
    %else
        %xdefine %%f current_function %+ _m
    %endif
    %xdefine %%tmp %%f %+ 0
    %ifnum %%tmp
        DEFINE_MMREGS mmtype
        %assign %%i 0
        %rep num_mmregs
            %xdefine %%tmp %%f %+ %%i
            CAT_XDEFINE %%m, %%i, m %+ %%tmp
            %assign %%i %%i+1
        %endrep
        %rep num_mmregs
            %assign %%i %%i-1
            CAT_XDEFINE m, %%i, %%m %+ %%i
            CAT_XDEFINE nn, m %+ %%i, %%i
        %endrep
    %endif
%endmacro

; Append cpuflags to the callee's name iff the appended name is known and the plain name isn't
%macro call 1
    %ifid %1
        call_internal %1 %+ SUFFIX, %1
    %else
        call %1
    %endif
%endmacro
%macro call_internal 2
    %xdefine %%i %2
    %ifndef cglobaled_%2
        %ifdef cglobaled_%1
            %xdefine %%i %1
        %endif
    %endif
    call %%i
    LOAD_MM_PERMUTATION %%i
%endmacro

; Substitutions that reduce instruction size but are functionally equivalent
%macro add 2
    %ifnum %2
        %if %2==128
            sub %1, -128
        %else
            add %1, %2
        %endif
    %else
        add %1, %2
    %endif
%endmacro

%macro sub 2
    %ifnum %2
        %if %2==128
            add %1, -128
        %else
            sub %1, %2
        %endif
    %else
        sub %1, %2
    %endif
%endmacro

;=============================================================================
; AVX abstraction layer
;=============================================================================

%assign i 0
%rep 32
    %if i < 8
        CAT_XDEFINE sizeofmm, i, 8
        CAT_XDEFINE regnumofmm, i, i
    %endif
    CAT_XDEFINE sizeofxmm, i, 16
    CAT_XDEFINE sizeofymm, i, 32
    CAT_XDEFINE sizeofzmm, i, 64
    CAT_XDEFINE regnumofxmm, i, i
    CAT_XDEFINE regnumofymm, i, i
    CAT_XDEFINE regnumofzmm, i, i
    %assign i i+1
%endrep
%undef i

%macro CHECK_AVX_INSTR_EMU 3-*
    %xdefine %%opcode %1
    %xdefine %%dst %2
    %rep %0-2
        %ifidn %%dst, %3
            %error non-avx emulation of ``%%opcode'' is not supported
        %endif
        %rotate 1
    %endrep
%endmacro

;%1 == instruction
;%2 == minimal instruction set
;%3 == 1 if float, 0 if int
;%4 == 1 if 4-operand emulation, 0 if 3-operand emulation, 255 otherwise (no emulation)
;%5 == 1 if commutative (i.e. doesn't matter which src arg is which), 0 if not
;%6+: operands
%macro RUN_AVX_INSTR 6-9+
    %ifnum sizeof%7
        %assign __sizeofreg sizeof%7
    %elifnum sizeof%6
        %assign __sizeofreg sizeof%6
    %else
        %assign __sizeofreg mmsize
    %endif
    %assign __emulate_avx 0
    %if avx_enabled && __sizeofreg >= 16
        %xdefine __instr v%1
    %else
        %xdefine __instr %1
        %if %0 >= 8+%4
            %assign __emulate_avx 1
        %endif
    %endif
    %ifnidn %2, fnord
        %ifdef cpuname
            %if notcpuflag(%2)
                %error use of ``%1'' %2 instruction in cpuname function: current_function
            %elif %3 == 0 && __sizeofreg == 16 && notcpuflag(sse2)
                %error use of ``%1'' sse2 instruction in cpuname function: current_function
            %elif %3 == 0 && __sizeofreg == 32 && notcpuflag(avx2)
                %error use of ``%1'' avx2 instruction in cpuname function: current_function
            %elif __sizeofreg == 16 && notcpuflag(sse)
                %error use of ``%1'' sse instruction in cpuname function: current_function
            %elif __sizeofreg == 32 && notcpuflag(avx)
                %error use of ``%1'' avx instruction in cpuname function: current_function
            %elif __sizeofreg == 64 && notcpuflag(avx512)
                %error use of ``%1'' avx512 instruction in cpuname function: current_function
            %elifidn %1, pextrw ; special case because the base instruction is mmx2,
                %ifnid %6       ; but sse4 is required for memory operands
                    %if notcpuflag(sse4)
                        %error use of ``%1'' sse4 instruction in cpuname function: current_function
                    %endif
                %endif
            %endif
        %endif
    %endif

    %if __emulate_avx
        %xdefine __src1 %7
        %xdefine __src2 %8
        %if %5 && %4 == 0
            %ifnidn %6, %7
                %ifidn %6, %8
                    %xdefine __src1 %8
                    %xdefine __src2 %7
                %elifnnum sizeof%8
                    ; 3-operand AVX instructions with a memory arg can only have it in src2,
                    ; whereas SSE emulation prefers to have it in src1 (i.e. the mov).
                    ; So, if the instruction is commutative with a memory arg, swap them.
                    %xdefine __src1 %8
                    %xdefine __src2 %7
                %endif
            %endif
        %endif
        %ifnidn %6, __src1
            %if %0 >= 9
                CHECK_AVX_INSTR_EMU {%1 %6, %7, %8, %9}, %6, __src2, %9
            %else
                CHECK_AVX_INSTR_EMU {%1 %6, %7, %8}, %6, __src2
            %endif
            %if __sizeofreg == 8
                MOVQ %6, __src1
            %elif %3
                MOVAPS %6, __src1
            %else
                MOVDQA %6, __src1
            %endif
        %endif
        %if %0 >= 9
            %1 %6, __src2, %9
        %else
            %1 %6, __src2
        %endif
    %elif %0 >= 9
        %if avx_enabled && __sizeofreg >= 16 && %4 == 1
            %ifnnum regnumof%7
                %if %3
                    vmovaps %6, %7
                %else
                    vmovdqa %6, %7
                %endif
                __instr %6, %6, %8, %9
            %else
                __instr %6, %7, %8, %9
            %endif
        %else
            __instr %6, %7, %8, %9
        %endif
    %elif %0 == 8
        %if avx_enabled && __sizeofreg >= 16 && %4 == 0
            %xdefine __src1 %7
            %xdefine __src2 %8
            %if %5
                %ifnum regnumof%7
                    %ifnum regnumof%8
                        %if regnumof%7 < 8 && regnumof%8 >= 8 && regnumof%8 < 16 && sizeof%8 <= 32
                            ; Most VEX-encoded instructions require an additional byte to encode when
                            ; src2 is a high register (e.g. m8..15). If the instruction is commutative
                            ; we can swap src1 and src2 when doing so reduces the instruction length.
                            %xdefine __src1 %8
                            %xdefine __src2 %7
                        %endif
                    %endif
                %elifnum regnumof%8 ; put memory operands in src2 when possible
                    %xdefine __src1 %8
                    %xdefine __src2 %7
                %else
                    %assign __emulate_avx 1
                %endif
            %elifnnum regnumof%7
                ; EVEX allows imm8 shift instructions to be used with memory operands,
                ; but VEX does not. This handles those special cases.
                %ifnnum %8
                    %assign __emulate_avx 1
                %elif notcpuflag(avx512)
                    %assign __emulate_avx 1
                %endif
            %endif
            %if __emulate_avx ; a separate load is required
                %if %3
                    vmovaps %6, %7
                %else
                    vmovdqa %6, %7
                %endif
                __instr %6, %6, %8
            %else
                __instr %6, __src1, __src2
            %endif
        %else
            __instr %6, %7, %8
        %endif
    %elif %0 == 7
        %if avx_enabled && __sizeofreg >= 16 && %5
            %xdefine __src1 %6
            %xdefine __src2 %7
            %ifnum regnumof%6
                %ifnum regnumof%7
                    %if regnumof%6 < 8 && regnumof%7 >= 8 && regnumof%7 < 16 && sizeof%7 <= 32
                        %xdefine __src1 %7
                        %xdefine __src2 %6
                    %endif
                %endif
            %endif
            __instr %6, __src1, __src2
        %else
            __instr %6, %7
        %endif
    %else
        __instr %6
    %endif
%endmacro

;%1 == instruction
;%2 == minimal instruction set
;%3 == 1 if float, 0 if int
;%4 == 1 if 4-operand emulation, 0 if 3-operand emulation, 255 otherwise (no emulation)
;%5 == 1 if commutative (i.e. doesn't matter which src arg is which), 0 if not
%macro AVX_INSTR 1-5 fnord, 0, 255, 0
    %macro %1 1-10 fnord, fnord, fnord, fnord, %1, %2, %3, %4, %5
        %ifidn %2, fnord
            RUN_AVX_INSTR %6, %7, %8, %9, %10, %1
        %elifidn %3, fnord
            RUN_AVX_INSTR %6, %7, %8, %9, %10, %1, %2
        %elifidn %4, fnord
            RUN_AVX_INSTR %6, %7, %8, %9, %10, %1, %2, %3
        %elifidn %5, fnord
            RUN_AVX_INSTR %6, %7, %8, %9, %10, %1, %2, %3, %4
        %else
            RUN_AVX_INSTR %6, %7, %8, %9, %10, %1, %2, %3, %4, %5
        %endif
    %endmacro
%endmacro

; Instructions with both VEX/EVEX and legacy encodings
; Non-destructive instructions are written without parameters
AVX_INSTR addpd, sse2, 1, 0, 1
AVX_INSTR addps, sse, 1, 0, 1
AVX_INSTR addsd, sse2, 1, 0, 0
AVX_INSTR addss, sse, 1, 0, 0
AVX_INSTR addsubpd, sse3, 1, 0, 0
AVX_INSTR addsubps, sse3, 1, 0, 0
AVX_INSTR aesdec, aesni, 0, 0, 0
AVX_INSTR aesdeclast, aesni, 0, 0, 0
AVX_INSTR aesenc, aesni, 0, 0, 0
AVX_INSTR aesenclast, aesni, 0, 0, 0
AVX_INSTR aesimc, aesni
AVX_INSTR aeskeygenassist, aesni
AVX_INSTR andnpd, sse2, 1, 0, 0
AVX_INSTR andnps, sse, 1, 0, 0
AVX_INSTR andpd, sse2, 1, 0, 1
AVX_INSTR andps, sse, 1, 0, 1
AVX_INSTR blendpd, sse4, 1, 1, 0
AVX_INSTR blendps, sse4, 1, 1, 0
AVX_INSTR blendvpd, sse4, 1, 1, 0 ; last operand must be xmm0 with legacy encoding
AVX_INSTR blendvps, sse4, 1, 1, 0 ; last operand must be xmm0 with legacy encoding
AVX_INSTR cmpeqpd, sse2, 1, 0, 1
AVX_INSTR cmpeqps, sse, 1, 0, 1
AVX_INSTR cmpeqsd, sse2, 1, 0, 0
AVX_INSTR cmpeqss, sse, 1, 0, 0
AVX_INSTR cmplepd, sse2, 1, 0, 0
AVX_INSTR cmpleps, sse, 1, 0, 0
AVX_INSTR cmplesd, sse2, 1, 0, 0
AVX_INSTR cmpless, sse, 1, 0, 0
AVX_INSTR cmpltpd, sse2, 1, 0, 0
AVX_INSTR cmpltps, sse, 1, 0, 0
AVX_INSTR cmpltsd, sse2, 1, 0, 0
AVX_INSTR cmpltss, sse, 1, 0, 0
AVX_INSTR cmpneqpd, sse2, 1, 0, 1
AVX_INSTR cmpneqps, sse, 1, 0, 1
AVX_INSTR cmpneqsd, sse2, 1, 0, 0
AVX_INSTR cmpneqss, sse, 1, 0, 0
AVX_INSTR cmpnlepd, sse2, 1, 0, 0
AVX_INSTR cmpnleps, sse, 1, 0, 0
AVX_INSTR cmpnlesd, sse2, 1, 0, 0
AVX_INSTR cmpnless, sse, 1, 0, 0
AVX_INSTR cmpnltpd, sse2, 1, 0, 0
AVX_INSTR cmpnltps, sse, 1, 0, 0
AVX_INSTR cmpnltsd, sse2, 1, 0, 0
AVX_INSTR cmpnltss, sse, 1, 0, 0
AVX_INSTR cmpordpd, sse2 1, 0, 1
AVX_INSTR cmpordps, sse 1, 0, 1
AVX_INSTR cmpordsd, sse2 1, 0, 0
AVX_INSTR cmpordss, sse 1, 0, 0
AVX_INSTR cmppd, sse2, 1, 1, 0
AVX_INSTR cmpps, sse, 1, 1, 0
AVX_INSTR cmpsd, sse2, 1, 1, 0
AVX_INSTR cmpss, sse, 1, 1, 0
AVX_INSTR cmpunordpd, sse2, 1, 0, 1
AVX_INSTR cmpunordps, sse, 1, 0, 1
AVX_INSTR cmpunordsd, sse2, 1, 0, 0
AVX_INSTR cmpunordss, sse, 1, 0, 0
AVX_INSTR comisd, sse2, 1
AVX_INSTR comiss, sse, 1
AVX_INSTR cvtdq2pd, sse2, 1
AVX_INSTR cvtdq2ps, sse2, 1
AVX_INSTR cvtpd2dq, sse2, 1
AVX_INSTR cvtpd2ps, sse2, 1
AVX_INSTR cvtps2dq, sse2, 1
AVX_INSTR cvtps2pd, sse2, 1
AVX_INSTR cvtsd2si, sse2, 1
AVX_INSTR cvtsd2ss, sse2, 1, 0, 0
AVX_INSTR cvtsi2sd, sse2, 1, 0, 0
AVX_INSTR cvtsi2ss, sse, 1, 0, 0
AVX_INSTR cvtss2sd, sse2, 1, 0, 0
AVX_INSTR cvtss2si, sse, 1
AVX_INSTR cvttpd2dq, sse2, 1
AVX_INSTR cvttps2dq, sse2, 1
AVX_INSTR cvttsd2si, sse2, 1
AVX_INSTR cvttss2si, sse, 1
AVX_INSTR divpd, sse2, 1, 0, 0
AVX_INSTR divps, sse, 1, 0, 0
AVX_INSTR divsd, sse2, 1, 0, 0
AVX_INSTR divss, sse, 1, 0, 0
AVX_INSTR dppd, sse4, 1, 1, 0
AVX_INSTR dpps, sse4, 1, 1, 0
AVX_INSTR extractps, sse4, 1
AVX_INSTR gf2p8affineinvqb, gfni, 0, 1, 0
AVX_INSTR gf2p8affineqb, gfni, 0, 1, 0
AVX_INSTR gf2p8mulb, gfni, 0, 0, 0
AVX_INSTR haddpd, sse3, 1, 0, 0
AVX_INSTR haddps, sse3, 1, 0, 0
AVX_INSTR hsubpd, sse3, 1, 0, 0
AVX_INSTR hsubps, sse3, 1, 0, 0
AVX_INSTR insertps, sse4, 1, 1, 0
AVX_INSTR lddqu, sse3
AVX_INSTR ldmxcsr, sse, 1
AVX_INSTR maskmovdqu, sse2
AVX_INSTR maxpd, sse2, 1, 0, 1
AVX_INSTR maxps, sse, 1, 0, 1
AVX_INSTR maxsd, sse2, 1, 0, 0
AVX_INSTR maxss, sse, 1, 0, 0
AVX_INSTR minpd, sse2, 1, 0, 1
AVX_INSTR minps, sse, 1, 0, 1
AVX_INSTR minsd, sse2, 1, 0, 0
AVX_INSTR minss, sse, 1, 0, 0
AVX_INSTR movapd, sse2, 1
AVX_INSTR movaps, sse, 1
AVX_INSTR movd, mmx
AVX_INSTR movddup, sse3, 1
AVX_INSTR movdqa, sse2
AVX_INSTR movdqu, sse2
AVX_INSTR movhlps, sse, 1, 0, 0
AVX_INSTR movhpd, sse2, 1, 0, 0
AVX_INSTR movhps, sse, 1, 0, 0
AVX_INSTR movlhps, sse, 1, 0, 0
AVX_INSTR movlpd, sse2, 1, 0, 0
AVX_INSTR movlps, sse, 1, 0, 0
AVX_INSTR movmskpd, sse2, 1
AVX_INSTR movmskps, sse, 1
AVX_INSTR movntdq, sse2
AVX_INSTR movntdqa, sse4
AVX_INSTR movntpd, sse2, 1
AVX_INSTR movntps, sse, 1
AVX_INSTR movq, mmx
AVX_INSTR movsd, sse2, 1, 0, 0
AVX_INSTR movshdup, sse3, 1
AVX_INSTR movsldup, sse3, 1
AVX_INSTR movss, sse, 1, 0, 0
AVX_INSTR movupd, sse2, 1
AVX_INSTR movups, sse, 1
AVX_INSTR mpsadbw, sse4, 0, 1, 0
AVX_INSTR mulpd, sse2, 1, 0, 1
AVX_INSTR mulps, sse, 1, 0, 1
AVX_INSTR mulsd, sse2, 1, 0, 0
AVX_INSTR mulss, sse, 1, 0, 0
AVX_INSTR orpd, sse2, 1, 0, 1
AVX_INSTR orps, sse, 1, 0, 1
AVX_INSTR pabsb, ssse3
AVX_INSTR pabsd, ssse3
AVX_INSTR pabsw, ssse3
AVX_INSTR packsswb, mmx, 0, 0, 0
AVX_INSTR packssdw, mmx, 0, 0, 0
AVX_INSTR packuswb, mmx, 0, 0, 0
AVX_INSTR packusdw, sse4, 0, 0, 0
AVX_INSTR paddb, mmx, 0, 0, 1
AVX_INSTR paddw, mmx, 0, 0, 1
AVX_INSTR paddd, mmx, 0, 0, 1
AVX_INSTR paddq, sse2, 0, 0, 1
AVX_INSTR paddsb, mmx, 0, 0, 1
AVX_INSTR paddsw, mmx, 0, 0, 1
AVX_INSTR paddusb, mmx, 0, 0, 1
AVX_INSTR paddusw, mmx, 0, 0, 1
AVX_INSTR palignr, ssse3, 0, 1, 0
AVX_INSTR pand, mmx, 0, 0, 1
AVX_INSTR pandn, mmx, 0, 0, 0
AVX_INSTR pavgb, mmx2, 0, 0, 1
AVX_INSTR pavgw, mmx2, 0, 0, 1
AVX_INSTR pblendvb, sse4, 0, 1, 0 ; last operand must be xmm0 with legacy encoding
AVX_INSTR pblendw, sse4, 0, 1, 0
AVX_INSTR pclmulqdq, fnord, 0, 1, 0
AVX_INSTR pclmulhqhqdq, fnord, 0, 0, 0
AVX_INSTR pclmulhqlqdq, fnord, 0, 0, 0
AVX_INSTR pclmullqhqdq, fnord, 0, 0, 0
AVX_INSTR pclmullqlqdq, fnord, 0, 0, 0
AVX_INSTR pcmpestri, sse42
AVX_INSTR pcmpestrm, sse42
AVX_INSTR pcmpistri, sse42
AVX_INSTR pcmpistrm, sse42
AVX_INSTR pcmpeqb, mmx, 0, 0, 1
AVX_INSTR pcmpeqw, mmx, 0, 0, 1
AVX_INSTR pcmpeqd, mmx, 0, 0, 1
AVX_INSTR pcmpeqq, sse4, 0, 0, 1
AVX_INSTR pcmpgtb, mmx, 0, 0, 0
AVX_INSTR pcmpgtw, mmx, 0, 0, 0
AVX_INSTR pcmpgtd, mmx, 0, 0, 0
AVX_INSTR pcmpgtq, sse42, 0, 0, 0
AVX_INSTR pextrb, sse4
AVX_INSTR pextrd, sse4
AVX_INSTR pextrq, sse4
AVX_INSTR pextrw, mmx2
AVX_INSTR phaddw, ssse3, 0, 0, 0
AVX_INSTR phaddd, ssse3, 0, 0, 0
AVX_INSTR phaddsw, ssse3, 0, 0, 0
AVX_INSTR phminposuw, sse4
AVX_INSTR phsubw, ssse3, 0, 0, 0
AVX_INSTR phsubd, ssse3, 0, 0, 0
AVX_INSTR phsubsw, ssse3, 0, 0, 0
AVX_INSTR pinsrb, sse4, 0, 1, 0
AVX_INSTR pinsrd, sse4, 0, 1, 0
AVX_INSTR pinsrq, sse4, 0, 1, 0
AVX_INSTR pinsrw, mmx2, 0, 1, 0
AVX_INSTR pmaddwd, mmx, 0, 0, 1
AVX_INSTR pmaddubsw, ssse3, 0, 0, 0
AVX_INSTR pmaxsb, sse4, 0, 0, 1
AVX_INSTR pmaxsw, mmx2, 0, 0, 1
AVX_INSTR pmaxsd, sse4, 0, 0, 1
AVX_INSTR pmaxub, mmx2, 0, 0, 1
AVX_INSTR pmaxuw, sse4, 0, 0, 1
AVX_INSTR pmaxud, sse4, 0, 0, 1
AVX_INSTR pminsb, sse4, 0, 0, 1
AVX_INSTR pminsw, mmx2, 0, 0, 1
AVX_INSTR pminsd, sse4, 0, 0, 1
AVX_INSTR pminub, mmx2, 0, 0, 1
AVX_INSTR pminuw, sse4, 0, 0, 1
AVX_INSTR pminud, sse4, 0, 0, 1
AVX_INSTR pmovmskb, mmx2
AVX_INSTR pmovsxbw, sse4
AVX_INSTR pmovsxbd, sse4
AVX_INSTR pmovsxbq, sse4
AVX_INSTR pmovsxwd, sse4
AVX_INSTR pmovsxwq, sse4
AVX_INSTR pmovsxdq, sse4
AVX_INSTR pmovzxbw, sse4
AVX_INSTR pmovzxbd, sse4
AVX_INSTR pmovzxbq, sse4
AVX_INSTR pmovzxwd, sse4
AVX_INSTR pmovzxwq, sse4
AVX_INSTR pmovzxdq, sse4
AVX_INSTR pmuldq, sse4, 0, 0, 1
AVX_INSTR pmulhrsw, ssse3, 0, 0, 1
AVX_INSTR pmulhuw, mmx2, 0, 0, 1
AVX_INSTR pmulhw, mmx, 0, 0, 1
AVX_INSTR pmullw, mmx, 0, 0, 1
AVX_INSTR pmulld, sse4, 0, 0, 1
AVX_INSTR pmuludq, sse2, 0, 0, 1
AVX_INSTR por, mmx, 0, 0, 1
AVX_INSTR psadbw, mmx2, 0, 0, 1
AVX_INSTR pshufb, ssse3, 0, 0, 0
AVX_INSTR pshufd, sse2
AVX_INSTR pshufhw, sse2
AVX_INSTR pshuflw, sse2
AVX_INSTR psignb, ssse3, 0, 0, 0
AVX_INSTR psignw, ssse3, 0, 0, 0
AVX_INSTR psignd, ssse3, 0, 0, 0
AVX_INSTR psllw, mmx, 0, 0, 0
AVX_INSTR pslld, mmx, 0, 0, 0
AVX_INSTR psllq, mmx, 0, 0, 0
AVX_INSTR pslldq, sse2, 0, 0, 0
AVX_INSTR psraw, mmx, 0, 0, 0
AVX_INSTR psrad, mmx, 0, 0, 0
AVX_INSTR psrlw, mmx, 0, 0, 0
AVX_INSTR psrld, mmx, 0, 0, 0
AVX_INSTR psrlq, mmx, 0, 0, 0
AVX_INSTR psrldq, sse2, 0, 0, 0
AVX_INSTR psubb, mmx, 0, 0, 0
AVX_INSTR psubw, mmx, 0, 0, 0
AVX_INSTR psubd, mmx, 0, 0, 0
AVX_INSTR psubq, sse2, 0, 0, 0
AVX_INSTR psubsb, mmx, 0, 0, 0
AVX_INSTR psubsw, mmx, 0, 0, 0
AVX_INSTR psubusb, mmx, 0, 0, 0
AVX_INSTR psubusw, mmx, 0, 0, 0
AVX_INSTR ptest, sse4
AVX_INSTR punpckhbw, mmx, 0, 0, 0
AVX_INSTR punpckhwd, mmx, 0, 0, 0
AVX_INSTR punpckhdq, mmx, 0, 0, 0
AVX_INSTR punpckhqdq, sse2, 0, 0, 0
AVX_INSTR punpcklbw, mmx, 0, 0, 0
AVX_INSTR punpcklwd, mmx, 0, 0, 0
AVX_INSTR punpckldq, mmx, 0, 0, 0
AVX_INSTR punpcklqdq, sse2, 0, 0, 0
AVX_INSTR pxor, mmx, 0, 0, 1
AVX_INSTR rcpps, sse, 1
AVX_INSTR rcpss, sse, 1, 0, 0
AVX_INSTR roundpd, sse4, 1
AVX_INSTR roundps, sse4, 1
AVX_INSTR roundsd, sse4, 1, 1, 0
AVX_INSTR roundss, sse4, 1, 1, 0
AVX_INSTR rsqrtps, sse, 1
AVX_INSTR rsqrtss, sse, 1, 0, 0
AVX_INSTR shufpd, sse2, 1, 1, 0
AVX_INSTR shufps, sse, 1, 1, 0
AVX_INSTR sqrtpd, sse2, 1
AVX_INSTR sqrtps, sse, 1
AVX_INSTR sqrtsd, sse2, 1, 0, 0
AVX_INSTR sqrtss, sse, 1, 0, 0
AVX_INSTR stmxcsr, sse, 1
AVX_INSTR subpd, sse2, 1, 0, 0
AVX_INSTR subps, sse, 1, 0, 0
AVX_INSTR subsd, sse2, 1, 0, 0
AVX_INSTR subss, sse, 1, 0, 0
AVX_INSTR ucomisd, sse2, 1
AVX_INSTR ucomiss, sse, 1
AVX_INSTR unpckhpd, sse2, 1, 0, 0
AVX_INSTR unpckhps, sse, 1, 0, 0
AVX_INSTR unpcklpd, sse2, 1, 0, 0
AVX_INSTR unpcklps, sse, 1, 0, 0
AVX_INSTR xorpd, sse2, 1, 0, 1
AVX_INSTR xorps, sse, 1, 0, 1

; 3DNow instructions, for sharing code between AVX, SSE and 3DN
AVX_INSTR pfadd, 3dnow, 1, 0, 1
AVX_INSTR pfsub, 3dnow, 1, 0, 0
AVX_INSTR pfmul, 3dnow, 1, 0, 1

;%1 == instruction
;%2 == minimal instruction set
%macro GPR_INSTR 2
    %macro %1 2-5 fnord, %1, %2
        %ifdef cpuname
            %if notcpuflag(%5)
                %error use of ``%4'' %5 instruction in cpuname function: current_function
            %endif
        %endif
        %ifidn %3, fnord
            %4 %1, %2
        %else
            %4 %1, %2, %3
        %endif
    %endmacro
%endmacro

GPR_INSTR andn, bmi1
GPR_INSTR bextr, bmi1
GPR_INSTR blsi, bmi1
GPR_INSTR blsr, bmi1
GPR_INSTR blsmsk, bmi1
GPR_INSTR bzhi, bmi2
GPR_INSTR mulx, bmi2
GPR_INSTR pdep, bmi2
GPR_INSTR pext, bmi2
GPR_INSTR popcnt, sse42
GPR_INSTR rorx, bmi2
GPR_INSTR sarx, bmi2
GPR_INSTR shlx, bmi2
GPR_INSTR shrx, bmi2

; base-4 constants for shuffles
%assign i 0
%rep 256
    %assign j ((i>>6)&3)*1000 + ((i>>4)&3)*100 + ((i>>2)&3)*10 + (i&3)
    %if j < 10
        CAT_XDEFINE q000, j, i
    %elif j < 100
        CAT_XDEFINE q00, j, i
    %elif j < 1000
        CAT_XDEFINE q0, j, i
    %else
        CAT_XDEFINE q, j, i
    %endif
    %assign i i+1
%endrep
%undef i
%undef j

%macro FMA_INSTR 3
    %macro %1 4-7 %1, %2, %3
        %if cpuflag(xop)
            v%5 %1, %2, %3, %4
        %elifnidn %1, %4
            %6 %1, %2, %3
            %7 %1, %4
        %else
            %error non-xop emulation of ``%5 %1, %2, %3, %4'' is not supported
        %endif
    %endmacro
%endmacro

FMA_INSTR  pmacsww,  pmullw, paddw
FMA_INSTR  pmacsdd,  pmulld, paddd ; sse4 emulation
FMA_INSTR pmacsdql,  pmuldq, paddq ; sse4 emulation
FMA_INSTR pmadcswd, pmaddwd, paddd

; Macros for consolidating FMA3 and FMA4 using 4-operand (dst, src1, src2, src3) syntax.
; FMA3 is only possible if dst is the same as one of the src registers.
; Either src2 or src3 can be a memory operand.
%macro FMA4_INSTR 2-*
    %push fma4_instr
    %xdefine %$prefix %1
    %rep %0 - 1
        %macro %$prefix%2 4-6 %$prefix, %2
            %if notcpuflag(fma3) && notcpuflag(fma4)
                %error use of ``%5%6'' fma instruction in cpuname function: current_function
            %elif cpuflag(fma4)
                v%5%6 %1, %2, %3, %4
            %elifidn %1, %2
                ; If %3 or %4 is a memory operand it needs to be encoded as the last operand.
                %ifnum sizeof%3
                    v%{5}213%6 %2, %3, %4
                %else
                    v%{5}132%6 %2, %4, %3
                %endif
            %elifidn %1, %3
                v%{5}213%6 %3, %2, %4
            %elifidn %1, %4
                v%{5}231%6 %4, %2, %3
            %else
                %error fma3 emulation of ``%5%6 %1, %2, %3, %4'' is not supported
            %endif
        %endmacro
        %rotate 1
    %endrep
    %pop
%endmacro

FMA4_INSTR fmadd,    pd, ps, sd, ss
FMA4_INSTR fmaddsub, pd, ps
FMA4_INSTR fmsub,    pd, ps, sd, ss
FMA4_INSTR fmsubadd, pd, ps
FMA4_INSTR fnmadd,   pd, ps, sd, ss
FMA4_INSTR fnmsub,   pd, ps, sd, ss

; Macros for converting VEX instructions to equivalent EVEX ones.
%macro EVEX_INSTR 2-3 0 ; vex, evex, prefer_evex
    %macro %1 2-7 fnord, fnord, %1, %2, %3
        %ifidn %3, fnord
            %define %%args %1, %2
        %elifidn %4, fnord
            %define %%args %1, %2, %3
        %else
            %define %%args %1, %2, %3, %4
        %endif
        %assign %%evex_required cpuflag(avx512) & %7
        %ifnum regnumof%1
            %if regnumof%1 >= 16 || sizeof%1 > 32
                %assign %%evex_required 1
            %endif
        %endif
        %ifnum regnumof%2
            %if regnumof%2 >= 16 || sizeof%2 > 32
                %assign %%evex_required 1
            %endif
        %endif
        %ifnum regnumof%3
            %if regnumof%3 >= 16 || sizeof%3 > 32
                %assign %%evex_required 1
            %endif
        %endif
        %if %%evex_required
            %6 %%args
        %else
            %5 %%args ; Prefer VEX over EVEX due to shorter instruction length
        %endif
    %endmacro
%endmacro

EVEX_INSTR vbroadcastf128, vbroadcastf32x4
EVEX_INSTR vbroadcasti128, vbroadcasti32x4
EVEX_INSTR vextractf128,   vextractf32x4
EVEX_INSTR vextracti128,   vextracti32x4
EVEX_INSTR vinsertf128,    vinsertf32x4
EVEX_INSTR vinserti128,    vinserti32x4
EVEX_INSTR vmovdqa,        vmovdqa32
EVEX_INSTR vmovdqu,        vmovdqu32
EVEX_INSTR vpand,          vpandd
EVEX_INSTR vpandn,         vpandnd
EVEX_INSTR vpor,           vpord
EVEX_INSTR vpxor,          vpxord
EVEX_INSTR vrcpps,         vrcp14ps,   1 ; EVEX versions have higher precision
EVEX_INSTR vrcpss,         vrcp14ss,   1
EVEX_INSTR vrsqrtps,       vrsqrt14ps, 1
EVEX_INSTR vrsqrtss,       vrsqrt14ss, 1

; vi:set sw=4 et:
