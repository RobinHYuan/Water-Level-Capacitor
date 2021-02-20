; EFM8_Receiver.asm:  This program implements a simple serial port
; communication protocol to program, verify, and read an SPI flash memory.  Since
; the program was developed to store wav audio files, it also allows 
; for the playback of said audio.  It is assumed that the wav sampling rate is
; 22050Hz, 8-bit, mono.
;
; Connections:
; 
; EFM8 board  SPI_FLASH
; P0.0        Pin 6 (SPI_CLK)
; P0.1        Pin 2 (MISO)
; P0.2        Pin 5 (MOSI)
; P0.3        Pin 1 (CS/)
; GND         Pin 4
; 3.3V        Pins 3, 7, 8  (The MCP1700 3.3V voltage regulator or similar is required)
;
; P3.0 is the DAC output which should be connected to the input of power amplifier (LM386 or similar)
;

$NOLIST
$MODEFM8LB1
$LIST

SYSCLK         EQU 72000000  ; Microcontroller system clock frequency in Hz
TIMER2_RATE    EQU 22050     ; 22050Hz is the sampling rate of the wav file we are playing
TIMER2_RELOAD  EQU 0x10000-(SYSCLK/TIMER2_RATE)
F_SCK_MAX      EQU 20000000
BAUDRATE       EQU 115200

FLASH_CE EQU P0.3
SPEAKER  EQU P2.0

; Commands supported by the SPI flash memory according to the datasheet
WRITE_ENABLE     EQU 0x06  ; Address:0 Dummy:0 Num:0
WRITE_DISABLE    EQU 0x04  ; Address:0 Dummy:0 Num:0
READ_STATUS      EQU 0x05  ; Address:0 Dummy:0 Num:1 to infinite
READ_BYTES       EQU 0x03  ; Address:3 Dummy:0 Num:1 to infinite
READ_SILICON_ID  EQU 0xab  ; Address:0 Dummy:3 Num:1 to infinite
FAST_READ        EQU 0x0b  ; Address:3 Dummy:1 Num:1 to infinite
WRITE_STATUS     EQU 0x01  ; Address:0 Dummy:0 Num:1
WRITE_BYTES      EQU 0x02  ; Address:3 Dummy:0 Num:1 to 256
ERASE_ALL        EQU 0xc7  ; Address:0 Dummy:0 Num:0
ERASE_BLOCK      EQU 0xd8  ; Address:3 Dummy:0 Num:0
READ_DEVICE_ID   EQU 0x9f  ; Address:0 Dummy:2 Num:1 to infinite

; Variables used in the program:
dseg at 30H
w:   ds 3 ; 24-bit play counter.  Decremented in Timer 2 ISR.
x:		ds	4
y:		ds	4
z:      ds  4
R:      ds  4
bcd:	ds	5
bseg
mf:		dbit 1
mask:   dbit 1
; Interrupt vectors:
cseg

org 0x0000 ; Reset vector
    ljmp MainProgram

org 0x0003 ; External interrupt 0 vector (not used in this code)
	reti

org 0x000B ; Timer/Counter 0 overflow interrupt vector (not used in this code)
	reti

org 0x0013 ; External interrupt 1 vector (not used in this code)
	reti

org 0x001B ; Timer/Counter 1 overflow interrupt vector (not used in this code
	reti

org 0x0023 ; Serial port receive/transmit interrupt vector (not used in this code)
	reti

org 0x005b ; Timer 2 interrupt vector.  Used in this code to replay the wave file.
	ljmp Timer2_ISR

LCD_RS equ P1.7
LCD_RW equ P1.6 
LCD_E  equ P1.5
LCD_D4 equ P2.2
LCD_D5 equ P2.3
LCD_D6 equ P2.4
LCD_D7 equ P2.5
;library used
$NOLIST
$include(LCD_4bit.inc)
$include(math32.inc)

$LIST 
Msg1:  db 'Capacitance:', 0
Msg2:  db 'pF', 0
Hex2bcd:
	clr a
    mov R0, #0  ; Set packed BCD result to 00000 
    mov R1, #0
    mov R2, #0
    mov R3, #16 ; Loop counter.
    
hex2bcd_L0:
    mov a, TL0 ; Shift TH0-TL0 left through carry
    rlc a
    mov TL0, a
    
    mov a, TH0
    rlc a
    mov TH0, a
    
	; Perform bcd + bcd + carry
	; using BCD numbers
	mov a, R0
	addc a, R0
	da a
	mov R0, a
	
	mov a, R1
	addc a, R1
	da a
	mov R1, a
	
	mov a, R2
	addc a, R2
	da a
	mov R2, a
	
	djnz R3, hex2bcd_L0
	ret

; Dumps the 5-digit packed BCD number in R2-R1-R0 into the LCD
DisplayBCD:
	; 5th digit:
    mov a, R2
    anl a, #0FH
    orl a, #'0' ; convert to ASCII
	lcall ?WriteData
	; 4th digit:
    mov a, R1
    swap a
    anl a, #0FH
    orl a, #'0' ; convert to ASCII
	lcall ?WriteData
	; 3rd digit:
    mov a, R1
    anl a, #0FH
    orl a, #'0' ; convert to ASCII
	lcall ?WriteData
	; 2nd digit:
    mov a, R0
    swap a
    anl a, #0FH
    orl a, #'0' ; convert to ASCII
	lcall ?WriteData
	; 1st digit:
    mov a, R0
    anl a, #0FH
    orl a, #'0' ; convert to ASCII
	lcall ?WriteData
    
    ret
;-------------------------------------;
; ISR for Timer 2.  Used to playback  ;
; the WAV file stored in the SPI      ;
; flash memory.                       ;
;-------------------------------------;
Timer2_ISR:
	mov	SFRPAGE, #0x00
	clr	TF2H ; Clear Timer2 interrupt flag

	; The registers used in the ISR must be saved in the stack
	push acc
	push psw
	
	; Check if the play counter is zero.  If so, stop playing sound.
	mov a, w+0
	orl a, w+1
	orl a, w+2
	jz stop_playing
	
	; Decrement play counter 'w'.  In this implementation 'w' is a 24-bit counter.
	mov a, #0xff
	dec w+0
	cjne a, w+0, keep_playing
	dec w+1
	cjne a, w+1, keep_playing
	dec w+2
	
keep_playing:

	setb SPEAKER
	lcall Send_SPI ; Read the next byte from the SPI Flash...
	
	; It gets a bit complicated here because we read 8 bits from the flash but we need to write 12 bits to DAC:
	mov SFRPAGE, #0x30 ; DAC registers are in page 0x30
	push acc ; Save the value we got from flash
	swap a
	anl a, #0xf0
	mov DAC0L, a
	pop acc
	swap a
	anl a, #0x0f
	mov DAC0H, a
	mov SFRPAGE, #0x00
	
	sjmp Timer2_ISR_Done

stop_playing:
	clr TR2 ; Stop timer 2
	setb FLASH_CE  ; Disable SPI Flash
	clr SPEAKER ; Turn off speaker.  Removes hissing noise when not playing sound.

Timer2_ISR_Done:	
	pop psw
	pop acc
	reti

;---------------------------------;
; Sends a byte via serial port    ;
;---------------------------------;
putchar:
	jbc	TI,putchar_L1
	sjmp putchar
putchar_L1:
	mov	SBUF,a
	ret

;---------------------------------;
; Receive a byte from serial port ;
;---------------------------------;
getchar:
	jbc	RI,getchar_L1
	sjmp getchar
getchar_L1:
	mov	a,SBUF
	ret

;---------------------------------;
; Sends AND receives a byte via   ;
; SPI.                            ;
;---------------------------------;
Send_SPI:
	mov	SPI0DAT, a
Send_SPI_L1:
	jnb	SPIF, Send_SPI_L1 ; Wait for SPI transfer complete
	clr SPIF ; Clear SPI complete flag 
	mov	a, SPI0DAT
	ret

;---------------------------------;
; SPI flash 'write enable'        ;
; instruction.                    ;
;---------------------------------;
Enable_Write:
	clr FLASH_CE
	mov a, #WRITE_ENABLE
	lcall Send_SPI
	setb FLASH_CE
	ret

;---------------------------------;
; This function checks the 'write ;
; in progress' bit of the SPI     ;
; flash memory.                   ;
;---------------------------------;
Check_WIP:
	clr FLASH_CE
	mov a, #READ_STATUS
	lcall Send_SPI
	mov a, #0x55
	lcall Send_SPI
	setb FLASH_CE
	jb acc.0, Check_WIP ;  Check the Write in Progress bit
	ret
	
Init_all:
	; Disable WDT:
	mov	WDTCN, #0xDE
	mov	WDTCN, #0xAD
	
	mov	VDM0CN, #0x80
	mov	RSTSRC, #0x06
	
	; Switch SYSCLK to 72 MHz.  First switch to 24MHz:
	mov	SFRPAGE, #0x10
	mov	PFE0CN, #0x20
	mov	SFRPAGE, #0x00
	mov	CLKSEL, #0x00
	mov	CLKSEL, #0x00 ; Second write to CLKSEL is required according to datasheet
	
	; Wait for clock to settle at 24 MHz by checking the most significant bit of CLKSEL:
Init_L1:
	mov	a, CLKSEL
	jnb	acc.7, Init_L1
	
	; Now switch to 72MHz:
	mov	CLKSEL, #0x03
	mov	CLKSEL, #0x03  ; Second write to CLKSEL is required according to datasheet
	
	; Wait for clock to settle at 72 MHz by checking the most significant bit of CLKSEL:
Init_L2:
	mov	a, CLKSEL
	jnb	acc.7, Init_L2

	mov	SFRPAGE, #0x00
	
	; Configure P3.0 as analog output.  P3.0 pin is the output of DAC0.
	anl	P3MDIN, #0xFE
	orl	P3, #0x01
	
	; Configure the pins used for SPI (P0.0 to P0.3)
	mov	P0MDOUT, #0x1D ; SCK, MOSI, P0.3, TX0 are push-pull, all others open-drain

	mov	XBR0, #0x03 ; Enable SPI and UART0: SPI0E=1, URT0E=1
	mov	XBR1, #0x10
	mov	XBR2, #0x40 ; Enable crossbar and weak pull-ups

	; Enable serial communication and set up baud rate using timer 1
	mov	SCON0, #0x10	
	mov	TH1, #(0x100-((SYSCLK/BAUDRATE)/(12*2)))
	mov	TL1, TH1
	anl	TMOD, #0x0F ; Clear the bits of timer 1 in TMOD
	orl	TMOD, #0x20 ; Set timer 1 in 8-bit auto-reload mode.  Don't change the bits of timer 0
	setb TR1 ; START Timer 1
	setb TI ; Indicate TX0 ready
	
	; Configure DAC 0
	mov	SFRPAGE, #0x30 ; To access DAC 0 we use register page 0x30
	mov	DACGCF0, #0b_1000_1000 ; 1:D23REFSL(VCC) 1:D3AMEN(NORMAL) 2:D3SRC(DAC3H:DAC3L) 1:D01REFSL(VCC) 1:D1AMEN(NORMAL) 1:D1SRC(DAC1H:DAC1L)
	mov	DACGCF1, #0b_0000_0000
	mov	DACGCF2, #0b_0010_0010 ; Reference buffer gain 1/3 for all channels
	mov	DAC0CF0, #0b_1000_0000 ; Enable DAC 0
	mov	DAC0CF1, #0b_0000_0010 ; DAC gain is 3.  Therefore the overall gain is 1.
	; Initial value of DAC 0 is mid scale:
	mov	DAC0L, #0x00
	mov	DAC0H, #0x08
	mov	SFRPAGE, #0x00
	
	; Configure SPI
	mov	SPI0CKR, #((SYSCLK/(2*F_SCK_MAX))-1)
	mov	SPI0CFG, #0b_0100_0000 ; SPI in master mode
	mov	SPI0CN0, #0b_0000_0001 ; SPI enabled and in three wire mode
	setb FLASH_CE ; CS=1 for SPI flash memory
	clr SPEAKER ; Turn off speaker.
	
	; Configure Timer 2 and its interrupt
	mov	TMR2CN0,#0x00 ; Stop Timer2; Clear TF2
	orl	CKCON0,#0b_0001_0000 ; Timer 2 uses the system clock
	; Initialize reload value:
	mov	TMR2RLL, #low(TIMER2_RELOAD)
	mov	TMR2RLH, #high(TIMER2_RELOAD)
	; Set timer to reload immediately
	mov	TMR2H,#0xFF
	mov	TMR2L,#0xFF
	setb ET2 ; Enable Timer 2 interrupts
	; setb TR2 ; Timer 2 is only enabled to play stored sound
	
	; initialize Timer 0 as a 16bit counter
	mov	SFRPAGE, #0x00
	mov p0skip,#0b0000_1000
	mov a, TMOD
    anl a, #0b_1111_0000 ; Clear the bits of timer/counter 0
    orl a, #0b_0000_0101 ; Sets the bits of timer/counter 0 for a 16-bit counter
    mov TMOD, a
	
	
	setb EA ; Enable interrupts
	
	ret

;---------------------------------;
; Main program. Includes hardware ;
; initialization and 'forever'    ;
; loop.                           ;
;---------------------------------;
Wait_one_second:	
    ;For a 24.5MHz clock one machine cycle takes 1/24.5MHz=40.81633ns

    mov R2, #153; Calibrate using this number to account for overhead delays
X3: mov R1, #255
X2: mov R0, #255
X1: djnz R0, X1 ; 3 machine cycles -> 3*40.81633ns*255=31.2245us (see table 10.2 in reference manual)
    djnz R1, X2 ; 31.2245us*255=7.96224ms
    djnz R2, X3 ; 7.96224ms*125=0.995s + overhead
    ret
	

MainProgram:
    mov SP, #0x7f ; Setup stack pointer to the start of indirectly accessable data memory minus one
    lcall Init_all ; Initialize the hardware
	lcall LCD_4BIT 
	clr mask
 	Set_Cursor(1, 1)
   Send_Constant_String(#Msg1)
   Set_Cursor(2, 11)
   Send_Constant_String(#Msg2)
forever_loop:
	clr TR0 ; Stop counter 0
    mov TL0, #0x00
    mov TH0, #0x00
    setb TR0 ; Start counter 0
    lcall Wait_one_second
    clr TR0 
	load_x(144)
	load_y(100000)
	lcall mul32
	load_y(63)
	lcall div32
	load_y(1000)
	lcall mul32
	mov y+0,TL0
	mov y+1,TH0
	mov y+2,#0x00
	mov y+3,#0x00
	lcall div32
	mov TL0, x+0
	mov TH0, x+1
	Set_Cursor(2, 5)
    lcall hex2bcd
    lcall DisplayBCD
    load_y(12)
    ;measure Capacitance
    jb RI, serial_get
    ljmp forever_loop
forever:
ljmp forever_loop
serial_get:
	lcall getchar ; Wait for data to arrive
	cjne a, #'#', forever ; Message format is #n[data] where 'n' is '0' to '9'
	clr TR2 ; Stop Timer 2 from playing previous request
	setb FLASH_CE ; Disable SPI Flash	
	clr SPEAKER ; Turn off speaker.
	lcall getchar


;------------------------------------------------------------------------------------------------------------------	

Percent_0:
    ; Playback a portion of the stored wav file
	clr TR2 ; Stop Timer 2 ISR from playing previous request
	mov tr2,#0x00
	setb FLASH_CE
	clr SPEAKER ; Turn off speaker.
	 
 	clr FLASH_CE ; Enable SPI Flash
 	mov a, #READ_BYTES
	lcall Send_SPI
  	mov a, #0x00
 	lcall Send_SPI
 	mov a, #0x00
 	lcall Send_SPI
  	mov a, #0x2d
 	lcall Send_SPI
 	; Get how many bytes to play

	mov w+2, #0x00
 	mov w+1, #0x7f
	mov w+0, #0x00
 
	mov a, #0x00 ; Request first byte to send to DAC
 	lcall Send_SPI
 
 	setb TR2 ; Start playback by enabling timer 2
	setb SPEAKER 
 	ljmp forever_loop 

Percent_10:
    ; Playback a portion of the stored wav file
	clr TR2 ; Stop Timer 2 ISR from playing previous request
	mov tr2,#0x00
	setb FLASH_CE
	clr SPEAKER ; Turn off speaker.
	 
 	clr FLASH_CE ; Enable SPI Flash
 	mov a, #READ_BYTES
	lcall Send_SPI
  	mov a, #0x00
 	lcall Send_SPI
 	mov a, #0x7e
 	lcall Send_SPI
  	mov a, #0x99
 	lcall Send_SPI
 	; Get how many bytes to play

	mov w+2, #0x00
 	mov w+1, #0x82
	mov w+0, #0x0b
 
	mov a, #0x00 ; Request first byte to send to DAC
 	lcall Send_SPI
 
 	setb TR2 ; Start playback by enabling timer 2
	setb SPEAKER 
 	ljmp forever_loop 
     
percent_20:
	 ; Playback a portion of the stored wav file
	clr TR2 ; Stop Timer 2 ISR from playing previous request
	mov tr2,#0x00
	setb FLASH_CE
	clr SPEAKER ; Turn off speaker.
	 
 	clr FLASH_CE ; Enable SPI Flash
 	mov a, #READ_BYTES
	lcall Send_SPI
  	mov a, #0x01
 	lcall Send_SPI
 	mov a, #0x00
 	lcall Send_SPI
  	mov a, #0x8d
 	lcall Send_SPI
 	; Get how many bytes to play

	mov w+2, #0x00
 	mov w+1, #0x45
	mov w+0, #0xc6
 
	mov a, #0x00 ; Request first byte to send to DAC
 	lcall Send_SPI
 
 	setb TR2 ; Start playback by enabling timer 2
	setb SPEAKER 
 	ljmp forever_loop 
 	
 percent_30:
	clr TR2 ;
	mov tr2,#0x00
	setb FLASH_CE
	clr SPEAKER ; Turn off speaker.
	 
 	clr FLASH_CE ; Enable SPI Flash
 	mov a, #READ_BYTES
	lcall Send_SPI
  	mov a, #0x01
 	lcall Send_SPI
 	mov a, #0x46
 	lcall Send_SPI
  	mov a, #0x52
 	lcall Send_SPI
 	; Get how many bytes to play

	mov w+2, #0x00
 	mov w+1, #0x45
	mov w+0, #0x03
 
	mov a, #0x00 ; Request first byte to send to DAC
 	lcall Send_SPI
 
 	setb TR2 ; Start playback by enabling timer 2
	setb SPEAKER 
 	ljmp forever_loop 	
	
 percent_40:
	 ; Playback a portion of the stored wav file
	clr TR2 ; Stop Timer 2 ISR from playing previous request
	mov tr2,#0x00
	setb FLASH_CE
	clr SPEAKER ; Turn off speaker.
	 
 	clr FLASH_CE ; Enable SPI Flash
 	mov a, #READ_BYTES
	lcall Send_SPI
  	mov a, #0x01
 	lcall Send_SPI
 	mov a, #0x8b
 	lcall Send_SPI
  	mov a, #0x56
 	lcall Send_SPI
 	; Get how many bytes to play

	mov w+2, #0x00
 	mov w+1, #0x44
	mov w+0, #0x1d
	mov a, #0x00 ; Request first byte to send to DAC
 	lcall Send_SPI
 
 	setb TR2 ; Start playback by enabling timer 2
	setb SPEAKER
	ljmp forever_loop

percent_50:
	; Playback a portion of the stored wav file
	clr TR2 ; Stop Timer 2 ISR from playing previous request
	mov tr2,#0x00
	setb FLASH_CE
	clr SPEAKER ; Turn off speaker.
	 
 	clr FLASH_CE ; Enable SPI Flash
 	mov a, #READ_BYTES
	lcall Send_SPI
  	mov a, #0x01
 	lcall Send_SPI
 	mov a, #0xce
 	lcall Send_SPI
  	mov a, #0xa3
 	lcall Send_SPI
 	; Get how many bytes to play

	mov w+2, #0x00
 	mov w+1, #0x41
	mov w+0, #0x8c
	mov a, #0x00 ; Request first byte to send to DAC
 	lcall Send_SPI
 
 	setb TR2 ; Start playback by enabling timer 2
	setb SPEAKER
	ljmp forever_loop

percent_60:
	 ; Playback a portion of the stored wav file
	clr TR2 ; Stop Timer 2 ISR from playing previous request
	mov tr2,#0x00
	setb FLASH_CE
	clr SPEAKER ; Turn off speaker.
	 
 	clr FLASH_CE ; Enable SPI Flash
 	mov a, #READ_BYTES
	lcall Send_SPI
  	mov a, #0x02
 	lcall Send_SPI
 	mov a, #0x10
 	lcall Send_SPI
  	mov a, #0x2f
 	lcall Send_SPI
 	; Get how many bytes to play

	mov w+2, #0x00
 	mov w+1, #0x44
	mov w+0, #0x1d
	mov a, #0x00 ; Request first byte to send to DAC
 	lcall Send_SPI
 
 	setb TR2 ; Start playback by enabling timer 2
	setb SPEAKER
	ljmp forever_loop


percent_70:
	 ; Playback a portion of the stored wav file
	clr TR2 ; Stop Timer 2 ISR from playing previous request
	mov tr2,#0x00
	setb FLASH_CE
	clr SPEAKER ; Turn off speaker.
	 
 	clr FLASH_CE ; Enable SPI Flash
 	mov a, #READ_BYTES
	lcall Send_SPI
  	mov a, #0x02
 	lcall Send_SPI
 	mov a, #0x52
 	lcall Send_SPI
  	mov a, #0xbf
 	lcall Send_SPI
 	; Get how many bytes to play

	mov w+2, #0x00
 	mov w+1, #0x53
	mov w+0, #0x1d
	mov a, #0x00 ; Request first byte to send to DAC
 	lcall Send_SPI
 
 	setb TR2 ; Start playback by enabling timer 2
	setb SPEAKER
	ljmp forever_loop

percent_80:
	 ; Playback a portion of the stored wav file
	clr TR2 ; Stop Timer 2 ISR from playing previous request
	mov tr2,#0x00
	setb FLASH_CE
	clr SPEAKER ; Turn off speaker.
	 
 	clr FLASH_CE ; Enable SPI Flash
 	mov a, #READ_BYTES
	lcall Send_SPI
  	mov a, #0x02
 	lcall Send_SPI
 	mov a, #0xa1
 	lcall Send_SPI
  	mov a, #0x5e
 	lcall Send_SPI
 	; Get how many bytes to play

	mov w+2, #0x00
 	mov w+1, #0x45
	mov w+0, #0x1d
	mov a, #0x00 ; Request first byte to send to DAC
 	lcall Send_SPI
 
 	setb TR2 ; Start playback by enabling timer 2
	setb SPEAKER
	ljmp forever_loop
percent_90:
	 ; Playback a portion of the stored wav file
	clr TR2 ; Stop Timer 2 ISR from playing previous request
	mov tr2,#0x00
	setb FLASH_CE
	clr SPEAKER ; Turn off speaker.
	 
 	clr FLASH_CE ; Enable SPI Flash
 	mov a, #READ_BYTES
	lcall Send_SPI
  	mov a, #0x02
 	lcall Send_SPI
 	mov a, #0xe1
 	lcall Send_SPI
  	mov a, #0x5e
 	lcall Send_SPI
 	; Get how many bytes to play

	mov w+2, #0x00
 	mov w+1, #0x45
	mov w+0, #0x1d
	mov a, #0x00 ; Request first byte to send to DAC
 	lcall Send_SPI
 
 	setb TR2 ; Start playback by enabling timer 2
	setb SPEAKER
	ljmp forever_loop
percent_full:
	 ; Playback a portion of the stored wav file
	clr TR2 ; Stop Timer 2 ISR from playing previous request
	mov tr2,#0x00
	setb FLASH_CE
	clr SPEAKER ; Turn off speaker.
	 
 	clr FLASH_CE ; Enable SPI Flash
 	mov a, #READ_BYTES
	lcall Send_SPI
  	mov a, #0x03
 	lcall Send_SPI
 	mov a, #0x23
 	lcall Send_SPI
  	mov a, #0x95
 	lcall Send_SPI
 	; Get how many bytes to play

	mov w+2, #0x00
 	mov w+1, #0xff
	mov w+0, #0x1d
	mov a, #0x00 ; Request first byte to send to DAC
 	lcall Send_SPI
 
 	setb TR2 ; Start playback by enabling timer 2
	setb SPEAKER
	ljmp forever_loop

end
