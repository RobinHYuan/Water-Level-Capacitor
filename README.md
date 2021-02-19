## Water-Level-Capacitor

#### NEW LCD PIN ASSIGNMENT:
  LCD_RS  equ P1.7\
  LCD_RW  equ P1.6\
  LCD_E   equ P1.5\
  LCD_D4  equ P2.2\
  LCD_D5  equ P2.3\
  LCD_D6  equ P2.4\
  LCD_D7  equ P2.5\
**Note:**\
  **Timer 0 input** should be at **Pin 0.6** as UART0 and SPI0 has occupied Pin 0.0 to 0.5.
  

------------


#### Update History:
**2021-02-18; 22:06:12; Thursday**
- The unit of the capacitance is changed to pico farads now instead of  micro farads, which will give us a more preciese reading while adding the water into the cup.

------------
#### Task List:
- [ ] Find the relationship between the height of liquid in the cup and its capacitance
- [ ] Indicate water level at different height
- [ ] Timer 3 ISR for counting one second 
- [ ] Add push button algorithms to indicate when to start measuring the capacitance
- [ ] New library for the 1604 LCD


