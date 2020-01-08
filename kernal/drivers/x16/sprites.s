;----------------------------------------------------------------------
; VERA Sprites Driver
;----------------------------------------------------------------------
; (C)2019 Michael Steil, License: 2-clause BSD

; This code currently supports up to 8 sprites.

.include "../../../io.inc"
.include "../../../regs.inc"
.include "../../../mac.inc"

.export sprite_set_image
.export sprite_set_position

.segment "SPRITES"

;---------------------------------------------------------------
; sprite_set_image
;
;   In:   .A     sprite number
;         .X     data width
;         .Y     data height
;         .C     1: apply mask; 0: don't apply mask
;         r0     pointer to pixel data
;         r1     pointer to mask data (if .C=1)
;         r2L    pixel data bits per pixel
;   Out: .C      0: OK, 1: error
;
; Notes: This function is very generic. "data width/height" and
;        bpp can be any numbers up to the maximum supported
;        by the hardware; this code will convert the sprite
;        data into the appropriate hardware format. [NYI]
;---------------------------------------------------------------
sprite_set_image:
	pha ; sprite number
	php

	asl
	asl
	asl
	asl ; add $1000 per sprite ; see memory layout in io.inc
	clc
	adc #>sprite_addr
	sta veramid
	lda #<sprite_addr
	sta veralo
	lda #$10 | (sprite_addr >> 16)
	sta verahi

	plp
	bcc @a
	cpx #16
	bne @a
	cpy #16
	bne @a
	lda r2L
	cmp #1
	bne @a

	jsr convert_16x16x1_mask
	bra @z
	
@a:
	; XXX support more formats

	sec ; unsupported
	rts

@z:
; set sprite data offset & bpp
	pla ; sprite number
	pha
	asl
	asl
	asl ; *8
	sta veralo
	lda #$50
	sta veramid
	lda #$1F
	sta verahi
	pla ; sprite number
	lsr
	pha
	lda #0
	ror ; LSB will be bit #12 of address
	clc
	adc #<(sprite_addr >> 5)
	sta veradat
	pla ; remaining bits
	adc #1 << 7 | >(sprite_addr >> 5) ; 8 bpp
	sta veradat

; set size
	lda veralo
	clc
	adc #5 ; skip to offset #7
	sta veralo
	lda #1 << 6 | 1 << 4 ;  16x16 px
	sta veradat

	clc ; OK
	rts

convert_16x16x1_mask:
; this is the code for
; .X  = 16 (width)
; .Y  = 16 (height)
; .C  = 1  (apply mask)
; r2L = 1  (1 bpp)

	PushB r2H
	ldy #0
@1:	lda #8
	sta r2H
	lda (r0),y ; pixels
	tax
	lda (r1),y ; mask
@2:	asl
	bcs @3
	stz veradat ; mask = 0 -> color 0 (translucent)
	pha
	txa
	asl         ; skip color
	tax
	pla
	bra @4
@3:	pha
	txa
	asl
	tax
	bcc @5
@0xxx:	lda #1  ; white
	bra @6
@5:	lda #16 ; black
@6:	sta veradat
	pla
@4:	dec r2H
	bne @2
	iny
	cpy #32
	bne @1

	PopB r2H
	rts

;---------------------------------------------------------------
; sprite_set_position
;
;   In:   .A     sprite number
;         r0     x coordinate
;         r1     y coordinate
;
; Note: A negative x coordinate turns the sprite off.
;---------------------------------------------------------------
sprite_set_position:
	; VERA: sprites @$1F5000
	ldx #$50
	stx veramid
	ldx #$1F
	stx verahi
	
	and #7 ; mask sprites 0-7
	asl
	asl
	asl ; *8
	clc

	ldx r0H
	bpl @1

; disable sprite
	adc #$06
	sta veralo
	stz veradat ; set zdepth to 0
	rts
	
@1:	adc #$02
	sta veralo
	lda r0L
	sta veradat ; offset 2: X lo
	lda r0H
	sta veradat ; offset 3: X hi
	lda r1L
	sta veradat ; offset 4: Y lo
	lda r1H
	sta veradat ; offset 5: Y hi
	lda #3 << 2
	sta veradat ; offset 6: set zdepth to 3

	lda #$00
	sta veralo
	lda #$40
	sta veramid
	lda #$1F
	sta verahi
	lda #1
	sta veradat ; enable sprites globally
	rts
