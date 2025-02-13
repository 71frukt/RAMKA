.model tiny
.186

.code

org 100h

VIDEOSEG	     equ 0b800h

CONSOLE_WIDTH    equ 80d
CONSOLE_HIGHT    equ 25d
CONSOLE_MOVEMENT equ 2d

FRAME_WIDTH    	 equ 21d
FRAME_HIGHT    	 equ 15d

MAX_STR_LEN		 equ 150d


Start:
		; mov ah, 09h
		; mov dx, offset STRING
		; int 21h

		mov ax, VIDEOSEG
		mov es, ax

        cld             ; moving forward

		mov bx, CONSOLE_WIDTH * (CONSOLE_HIGHT / 2) + CONSOLE_WIDTH / 2
        sal bx, 1

		mov byte ptr es:[bx]     , 'A'
		mov byte ptr es:[bx + 1d], 11001110b
		
		mov dl, FRAME_WIDTH
		mov dh, FRAME_HIGHT
        lea bx, TABLE_CHARS
        lea si, STRING
		call PrintFrame

        mov ax, 4c00h
		int 21h



;-------------------------------------------------------------------------------------
; Prints a row '#--..--#' with N chars in console with offset
;
; Entry: 	es:di = start addr (es has to point to a segment of video memory 0b800h)
;           cx    = length
;		 	bx    = addr of line like '|_|' characterizing the characters of line
; Exit:		none
; Destr:	ax, cx, di
;-------------------------------------------------------------------------------------
PrintRow:
        mov ah, 0Fh

        mov al, [bx]
        stosw 

		sub cx, 2d		; length -= 2 (for final char)
        mov al, [bx + 1]
        rep stosw

        mov al, [bx + 2]
        stosw

		ret
		endp
;-------------------------------------------------------------------------------------


;-------------------------------------------------------------------------------------
; Prints the frame [length x height] to the console based on the coordinates of the 
; 	upper-left corner
;
; Entry: 	dl = length, dh = height, 
;			bx = addr of line like '+-+|_|+-+' characterizing the characters of table
;           si = addr of line "..." which should be inside the frame
; Exit: 	none
; Destr: 	ax, bx dx, di, cx
;-------------------------------------------------------------------------------------
PrintFrame:
        push bp
        mov bp, sp

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

        mov di, CONSOLE_WIDTH * (CONSOLE_HIGHT / 2 + CONSOLE_MOVEMENT) + CONSOLE_WIDTH / 2    ; center of console
        sub di, ax              ; addr of the upper-left edge of the frame
        sal di, 1               ; *=2 (1 character = 2 bytes)

        mov ch, 0
        mov cl, dl

		push di
		call PrintRow
		pop  di

        add di, CONSOLE_WIDTH * 2d
		add bx, 3d

		mov cl, dh
        sub cx, 2d       ; for 1st end last lines

        inc cx
        jmp test2

    loop2:              ; for (cx = hight; cx > 0; cx--)
        push cx
        push di
        mov cl, dl      ; arg cx = length
        call PrintRow
        pop di
        pop cx

        add di, CONSOLE_WIDTH * 2d

    test2:
		loop  loop2

		add bx, 3d
        mov cl, dl          ; arg cx = length
		call PrintRow


        mov di, CONSOLE_WIDTH * (CONSOLE_HIGHT / 2 + CONSOLE_MOVEMENT) + CONSOLE_WIDTH / 2
        sub dl, 2           ; minus the borders of the frame
        
        call PrintTextInFrame

        leave
		ret
		endp
;-------------------------------------------------------------------------------------


;-------------------------------------------------------------------------------------
; Prints a text in frame
; 
; Entry:    di = addr of center       of the frame
;           dl = length, dh = height  of the frame
;           si = addr of line "..." which should be inside the frame
; Exit:     none
; Destr:    
;-------------------------------------------------------------------------------------
PrintTextInFrame:
        push di
        push es
        call CountStrLen    ; cx = length of line in es:si
        pop  es
        pop  di

        inc si              ; skip the first "

        mov ah, 0
        mov al, dl
        div cl

        ; mov ch, 0
        ; mov cl, al

        ; ...cycle

        mov ch, 0
        mov cl, ah

        shr ax, 8       ; ah -> al
        sar ax, 1
        sub di, ax

        sal di, 1

        call PrintLine

        ret
        endp

        ; mov ax, cx
        ; sar ax, 1
        ; sub di, ax
        ; sal di, 1           ; *=2 (1 character = 2 bytes)


;-------------------------------------------------------------------------------------
; Prints a line of a certain length at the specified address
;
; Entry:    es:di = addr of dest
;           cx    = length of line
; Exit:     none
; Destr:    cx, di
;-------------------------------------------------------------------------------------
PrintLine:
        mov ah, 0Fh

    print_line_loop:
        lodsb
        stosw
        loop print_line_loop

        ret
        endp
;-------------------------------------------------------------------------------------


;-------------------------------------------------------------------------------------
; Prints the frame [length x height] to the console based on the coordinates of the 
; upper-left corner smoothly growing
;
; Entry: 	dl = length, dh = height, 
;			bx = addr of line like '+-+|_|+-+' characterizing the characters of table
; Exit: 	none
; Destr: 	ax, bx dx, di, cx
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
        push dx
        push cx
        push bx

        call PrintFrame

        mov  ah, 86h
		mov  cx, 01h	; cx:dx = 186A0h = 0.1 * 10^6 mcs = 0.1 s
		mov  dx, 86A0h
		int  15h

        pop bx
        pop cx
        pop dx

        add dl, 2
        add dh, 2

        loop animated_print_frame
        
        ret
		endp
;-------------------------------------------------------------------------------------


;-------------------------------------------------------------------------------------
; Counts the number of characters of a string enclosed in quotation marks
;
; Entry:	ds:si = source ptr
; Exit:		cx 	  = length
; Destr:	ax, cx, es, di
;-------------------------------------------------------------------------------------
CountStrLen:
        mov di, si

        mov ax, ds
        mov es, ax

		inc di			; skip first "
		push di

		mov cx, MAX_STR_LEN
		mov ax, '"'
		repne scasb

        dec di          ; minus last "

		mov cx, di
		pop di
		sub cx, di
		
        ret
        endp
;-------------------------------------------------------------------------------------


.data

STRING 			db '"HI GITLER DETSKOE PORNO WTFFFFFF"'
TABLE_CHARS		db '…Õª∫ ∫»Õº'

end Start