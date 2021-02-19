Play_1stSegment: ; Playback a portion of the stored wav file
	clr TR2 ; Stop Timer 2 ISR from playing previous request
	setb FLASH_CE
	clr SPEAKER ; Turn off speaker.
	 
 	clr FLASH_CE ; Enable SPI Flash
 	mov a, #READ_BYTES
 	lcall Send_SPI
	mov a, #0x00
	lcall Send_SPI
  	mov a, #0x00
 	lcall Send_SPI
 	mov a, #0x00
 	lcall Send_SPI
  	mov a, #0x2d
 	lcall Send_SPI
 	; Get how many bytes to play

	mov w+2, #0x00
 	mov w+1, #0x30
	mov w+0, #0xDA
 
	mov a, #0x00 ; Request first byte to send to DAC
 	lcall Send_SPI
 
 	setb TR2 ; Start playback by enabling timer 2
	setb SPEAKER 
 	ljmp forever_loop 
