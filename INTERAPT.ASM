.model tiny
.386

.code

org 100h


VIDEOSEG	        equ 0b800h
CONSOLE_ARGS        equ 80h

CONSOLE_WIDTH       equ 80d
CONSOLE_HEIGHT      equ 25d
CONSOLE_MOVEMENT    equ 2d

CENTER_ADDR         equ CONSOLE_WIDTH * (CONSOLE_HEIGHT / 2 + CONSOLE_MOVEMENT) + CONSOLE_WIDTH / 2

FRAME_WIDTH    	    equ 50d
FRAME_HEIGHT        equ 20d

REGS_FRAME_WIDTH    equ 13d
REGS_FRAME_HEIGHT   equ 8d
REGS_FRAME_BORDER_COLOR  equ 00001110b
REGS_FRAME_BCKG_COLOR    equ 00001110b


RIGHT_UP_ADDR       equ (CONSOLE_WIDTH - (REGS_FRAME_WIDTH - REGS_FRAME_WIDTH / 2) + CONSOLE_WIDTH * (REGS_FRAME_HEIGHT / 2))

PARTITION_SYM       equ '/'
LINE_END_SYM        equ '*'

MAX_STR_LEN         equ 150d

REGISTERS_INFO_KEY  equ 13h     ; R  scan code

REGISTERS_INFO_ON   equ 1
REGISTERS_INFO_OFF  equ 0



Start:
        xor ax, ax
        mov es, ax
        mov bx, 09h * 4

        mov ax, es:[bx]
        mov old09ofs, ax
        mov ax, es:[bx + 2]
        mov old09seg, ax

        cli
        mov word ptr es:[bx], offset InterceptKeyboard
        mov ax, cs
        mov es:[bx + 2], ax
        sti


        xor ax, ax
        mov es, ax
        mov bx, 08h * 4

        mov ax, es:[bx]
        mov old_timer_ofs, ax
        mov ax, es:[bx + 2]
        mov old_timer_seg, ax

        cli
        mov word ptr es:[bx], offset InterceptTimer
        mov ax, cs
        mov es:[bx + 2], ax
        sti
    

        int 09h

        mov ax, 3100h
        mov dx, offset EOP
        shr dx, 4
        inc dx
        int 21h


;-------------------------------------------------------------------------------------
; Intercepts the 09h interrupt and calls the frame drawing function with register
; information if the specified key was pressed, and erases it if another one was pressed.
; After that, the control is transferred to the 09hr interrupt.
;
; Entry: es = VIDEOSEG
; Exit:  none
; Destr: none
;-------------------------------------------------------------------------------------
InterceptKeyboard   proc

        push ax bx cx dx di si es ds

        push cs
        pop ds

        in  al, 60h
        cmp al, REGISTERS_INFO_KEY
        jne TransferControlToInt_09h

        mov al, FRAME_FLAG
        xor al, 1
        mov byte ptr FRAME_FLAG, al

TransferControlToInt_09h:
        pop ds es si di dx cx bx ax

                    db 0eah        ; jmp 0000:0000
        old09ofs    dw 0
        old09seg    dw 0

        endp
;-------------------------------------------------------------------------------------


;-------------------------------------------------------------------------------------
; Intercepts timer interrupt and if FRAME_FLAG = 1 prints a frame with registers
; Entry: es = VIDEOSEG
; Exit:  none
; Destr: none
;-------------------------------------------------------------------------------------
InterceptTimer proc
        push ax bx cx dx di si es ds

        push cs
        pop ds

        mov al, FRAME_FLAG
        cmp al, REGISTERS_INFO_ON
        jne TransferControlToTimer

        push si
        push di
        push dx
        push cx
        push bx
        push ax

        cld             ; moving forward

        pop  bx
        lea  si, AX_INFO
        call ItoA_hex

        pop  bx
        lea  si, BX_INFO
        call ItoA_hex
        
        pop  bx
        lea  si, CX_INFO
        call ItoA_hex

        pop  bx
        lea  si, DX_INFO
        call ItoA_hex

        pop  bx
        lea  si, DI_INFO
        call ItoA_hex

        pop  bx
        lea  si, SI_INFO
        call ItoA_hex


        mov dl, REGS_FRAME_WIDTH
        mov dh, REGS_FRAME_HEIGHT
        mov ah, REGS_FRAME_BORDER_COLOR
        mov al, REGS_FRAME_BCKG_COLOR
        lea bx, FRAME_STYLE_1 + 1     ; skip LINE_END_SYM

        mov di, VIDEOSEG
		mov es, di
        
        mov di, RIGHT_UP_ADDR
        lea si, REGISTERS_INFO_STR

        

		call PrintFrame

        jmp TransferControlToTimer
    

TransferControlToTimer:
        pop ds es si di dx cx bx ax

                        db 0eah        ; jmp 0000:0000
        old_timer_ofs   dw 0
        old_timer_seg   dw 0

        endp
;-------------------------------------------------------------------------------------


;-------------------------------------------------------------------------------------
; Prints the frame [length x height] to the console based on the coordinates of the 
; 	upper-left corner
;
; Entry: 	di = addr of center of the frame
;           dl = length,      dh = height
;           ah = frame color, al = bckg color
;			bx = addr of line like '+-+|_|+-+' characterizing the characters of table
;           si = addr of line "..." which should be inside the frame
; Exit: 	none
; Destr: 	ax, bx, di, si, cx
;-------------------------------------------------------------------------------------
PrintFrame:
        push bp
        mov bp, sp

        sub sp, 4               ; allocate memory for color and di
        mov ss:[bp - 2], ax     ; frame color = [bp - 1], bckg color = [bp - 2]
        mov ss:[bp - 4], di

        mov ah, 0               ; TODO ???
        mov al, dh              ; ax = dh/2 * CONSOLE_WIDTH + dl/2 = (dh * CONSOLE_WIDTH + dl) / 2
        sar ax, 1

        mov cx, CONSOLE_WIDTH
        push dx
        mul cx
        pop dx

        mov cl, dl              ; TODO ???
        mov ch, 0
        sar cx, 1

        add ax, cx              ; ax = offset from the upper-left edge of the frame to the center

        sub di, ax              ; addr of the upper-left edge of the frame
        sal di, 1               ; *=2 (1 character = 2 bytes)

        mov ch, 0
        mov cl, dl

		push di
        mov  al, ss:[bp - 1]
        mov  ah, ss:[bp - 1]
		call PrintRow
		pop  di

        add di, CONSOLE_WIDTH * 2d
		add bx, 3d

		mov cl, dh
        sub cx, 2d       ; for 1st end last lines

        inc cx
        jmp test2

    loop2:              ; for (cx = height; cx > 0; cx--)
        push cx
        push di
        mov cl, dl      ; arg cx = length
        mov ax, ss:[bp - 2]
        call PrintRow
        pop di
        pop cx

        add di, CONSOLE_WIDTH * 2d

    test2:
		loop  loop2


		add bx, 3d
        mov cl, dl          ; arg cx = length
		mov al, ss:[bp - 1]
        mov ah, ss:[bp - 1]
		call PrintRow

        mov di, ss:[bp - 4]
        sal di, 1
        call PrintTextInFrame

        leave
		ret
		endp
;-------------------------------------------------------------------------------------


;-------------------------------------------------------------------------------------
; Prints a row '#--..--#' with N chars in console with offset
;
; Entry: 	es:di = start addr (es has to point to a segment of video memory 0b800h)
;           cx    = length
;		 	bx    = addr of line like '|_|' characterizing the characters of line
;           ah    = border color, al = line color
; Exit:		none
; Destr:	cx, di
;-------------------------------------------------------------------------------------
PrintRow:
        ; mov ah, 0Fh
        push ax         ; save frame color

        mov al, [bx]
        stosw 

		sub  cx, 2d		; length -= 2 (for final char)
        pop  ax
        push ax
        mov  ah, al      ; = bckg color
        mov al, [bx + 1]
        rep stosw

        pop ax          ; ah = frame color
        mov al, [bx + 2]
        stosw

		ret
		endp
;-------------------------------------------------------------------------------------


;-------------------------------------------------------------------------------------
; Prints a text in frame
; 
; Entry:    di    = addr of center       of the frame
;           dl    = length, dh = height  of the frame
;           ds:si = addr of line "..." which should be inside the frame
; Exit:     none
; Destr:    ax, cx, di, si
;-------------------------------------------------------------------------------------
PrintTextInFrame:
        push di es
        call CountNumOfLines    ; cx = count of lines
        pop  es di

        mov al, 3
        cmp dl, al
        jb no_text

        cmp dh, al
        jb no_text

    ; don't go out of bounds by y
        mov ah, 0               
        mov al, dh
        sub ax, 2               ; minus borders

        cmp cx, ax
        jbe text_fits_y
        mov cx, ax
    text_fits_y:

        push cx
        sar  cx, 1               ; count_of_lines / 2
        mov  ax, CONSOLE_WIDTH * 2

        push dx
        mul  cx                  ; shift = CONSOLE_WIDTH * (count_of_lines / 2)
        pop  dx

        sub  di, ax
        pop  cx

        add si, 2               ; skip PARTITION_SYM and LINE_END_SYM sym
    

    print_next_line:
        push cx
        push es di
        mov al, PARTITION_SYM
        call CountStrLen        ; cx = length of line in ds:si
        pop  di es
        push di

    ; don't go out of bounds by x
        mov ah, 0               
        mov al, dl
        sub ax, 2               ; minus borders

        cmp cx, ax
        push cx
        jbe text_fits_x
        mov cx, ax
    text_fits_x:

        mov ax, cx              ; di - (cx / 2) * 2
        and ax, 0FFFEh          ; make even (and ax, (not 1))
        sub di, ax

        push si
        call PrintLine
        pop si

        pop cx
        add si, cx
        inc si                  ; skip PARTITION_SYM

        pop di

        add di, CONSOLE_WIDTH * 2

        pop cx
        loop print_next_line

    no_text:

        ret
        endp

;-------------------------------------------------------------------------------------
; Prints a line of a certain length at the specified address
;
; Entry:    es:di = addr of dest
;           ds:si = addr of source
;           cx    = length of line
; Exit:     none
; Destr:    cx, di, si
;-------------------------------------------------------------------------------------
PrintLine:
    print_line_loop:
        lodsb
        stosb
        inc di
        loop print_line_loop

        ret
        endp
;-------------------------------------------------------------------------------------


;-------------------------------------------------------------------------------------
; Counts the number of characters of a string formatted as '... *al*'
;
; Entry:	ds:si = source ptr
;           al    = border symbol
; Exit:		cx 	  = length
; Destr:	cx, es, di
;-------------------------------------------------------------------------------------
CountStrLen:
        mov di, si
        mov cx, ds
        mov es, cx

		push di

		mov cx, MAX_STR_LEN
		repne scasb         ; ... _ *al* _ _
                            ;            ^ di pointers here
        dec di
        
		mov cx, di

		pop di
		sub cx, di
		
        ret
        endp
;-------------------------------------------------------------------------------------


;-------------------------------------------------------------------------------------
; Counts the number of lines of a string formatted as '"|...|...|.. ..|"' ('|' separates lines)
;
; Entry:	ds:si = source ptr
; Exit:		cx 	  = num of lines
; Destr:	ax, cx, es, di
;-------------------------------------------------------------------------------------
CountNumOfLines:
        mov di, si  ; for scasw
        mov ax, ds
        mov es, ax


        push di si
        inc  si      ; skip first '"'
        mov  ah, 1   ; counter of borders (including first '"')
        mov  al, LINE_END_SYM
        call CountStrLen
        pop  si di

        mov al, PARTITION_SYM

    count_borders:
        scasb
        jne not_a_border

        inc ah

    not_a_border:
        loop count_borders

        dec ah      ; count_of_lines = count_of_borders - 1

        mov ch, 0
        mov cl, ah

        ret
        endp
;-------------------------------------------------------------------------------------


;-------------------------------------------------------------------------------------
; Prints the frame [length x height] to the console based on the coordinates of the 
; upper-left corner smoothly growing
;
; Entry: 	di = addr of center of the frame
;           dl = length,      dh = height
;           ah = frame color, al = bckg color
;			bx = addr of line like '+-+|_|+-+' characterizing the characters of table
;           si = addr of line "..." which should be inside the frame
; Exit: 	none
; Destr: 	ax, dx, cx
;-------------------------------------------------------------------------------------
PrintGrowingFrame:
        mov cx, 1

    count_growth_step:      ; while (dl-- > 3 && dh-- > 3) cx++
        cmp dl, 3           ; '3' is protection from dl or dh = 1
        jbe animated_print_frame

        cmp dh, 3
        jbe animated_print_frame

        sub dl, 2
        sub dh, 2

        inc cx

        jmp count_growth_step

    animated_print_frame:
        push ax bx cx dx di si
        
        call PrintFrame

        mov  ah, 86h
		mov  cx, 01h	; cx:dx = 186A0h = 0.1 * 10^6 mcs = 0.1 s
		mov  dx, 86A0h
		int  15h

        pop si di dx cx bx ax

        add dl, 2
        add dh, 2

        loop animated_print_frame
        
        ret
		endp
;-------------------------------------------------------------------------------------


;-------------------------------------------------------------------------------------
; Converts a string ending with a space to a decimal number
; after work of the func si indicates on the next arg
;
; Entry:    ds:si = addr of string ending with a space
; Exit:     ax    = decimal number
; Destr:    ax, bx, cx, dx, si, es
;-------------------------------------------------------------------------------------
AtoI_dec:
        mov al, ' '
        call CountStrLen     ; cx = length
        dec cx

        xor ax, ax      ; ax = the final number
        xor bx, bx      ; bx = cur_digit

    next_dec_digit_atoi:
        mov bl, ds:[si]   ; bx = cur_digit    
        inc si
        sub bx, '0'

        push ax

        mov ax, 10d
        call Pow        ; ax = 10^cx

        mul bx          ; ax = cur_digit * 10 ^ (length - 1)
        mov bx, ax

        pop ax

        add ax, bx      ; final_num += cur_digit * 10 ^ (length - 1)

        dec cx
        jns next_dec_digit_atoi  ; cx < 0

        inc si

        ret
        endp
;-------------------------------------------------------------------------------------


;-------------------------------------------------------------------------------------
; Converts a string ending with a space to a hexadecimal number
; after work of the func si indicates on the next arg
;
; Entry:    ds:si = addr of string ending with a space
; Exit:     ax    = hexadecimal number
; Destr:    ax, bx, cx, dx, si, es
;-------------------------------------------------------------------------------------
AtoI_hex:
        mov al, ' '
        call CountStrLen     ; cx = length
        dec cx

        xor ax, ax      ; ax = the final number
        xor bx, bx      ; bx = cur_digit

    next_hex_digit_atoi:
        mov bl, ds:[si] ; bx = cur_digit    
        inc si

        cmp bx, '9'
        ja is_letter_atoi
        sub bx, '0'
        jmp digit_is_parsed_atoi

    is_letter_atoi:
        sub bx, 'A' - 0Ah

    digit_is_parsed_atoi:

        push ax

        mov ax, 10h
        call Pow        ; ax = 10h^cx

        mul bx          ; ax = cur_digit * 10h ^ (length - 1)
        mov bx, ax

        pop ax

        add ax, bx      ; final_num += cur_digit * 10h ^ (length - 1)

        dec cx
        jns next_hex_digit_atoi  ; cx < 0

        inc si

        ret
        endp
;-------------------------------------------------------------------------------------


;-------------------------------------------------------------------------------------
; Writes the register value to the specified address in memory
; Entry:    bx    - converted register
;           ds:si - address in memory
; Exit:     none
; Destr:    bx, cx, si
;-------------------------------------------------------------------------------------
ItoA_hex:
        mov cx, 4   ; 4 bytes in register
        add si, 3

    new_digit_itoa:
        push bx
        and bx, 000Fh

        cmp bx, 9h
        ja  bx_is_letter_itoa
        add bx, '0'
        jmp bx_is_parsed_itoa

    bx_is_letter_itoa:
        add bx, 'A' - 0Ah

    bx_is_parsed_itoa:
        mov byte ptr ds:[si], bl
        dec si

        pop bx
        sar bx, 4   ; 4 binary digits in one hex digit

    loop new_digit_itoa

        endp
;-------------------------------------------------------------------------------------


;-------------------------------------------------------------------------------------
; Raises a number to a power
; Entry:    ax = number
;           cx = degree
; Exit:     ax = a number raised to a power
; Destr:    ax, dx
;-------------------------------------------------------------------------------------
Pow:
        jcxz zero_degree

        cmp cx, 1
        je one_degree

        push cx
        dec  cx

        rep mul ax

        pop cx
        ret

    zero_degree:
        mov ax, 1
        ret

    one_degree:
        ret

        endp
;-------------------------------------------------------------------------------------


;-------------------------------------------------------------------------------------
; Gets arguments from the command line
; Entry:    none
; Exit:     dl = length,      dh = height, 
;           ah = frame color, al = bckg color
;			bx = addr of line like '+-+|_|+-+' characterizing the characters of table
;           si = addr of line "..." which should be inside the frame
;
; Destr:    ax, bx, cx, dx, si, es
;-------------------------------------------------------------------------------------
GetArgs:
        mov si, CONSOLE_ARGS

        ; mov cl, ds:[si]
        add si, 2       ; skip args len and space

    ; get length    
        call AtoI_dec   ; after that si pointers on the next arg
        mov  dl, al

    ; get height
        push dx
        call AtoI_dec
        pop  dx
        mov  dh, al

    ; get frame color
        push dx
        call AtoI_hex
        pop  dx
        mov  ah, al
        xor  al, al

    ; get bckg color
        push dx

        mov  ch, ah
        push cx
        call AtoI_hex
        pop  cx
        mov  ah, ch

        pop  dx
        
    ; get style of frame (0 - custom, 1-3 - ready-made styles)
        push ax dx
        call AtoI_dec

        mov  cx, 11     ; 9 symbols + LINE_END_SYM x 2
        mul  cx
        mov  cx, ax

        pop  dx ax
        cmp  cx, 0       ; if style = 0 get table chars from console
        je   get_table_chars

        sub cx, 11      
        add cx, offset FRAME_STYLE_1 + 1
        mov bx, cx
        jmp get_text

    get_table_chars:
        inc si         ; skip LINE_END_SYM
        mov bx, si
        push ax
        mov al, LINE_END_SYM
        call CountStrLen
        pop ax
        add si, cx
        add si, 2       ; + LINE_END_SYM + space

    get_text:           ;which should be inside the frame
        ; si is already pointing at it

        ret
        endp
;-------------------------------------------------------------------------------------

.data

STRING 	    db '*/HI GITLER 12345/6789/PAMPAMPAMPAMPAMPAMPAMPPAMP/ZZZZZZZZZZZZZZZZZZZZZZZZ/huizalupapenisher/rrrrrrrrr/aaaaaaa/bbbbbb/*'


REGISTERS_INFO_STR: 
            db '*/ax = '
AX_INFO     db '0000'

            db '/bx = '
BX_INFO     db '0000'

            db '/cx = '
CX_INFO     db '0000'

            db '/dx = '
DX_INFO     db '0000'

            db '/di = '
DI_INFO     db '0000'

            db '/si = '
SI_INFO     db '0000/*'

FRAME_FLAG  db 0


FRAME_STYLE_1	    db '*ÉÍ»º ºÈÍ¼*'
FRAME_STYLE_2	    db '*+-+l l+-+*'

EOP:
end Start