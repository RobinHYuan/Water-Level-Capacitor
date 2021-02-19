## Water-Level-Capacitor

------------
### Introduction:

For this project, we will design, build, program, and test a microcontroller based capacitive water level detector.  The main purpose of this device is to aid visually impaired people to serve drinks.  For  this  project,  the  level  of  the  dielectric  (water)  of  a  conical-plate  capacitor  will  be  used  to sense  water  level.  A  microcontroller  system  will be  used  to  estimate  such  liquid  level  and provided audible feedback to the user. 

------------

### Team Member:

  Andi Li\
  Jerry Shao\
  Robin Yuan\
  Sean Fu
  
------------

### New LCD Pin Assignment:

  LCD_RS  equ P1.7\
  LCD_RW  equ P1.6\
  LCD_E &nbsp; equ P1.5\
  LCD_D4 equ P2.2\
  LCD_D5  equ P2.3\
  LCD_D6  equ P2.4\
  LCD_D7   equ P2.5\
**Note:**\
  **Timer 0 input** should be at **Pin 0.6** as UART0 and SPI0 has occupied Pin 0.0 to 0.5.
  

------------


### Update History:
**2021-02-18; 22:06:12; Thursday**
- The unit of capacitance displayed on LCD is changed to pico farads now instead of  micro farads, which will give us a more preciese reading while adding the water into the cup.

------------
### Task List:
- [ ] Find the relationship between the height of liquid in the cup and its capacitance
- [ ] Indicate water level at different height
- [ ] Timer 3 ISR for counting one second 
- [ ] Add push-button algorithms to indicate when to start measuring the capacitance
- [ ] New library for the 1604 LCD
- [ ] Reduce the frequency measuring period to one-forth of a second for a faster feedback 
------------
### Schematic:
<img src="https://user-images.githubusercontent.com/68177491/108474843-c5fd8180-7244-11eb-9bd0-d1f16b9fe390.jpg" width="512" height="683"/>

------------
### Breadboard Layout:
<img src="https://user-images.githubusercontent.com/68177491/108475285-5c31a780-7245-11eb-95e6-f33e19c6c2ad.jpg" width="504" height="672"/>


------------
### Robin's Message: **Matou Sakura is the best girl**
<img src="https://user-images.githubusercontent.com/68177491/108470137-54bad000-723e-11eb-8eb2-a700d3040374.png" width="622" height="875"/>



