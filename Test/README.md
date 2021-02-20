# Instruction for Testing the Prototype Board

------------
## Procedures (USE 9v BATTERY AND PLUG IN THE USB CABLE):

**Before procceding futher, please make sure you have:** \
I: Checked if any IC chips are dispating an unreasonble amount of heat\
II: Measured all terminals and pins that have a rated voltage on the provided schematic

After performing the preliminary checks, you should:\
A: Download all files in this folder\
B: Flash the provided wav file onto the chip\
C: Test the LCD Function\
D: Test the Capacitance Meter Function\
E: Test the Speaker Function

------------

## Part A:
There are SIX files in total for you to download. \
Make sure you get all your libraries from this folder instead of your achived labs and projects.


**File List:** 
- Computer_Sender.exe
- LCD_4bit.inc
- math32.inc
- voice.wav
- test.asm
- EFM8_Receiver.asm
-------------



## Part B:
1. Switch your system to windows
2. Open CrossIDE
3. Compile EFM8_Receiver.asm 
4. Flash it onto the board
5. Remeber your **SERIAL PORT NUMBER/ COM[ ]**
6. Press the windows/command key 
7. Search for command prompt
8. Run it as administrator
 
**Depending on you directory, your commands might be slightly different** \
**Here is a list of commands you might find useful:** 
```
 cd C:\Users\circl\OneDrive\Desktop\ELEC-Y2T2\ELEC 291_Electrical Engineering Design Studio I\Project 1\
 Computer_Sender -DCOM[] -w -v voice.wav \\ Replace the DCOM[] with you serial port number
```
9. Use the first line of code to goto the correct folder
 10. Use the second line of code to flash the music
  
 **If you have loaded the wav file correctly, you should see something like this:**
 <img src="https://user-images.githubusercontent.com/68177491/108592248-d0da1400-7321-11eb-81f8-e91c593d524d.png" width="520" height="300"/>\
11. (Optional) Press boot button see if any sound comes out\
12.  Flash EFM8_Receiver.asm onto the board

-------------

## PART C, D AND E:
1. After flashing and reseting the EFM8, you should be able to see a string, "LCD IS WORKING" displayed on the LCD

  <img src="https://user-images.githubusercontent.com/68177491/108593207-4e545300-7327-11eb-9c07-8737f5f5159e.jpg" width="378" height="504"/>\

2. In five seconds, the LCD will start to display the reading of the capacitance meter 

<img src="https://user-images.githubusercontent.com/68177491/108593261-9d01ed00-7327-11eb-9a50-7ac01816d871.jpg" width="378" height="504"/>\

3. Three seconds later, if you hold the boot button for one second and then release it, the LCD will show another string, "SPEAKER IS ON". Meanwhile, you should also be able to hear voice from the speaker

<img src="https://user-images.githubusercontent.com/68177491/108593263-9e331a00-7327-11eb-9516-349f91ae194c.jpg" width="378" height="504"/>\
                                                                                                                                        
-------------
**This test project is sponsored by Matou Sakura**\
<img src="https://user-images.githubusercontent.com/68177491/108592567-3f6ba180-7323-11eb-9a9e-3023a3b0d357.jpg" width="512" height="384"/>
