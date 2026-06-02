#include "Arduino.h"
#include "ER_TFTM070_7.h"
#include <SPI.h>

#define  LCD_RESET  9
#define  LCD_CS     10

// ------------------------------------------------------------ SPI Drive --------------------------------------------------------------------
#if Arduino_SPI
void ER5517Basic::SPIInit()
{
	pinMode(LCD_CS, OUTPUT);
	SPI.beginTransaction(SPISettings(8000000, MSBFIRST, SPI_MODE0));
	SPI.begin();
}
void ER5517Basic::SPISetCs(int cs)
{
	if(cs)
		digitalWrite(LCD_CS,HIGH);
	else
	  digitalWrite(LCD_CS,LOW);
}
unsigned char ER5517Basic::SPIRwByte(unsigned char value)
{
	unsigned char rec;
	rec = SPI.transfer(value);
	return rec;
}
void ER5517Basic::SPI_CmdWrite(int cmd)
{
  ER5517.SPISetCs(0);    //SS_RESET;
  ER5517.SPIRwByte(0x00);
  ER5517.SPIRwByte(cmd);
  ER5517.SPISetCs(1);    //SS_SET;
}
void ER5517Basic::SPI_DataWrite(int data)
{
  ER5517.SPISetCs(0);    //SS_RESET;
  ER5517.SPIRwByte(0x80);
  ER5517.SPIRwByte(data);
  ER5517.SPISetCs(1);    //SS_SET;
}
void ER5517Basic::SPI_DataWrite_Pixel(int data)
{
  ER5517.SPISetCs(0);    //SS_RESET;
  ER5517.SPIRwByte(0x80);
  ER5517.SPIRwByte(data);
  ER5517.SPISetCs(1);    //SS_SET;
  
  ER5517.SPISetCs(0);    //SS_RESET;
  ER5517.SPIRwByte(0x80);
  ER5517.SPIRwByte(data>>8);
  ER5517.SPISetCs(1);    //SS_SET;
}
int ER5517Basic::SPI_StatusRead(void)
{
  int temp = 0;
  ER5517.SPISetCs(0);    //SS_RESET;
  ER5517.SPIRwByte(0x40);
  temp = ER5517.SPIRwByte(0x00);
  ER5517.SPISetCs(1);    //SS_SET;
  return temp;
}

int ER5517Basic::SPI_DataRead(void)
{
  int temp = 0;
  ER5517.SPISetCs(0);    //SS_RESET;
  ER5517.SPIRwByte(0xc0);
  temp = ER5517.SPIRwByte(0x00);
  ER5517.SPISetCs(1);    //SS_SET;
  return temp;
}
#endif

//-----------------------------------------------------------------------------------------------------------------------------------

void ER5517Basic::Parallel_Init(void)
{
	#if Arduino_SPI
	ER5517.SPIInit();
	#endif
	
	#if Arduino_IIC
	ER5517.IICInit();
	#endif
}
void ER5517Basic::LCD_CmdWrite(unsigned char cmd)
{
	#if Arduino_SPI
	ER5517.SPI_CmdWrite(cmd);
	#endif
	
	#if Arduino_IIC
	ER5517.IIC_CmdWrite(cmd);
	#endif
}

void ER5517Basic::LCD_DataWrite(unsigned char data)
{
	#if Arduino_SPI
	ER5517.SPI_DataWrite(data);
	#endif
	
	#if Arduino_IIC
	ER5517.IIC_DataWrite(data);
	#endif
}

void ER5517Basic::LCD_DataWrite_Pixel(unsigned int data)
{
	#if Arduino_SPI
	ER5517.SPI_DataWrite_Pixel(data);
	#endif
	
	#if Arduino_IIC
	ER5517.IIC_DataWrite_Pixel(data);
	#endif
}


unsigned char ER5517Basic::LCD_StatusRead(void)
{
	unsigned char temp = 0;
	
	#if Arduino_SPI
	temp = ER5517.SPI_StatusRead();
	#endif
	
	#if Arduino_IIC
	temp = ER5517.IIC_StatusRead();
	#endif
	
	return temp;
}

unsigned int ER5517Basic::LCD_DataRead(void)
{
	unsigned int temp = 0;

	#if Arduino_SPI
	temp = ER5517.SPI_DataRead();
	#endif
	
	#if Arduino_IIC
	temp = ER5517.IIC_DataRead();
	#endif
	
	return temp;
}
void ER5517Basic::LCD_RegisterWrite(unsigned char Cmd,unsigned char Data)
{
	ER5517.LCD_CmdWrite(Cmd);
	ER5517.LCD_DataWrite(Data);
}  
//---------------------//
unsigned char ER5517Basic::LCD_RegisterRead(unsigned char Cmd)
{
	unsigned char temp;
	
	ER5517.LCD_CmdWrite(Cmd);
	temp=ER5517.LCD_DataRead();
	return temp;
}


void ER5517Basic::Check_SDRAM_Ready(void)
{
/*  0: SDRAM is not ready for access
  1: SDRAM is ready for access    */  
  unsigned char temp;
  do
  {
    temp=ER5517.LCD_StatusRead();
  }
  while( (temp&0x04) == 0x00 );
}
void ER5517Basic::TFT_16bit(void)
{
  unsigned char temp;
  ER5517.LCD_CmdWrite(0x01);
  temp = ER5517.LCD_DataRead();
  temp |= cSetb4;
    temp &= cClrb3;
  ER5517.LCD_DataWrite(temp);  
}
void ER5517Basic::Host_Bus_16bit(void)
{
/*  Parallel Host Data Bus Width Selection
    0: 8-bit Parallel Host Data Bus.
    1: 16-bit Parallel Host Data Bus.*/
  unsigned char temp;
  ER5517.LCD_CmdWrite(0x01);
  temp = ER5517.LCD_DataRead();
  temp |= cSetb0;
  ER5517.LCD_DataWrite(temp);
}
void ER5517Basic::RGB_16b_16bpp(void)
{
  unsigned char temp;
  ER5517.LCD_CmdWrite(0x02);
  temp = ER5517.LCD_DataRead();
  temp &= cClrb7;
  temp |= cSetb6;
  ER5517.LCD_DataWrite(temp);
}
void ER5517Basic::MemRead_Left_Right_Top_Down(void)
{
  unsigned char temp;
  ER5517.LCD_CmdWrite(0x02);
  temp = ER5517.LCD_DataRead();
  temp &= cClrb5;
  temp &= cClrb4;
  ER5517.LCD_DataWrite(temp);
}
void ER5517Basic::Graphic_Mode(void)
{
  unsigned char temp;
  ER5517.LCD_CmdWrite(0x03);
  temp = ER5517.LCD_DataRead();
    temp &= cClrb2;
  ER5517.LCD_DataWrite(temp);
}
void ER5517Basic::Memory_Select_SDRAM(void)
{
  unsigned char temp;
  ER5517.LCD_CmdWrite(0x03);
  temp = ER5517.LCD_DataRead();
    temp &= cClrb1;
    temp &= cClrb0; // B
  ER5517.LCD_DataWrite(temp);
}
void ER5517Basic::HSCAN_L_to_R(void)
{
/*  
Horizontal Scan Direction
0 : From Left to Right
1 : From Right to Left
PIP window will be disabled when HDIR set as 1.
*/
  unsigned char temp;
  
  ER5517.LCD_CmdWrite(0x12);
  temp = ER5517.LCD_DataRead();
  temp &= cClrb4;
  ER5517.LCD_DataWrite(temp);
}
void ER5517Basic::VSCAN_T_to_B(void)
{
/*  
Vertical Scan direction
0 : From Top to Bottom
1 : From bottom to Top
PIP window will be disabled when VDIR set as 1.
*/
  unsigned char temp;
  
  ER5517.LCD_CmdWrite(0x12);
  temp = ER5517.LCD_DataRead();
  temp &= cClrb3;
  ER5517.LCD_DataWrite(temp);
}
void ER5517Basic::PDATA_Set_RGB(void)
{
/*  
parallel PDATA[23:0] Output Sequence
000b : RGB.
001b : RBG.
010b : GRB.
011b : GBR.
100b : BRG.
101b : BGR.
*/
  unsigned char temp;
  
  ER5517.LCD_CmdWrite(0x12);
  temp = ER5517.LCD_DataRead();
    temp &=0xf8;
  ER5517.LCD_DataWrite(temp);
}
void ER5517Basic::PCLK_Rising(void)   
{
/*
PCLK Inversion
0: PDAT, DE, HSYNC etc. Drive(/ change) at PCLK falling edge.
1: PDAT, DE, HSYNC etc. Drive(/ change) at PCLK rising edge.
*/
  unsigned char temp;
  ER5517.LCD_CmdWrite(0x12);
  temp = ER5517.LCD_DataRead();
    temp &= cClrb7;
  ER5517.LCD_DataWrite(temp);
}
void ER5517Basic::PCLK_Falling(void)
{
/*
PCLK Inversion
0: PDAT, DE, HSYNC etc. Drive(/ change) at PCLK falling edge.
1: PDAT, DE, HSYNC etc. Drive(/ change) at PCLK rising edge.
*/
  unsigned char temp;
  ER5517.LCD_CmdWrite(0x12);
  temp = ER5517.LCD_DataRead();
    temp |= cSetb7;
  ER5517.LCD_DataWrite(temp);
}
void ER5517Basic::HSYNC_Low_Active(void)
{
/*  
HSYNC Polarity
0 : Low active.
1 : High active.
*/
  unsigned char temp;
  
  ER5517.LCD_CmdWrite(0x13);
  temp = ER5517.LCD_DataRead();
  temp &= cClrb7;
  ER5517.LCD_DataWrite(temp);
}
void ER5517Basic::HSYNC_High_Active(void)
{
/*  
HSYNC Polarity
0 : Low active.
1 : High active.
*/
  unsigned char temp;
  
  ER5517.LCD_CmdWrite(0x13);
  temp = ER5517.LCD_DataRead();   
  temp |= cSetb7;
  ER5517.LCD_DataWrite(temp);
}
void ER5517Basic::VSYNC_Low_Active(void)
{
/*  
VSYNC Polarity
0 : Low active.
1 : High active.
*/
  unsigned char temp;
  
  ER5517.LCD_CmdWrite(0x13);
  temp = ER5517.LCD_DataRead();
  temp &= cClrb6; 
  ER5517.LCD_DataWrite(temp);
}
void ER5517Basic::VSYNC_High_Active(void)
{
/*  
VSYNC Polarity
0 : Low active.
1 : High active.
*/
  unsigned char temp;
  
  ER5517.LCD_CmdWrite(0x13);
  temp = ER5517.LCD_DataRead();
  temp |= cSetb6;
  ER5517.LCD_DataWrite(temp);
}
void ER5517Basic::DE_Low_Active(void)
{
/*  
DE Polarity
0 : High active.
1 : Low active.
*/
  unsigned char temp;
  
  ER5517.LCD_CmdWrite(0x13);
  temp = ER5517.LCD_DataRead();
    temp |= cSetb5;
  ER5517.LCD_DataWrite(temp);
}
void ER5517Basic::DE_High_Active(void)
{
/*  
DE Polarity
0 : High active.
1 : Low active.
*/
  unsigned char temp;
  
  ER5517.LCD_CmdWrite(0x13);
  temp = ER5517.LCD_DataRead();
  temp &= cClrb5;
  ER5517.LCD_DataWrite(temp);
}
void ER5517Basic::Set_PCLK(unsigned char val)
{
  if(val == 1)  ER5517.PCLK_Falling();
  else      ER5517.PCLK_Rising();
}

void ER5517Basic::Set_HSYNC_Active(unsigned char val)
{
  if(val == 1)  ER5517.HSYNC_High_Active();
  else      ER5517.HSYNC_Low_Active();
}

void ER5517Basic::Set_VSYNC_Active(unsigned char val)
{
  if(val == 1)  ER5517.VSYNC_High_Active();
  else      ER5517.VSYNC_Low_Active();
}

void ER5517Basic::Set_DE_Active(unsigned char val)
{
  if(val == 1)  ER5517.DE_High_Active();
  else      ER5517.DE_Low_Active();
}
void ER5517Basic::LCD_HorizontalWidth_VerticalHeight(unsigned short WX,unsigned short HY)
{
  unsigned char temp;
  if(WX<8)
    {
  ER5517.LCD_CmdWrite(0x14);
  ER5517.LCD_DataWrite(0x00);
    
  ER5517.LCD_CmdWrite(0x15);
  ER5517.LCD_DataWrite(WX);
    
    temp=HY-1;
  ER5517.LCD_CmdWrite(0x1A);
  ER5517.LCD_DataWrite(temp);
      
  temp=(HY-1)>>8;
  ER5517.LCD_CmdWrite(0x1B);
  ER5517.LCD_DataWrite(temp);
  }
  else
  {
    temp=(WX/8)-1;
  ER5517.LCD_CmdWrite(0x14);
  ER5517.LCD_DataWrite(temp);
    
    temp=WX%8;
  ER5517.LCD_CmdWrite(0x15);
  ER5517.LCD_DataWrite(temp);
    
    temp=HY-1;
  ER5517.LCD_CmdWrite(0x1A);
  ER5517.LCD_DataWrite(temp);
      
  temp=(HY-1)>>8;
  ER5517.LCD_CmdWrite(0x1B);
  ER5517.LCD_DataWrite(temp);
  }
}
//[16h][17h]=========================================================================
void ER5517Basic::LCD_Horizontal_Non_Display(unsigned short WX)
{
  unsigned char temp;
  if(WX<8)
  {
  ER5517.LCD_CmdWrite(0x16);
  ER5517.LCD_DataWrite(0x00);
    
  ER5517.LCD_CmdWrite(0x17);
  ER5517.LCD_DataWrite(WX);
  }
  else
  {
    temp=(WX/8)-1;
  ER5517.LCD_CmdWrite(0x16);
  ER5517.LCD_DataWrite(temp);
    
    temp=WX%8;
  ER5517.LCD_CmdWrite(0x17);
  ER5517.LCD_DataWrite(temp);
  } 
}
//[18h]=========================================================================
void ER5517Basic::LCD_HSYNC_Start_Position(unsigned short WX)
{
  unsigned char temp;
  if(WX<8)
  {
  ER5517.LCD_CmdWrite(0x18);
  ER5517.LCD_DataWrite(0x00);
  }
  else
  {
    temp=(WX/8)-1;
  ER5517.LCD_CmdWrite(0x18);
  ER5517.LCD_DataWrite(temp);  
  }
}
//[19h]=========================================================================
void ER5517Basic::LCD_HSYNC_Pulse_Width(unsigned short WX)
{
  unsigned char temp;
  if(WX<8)
  {
  ER5517.LCD_CmdWrite(0x19);
  ER5517.LCD_DataWrite(0x00);
  }
  else
  {
    temp=(WX/8)-1;
  ER5517.LCD_CmdWrite(0x19);
  ER5517.LCD_DataWrite(temp);  
  }
}
//[1Ch][1Dh]=========================================================================
void ER5517Basic::LCD_Vertical_Non_Display(unsigned short HY)
{
  unsigned char temp;
    temp=HY-1;
  ER5517.LCD_CmdWrite(0x1C);
  ER5517.LCD_DataWrite(temp);

  ER5517.LCD_CmdWrite(0x1D);
  ER5517.LCD_DataWrite(temp>>8);
}
//[1Eh]=========================================================================
void ER5517Basic::LCD_VSYNC_Start_Position(unsigned short HY)
{
  unsigned char temp;
    temp=HY-1;
  ER5517.LCD_CmdWrite(0x1E);
  ER5517.LCD_DataWrite(temp);
}
//[1Fh]=========================================================================
void ER5517Basic::LCD_VSYNC_Pulse_Width(unsigned short HY)
{
  unsigned char temp;
    temp=HY-1;
  ER5517.LCD_CmdWrite(0x1F);
  ER5517.LCD_DataWrite(temp);
}
void ER5517Basic::Memory_XY_Mode(void) 
{
  unsigned char temp;

  ER5517.LCD_CmdWrite(0x5E);
  temp = ER5517.LCD_DataRead();
  temp &= cClrb2;
  ER5517.LCD_DataWrite(temp);
}
void ER5517Basic::Memory_16bpp_Mode(void)  
{
  unsigned char temp;

  ER5517.LCD_CmdWrite(0x5E);
  temp = ER5517.LCD_DataRead();
  temp &= cClrb1;
  temp |= cSetb0;
  ER5517.LCD_DataWrite(temp);
}
void ER5517Basic::Select_Main_Window_16bpp(void)
{
  unsigned char temp;
  ER5517.LCD_CmdWrite(0x10);
  temp = ER5517.LCD_DataRead();
    temp &= cClrb3;
    temp |= cSetb2;
  ER5517.LCD_DataWrite(temp);
}
void ER5517Basic::Main_Image_Start_Address(unsigned long Addr) 
{
/*
[20h] Main Image Start Address[7:2]
[21h] Main Image Start Address[15:8]
[22h] Main Image Start Address [23:16]
[23h] Main Image Start Address [31:24]
*/
  ER5517.LCD_RegisterWrite(0x20,Addr);
  ER5517.LCD_RegisterWrite(0x21,Addr>>8);
  ER5517.LCD_RegisterWrite(0x22,Addr>>16);
  ER5517.LCD_RegisterWrite(0x23,Addr>>24);
}
void ER5517Basic::Main_Image_Width(unsigned short WX)  
{
/*
[24h] Main Image Width [7:0]
[25h] Main Image Width [12:8]
Unit: Pixel.
It must be divisible by 4. MIW Bit [1:0] tie to ��0�� internally.
The value is physical pixel number. Maximum value is 8188 pixels
*/
  ER5517.LCD_RegisterWrite(0x24,WX);
  ER5517.LCD_RegisterWrite(0x25,WX>>8);
}
//[26h][27h][28h][29h]=========================================================================
void ER5517Basic::Main_Window_Start_XY(unsigned short WX,unsigned short HY)  
{
/*
[26h] Main Window Upper-Left corner X-coordination [7:0]
[27h] Main Window Upper-Left corner X-coordination [12:8]
Reference Main Image coordination.
Unit: Pixel
It must be divisible by 4. MWULX Bit [1:0] tie to ��0�� internally.
X-axis coordination plus Horizontal display width cannot large than 8188.

[28h] Main Window Upper-Left corner Y-coordination [7:0]
[29h] Main Window Upper-Left corner Y-coordination [12:8]
Reference Main Image coordination.
Unit: Pixel
Range is between 0 and 8191.
*/
  ER5517.LCD_RegisterWrite(0x26,WX);
  ER5517.LCD_RegisterWrite(0x27,WX>>8);

  ER5517.LCD_RegisterWrite(0x28,HY);
  ER5517.LCD_RegisterWrite(0x29,HY>>8);
}
void ER5517Basic::Canvas_Image_Start_address(unsigned long Addr) 
{
/*
[50h] Start address of Canvas [7:0]
[51h] Start address of Canvas [15:8]
[52h] Start address of Canvas [23:16]
[53h] Start address of Canvas [31:24]
*/
  ER5517.LCD_RegisterWrite(0x50,Addr);
  ER5517.LCD_RegisterWrite(0x51,Addr>>8);
  ER5517.LCD_RegisterWrite(0x52,Addr>>16);
  ER5517.LCD_RegisterWrite(0x53,Addr>>24);
}
//[54h][55h]=========================================================================
void ER5517Basic::Canvas_image_width(unsigned short WX)  
{
/*
[54h] Canvas image width [7:2]
[55h] Canvas image width [12:8]
*/
  ER5517.LCD_RegisterWrite(0x54,WX);
  ER5517.LCD_RegisterWrite(0x55,WX>>8);
}
//[56h][57h][58h][59h]=========================================================================
void ER5517Basic::Active_Window_XY(unsigned short WX,unsigned short HY)  
{
/*
[56h] Active Window Upper-Left corner X-coordination [7:0]
[57h] Active Window Upper-Left corner X-coordination [12:8]
[58h] Active Window Upper-Left corner Y-coordination [7:0]
[59h] Active Window Upper-Left corner Y-coordination [12:8]
*/
  ER5517.LCD_RegisterWrite(0x56,WX);
  ER5517.LCD_RegisterWrite(0x57,WX>>8);
  
  ER5517.LCD_RegisterWrite(0x58,HY);
  ER5517.LCD_RegisterWrite(0x59,HY>>8);
}
//[5Ah][5Bh][5Ch][5Dh]=========================================================================
void ER5517Basic::Active_Window_WH(unsigned short WX,unsigned short HY)  
{
/*
[5Ah] Width of Active Window [7:0]
[5Bh] Width of Active Window [12:8]
[5Ch] Height of Active Window [7:0]
[5Dh] Height of Active Window [12:8]
*/
  ER5517.LCD_RegisterWrite(0x5A,WX);
  ER5517.LCD_RegisterWrite(0x5B,WX>>8);
 
  ER5517.LCD_RegisterWrite(0x5C,HY);
  ER5517.LCD_RegisterWrite(0x5D,HY>>8);
}
void ER5517Basic::Foreground_color_65k(unsigned short temp)
{
    ER5517.LCD_CmdWrite(0xD2);
  ER5517.LCD_DataWrite(temp>>8);
 
    ER5517.LCD_CmdWrite(0xD3);
  ER5517.LCD_DataWrite(temp>>3);
  
    ER5517.LCD_CmdWrite(0xD4);
  ER5517.LCD_DataWrite(temp<<3);
}

//Input data format:R5G6B6
void ER5517Basic::Background_color_65k(unsigned short temp)
{
    ER5517.LCD_CmdWrite(0xD5);
  ER5517.LCD_DataWrite(temp>>8);
  
    ER5517.LCD_CmdWrite(0xD6);
  ER5517.LCD_DataWrite(temp>>3);
   
    ER5517.LCD_CmdWrite(0xD7);
  ER5517.LCD_DataWrite(temp<<3);
}



void ER5517Basic::Check_Busy_Draw(void)
{
  unsigned char temp;
  do
  {
    temp=ER5517.LCD_StatusRead();
  }
  while(temp&0x08);

}

void ER5517Basic::Check_2D_Busy(void)
{
  do
  {
    
  }
  while( ER5517.LCD_StatusRead()&0x08 );
}


void ER5517Basic::Check_Mem_WR_FIFO_not_Full(void)
{
/*  0: Memory Write FIFO is not full.
  1: Memory Write FIFO is full.   */
  do
  {
    
  }
  while( ER5517.LCD_StatusRead()&0x80 );
}
void ER5517Basic::Check_Mem_WR_FIFO_Empty(void)
{
/*  0: Memory Write FIFO is not empty.
  1: Memory Write FIFO is empty.    */  
  do
  {
    
  }
  while( (ER5517.LCD_StatusRead()&0x40) == 0x00 );
}
void ER5517Basic::Check_Mem_RD_FIFO_not_Full(void)
{
/*  0: Memory Read FIFO is not full.
  1: Memory Read FIFO is full.    */
  do
  {
    
  }
  while( ER5517.LCD_StatusRead()&0x20 );
}
void ER5517Basic::Check_Mem_RD_FIFO_not_Empty(void)
{
/*  0: Memory Read FIFO is not empty.
  1: Memory Read FIFO is empty.
    */
  do
  {
    
  }
  while( ER5517.LCD_StatusRead()&0x10 );
}


void ER5517Basic::DrawSquare_Fill
(
 unsigned short X1                
,unsigned short Y1              
,unsigned short X2                
,unsigned short Y2              
,unsigned long ForegroundColor   
)
{
  ER5517.Foreground_color_65k(ForegroundColor);
  ER5517.Square_Start_XY(X1,Y1);
  ER5517.Square_End_XY(X2,Y2);
  ER5517.Start_Square_Fill();
  ER5517.Check_2D_Busy();
}

void ER5517Basic::DrawCircle_Fill
(
 unsigned short X1                
,unsigned short Y1              
,unsigned short R                            
,unsigned long ForegroundColor 
)

{
  ER5517.Foreground_color_65k(ForegroundColor);
  ER5517.Circle_Center_XY(X1,Y1);
  ER5517.Circle_Radius_R(R);
  ER5517.Start_Circle_or_Ellipse_Fill();
  ER5517.Check_2D_Busy();
}


void ER5517Basic::Enable_SFlash_SPI(void)
{
/*  Serial Flash SPI Interface Enable/Disable
    0: Disable
    1: Enable*/
  unsigned char temp;
  ER5517.LCD_CmdWrite(0x01);
  temp = ER5517.LCD_DataRead();
  temp |= cSetb1;
  ER5517.LCD_DataWrite(temp);     
}

void ER5517Basic::Goto_Pixel_XY(unsigned short WX,unsigned short HY) 
{
/*
[Write]: Set Graphic Read/Write position
[Read]: Current Graphic Read/Write position
Read back is Read position or Write position depends on
REG[5Eh] bit3, Select to read back Graphic Read/Write position.
When DPRAM Linear mode:Graphic Read/Write Position [31:24][23:16][15:8][7:0]
When DPRAM Active window mode:Graphic Read/Write 
Horizontal Position [12:8][7:0], 
Vertical Position [12:8][7:0].
Reference Canvas image coordination. Unit: Pixel
*/
  ER5517.LCD_RegisterWrite(0x5F,WX);
  ER5517.LCD_RegisterWrite(0x60,WX>>8);
  
  ER5517.LCD_RegisterWrite(0x61,HY);
  ER5517.LCD_RegisterWrite(0x62,HY>>8);
}

void ER5517Basic::Goto_Text_XY(unsigned short WX,unsigned short HY)  
{
/*
Write: Set Text Write position
Read: Current Text Write position
Text Write X-coordination [12:8][7:0]
Text Write Y-coordination [12:8][7:0]
Reference Canvas image coordination.
Unit: Pixel
*/
  ER5517.LCD_RegisterWrite(0x63,WX);
  ER5517.LCD_RegisterWrite(0x64,WX>>8);
  
  ER5517.LCD_RegisterWrite(0x65,HY);
  ER5517.LCD_RegisterWrite(0x66,HY>>8);
}


//[67h]=========================================================================
/*
[bit7]Draw Line / Triangle Start Signal
Write Function
0 : Stop the drawing function.
1 : Start the drawing function.
Read Function
0 : Drawing function complete.
1 : Drawing function is processing.
[bit5]Fill function for Triangle Signal
0 : Non fill.
1 : Fill.
[bit1]Draw Triangle or Line Select Signal
0 : Draw Line
1 : Draw Triangle
*/
void ER5517Basic::Start_Line(void)
{
  ER5517.LCD_CmdWrite(0x67);
  ER5517.LCD_DataWrite(0x80);
  Check_Busy_Draw();
}
void ER5517Basic::Start_Triangle(void)
{
  ER5517.LCD_CmdWrite(0x67);
  ER5517.LCD_DataWrite(0x82);//B1000_0010
  Check_Busy_Draw();
}
void ER5517Basic::Start_Triangle_Fill(void)
{

  ER5517.LCD_CmdWrite(0x67);
  ER5517.LCD_DataWrite(0xA2);//B1010_0010
  Check_Busy_Draw();
}
//[68h][69h][6Ah][6Bh]=========================================================================
//�����
void ER5517Basic::Line_Start_XY(unsigned short WX,unsigned short HY)
{
/*
[68h] Draw Line/Square/Triangle Start X-coordination [7:0]
[69h] Draw Line/Square/Triangle Start X-coordination [12:8]
[6Ah] Draw Line/Square/Triangle Start Y-coordination [7:0]
[6Bh] Draw Line/Square/Triangle Start Y-coordination [12:8]
*/
  ER5517.LCD_CmdWrite(0x68);
  ER5517.LCD_DataWrite(WX);

  ER5517.LCD_CmdWrite(0x69);
  ER5517.LCD_DataWrite(WX>>8);

  ER5517.LCD_CmdWrite(0x6A);
  ER5517.LCD_DataWrite(HY);

  ER5517.LCD_CmdWrite(0x6B);
  ER5517.LCD_DataWrite(HY>>8);
}
//[6Ch][6Dh][6Eh][6Fh]=========================================================================
//���յ�
void ER5517Basic::Line_End_XY(unsigned short WX,unsigned short HY)
{
/*
[6Ch] Draw Line/Square/Triangle End X-coordination [7:0]
[6Dh] Draw Line/Square/Triangle End X-coordination [12:8]
[6Eh] Draw Line/Square/Triangle End Y-coordination [7:0]
[6Fh] Draw Line/Square/Triangle End Y-coordination [12:8]
*/
  ER5517.LCD_CmdWrite(0x6C);
  ER5517.LCD_DataWrite(WX);

  ER5517.LCD_CmdWrite(0x6D);
  ER5517.LCD_DataWrite(WX>>8);

  ER5517.LCD_CmdWrite(0x6E);
  ER5517.LCD_DataWrite(HY);

  ER5517.LCD_CmdWrite(0x6F);
  ER5517.LCD_DataWrite(HY>>8);
}
//[68h]~[73h]=========================================================================
//�T��-�I1
void ER5517Basic::Triangle_Point1_XY(unsigned short WX,unsigned short HY)
{
/*
[68h] Draw Line/Square/Triangle Start X-coordination [7:0]
[69h] Draw Line/Square/Triangle Start X-coordination [12:8]
[6Ah] Draw Line/Square/Triangle Start Y-coordination [7:0]
[6Bh] Draw Line/Square/Triangle Start Y-coordination [12:8]
*/
  ER5517.LCD_CmdWrite(0x68);
  ER5517.LCD_DataWrite(WX);

  ER5517.LCD_CmdWrite(0x69);
  ER5517.LCD_DataWrite(WX>>8);

  ER5517.LCD_CmdWrite(0x6A);
  ER5517.LCD_DataWrite(HY);

  ER5517.LCD_CmdWrite(0x6B);
  ER5517.LCD_DataWrite(HY>>8);
}
//�T��-�I2
void ER5517Basic::Triangle_Point2_XY(unsigned short WX,unsigned short HY)
{
/*
[6Ch] Draw Line/Square/Triangle End X-coordination [7:0]
[6Dh] Draw Line/Square/Triangle End X-coordination [12:8]
[6Eh] Draw Line/Square/Triangle End Y-coordination [7:0]
[6Fh] Draw Line/Square/Triangle End Y-coordination [12:8]
*/
  ER5517.LCD_CmdWrite(0x6C);
  ER5517.LCD_DataWrite(WX);

  ER5517.LCD_CmdWrite(0x6D);
  ER5517.LCD_DataWrite(WX>>8);

  ER5517.LCD_CmdWrite(0x6E);
  ER5517.LCD_DataWrite(HY);

  ER5517.LCD_CmdWrite(0x6F);
  ER5517.LCD_DataWrite(HY>>8);
}
//�T��-�I3
void ER5517Basic::Triangle_Point3_XY (unsigned short WX,unsigned short HY)
{
/*
[70h] Draw Triangle Point 3 X-coordination [7:0]
[71h] Draw Triangle Point 3 X-coordination [12:8]
[72h] Draw Triangle Point 3 Y-coordination [7:0]
[73h] Draw Triangle Point 3 Y-coordination [12:8]
*/
  ER5517.LCD_CmdWrite(0x70);
  ER5517.LCD_DataWrite(WX);

  ER5517.LCD_CmdWrite(0x71);
  ER5517.LCD_DataWrite(WX>>8);

  ER5517.LCD_CmdWrite(0x72);
  ER5517.LCD_DataWrite(HY);

  ER5517.LCD_CmdWrite(0x73);
  ER5517.LCD_DataWrite(HY>>8);
}

void ER5517Basic::Square_Start_XY(unsigned short WX,unsigned short HY)
{
/*
[68h] Draw Line/Square/Triangle Start X-coordination [7:0]
[69h] Draw Line/Square/Triangle Start X-coordination [12:8]
[6Ah] Draw Line/Square/Triangle Start Y-coordination [7:0]
[6Bh] Draw Line/Square/Triangle Start Y-coordination [12:8]
*/
  ER5517.LCD_CmdWrite(0x68);
  ER5517.LCD_DataWrite(WX);

  ER5517.LCD_CmdWrite(0x69);
  ER5517.LCD_DataWrite(WX>>8);

  ER5517.LCD_CmdWrite(0x6A);
  ER5517.LCD_DataWrite(HY);

  ER5517.LCD_CmdWrite(0x6B);
  ER5517.LCD_DataWrite(HY>>8);
}

void ER5517Basic::Square_End_XY(unsigned short WX,unsigned short HY)
{
/*
[6Ch] Draw Line/Square/Triangle End X-coordination [7:0]
[6Dh] Draw Line/Square/Triangle End X-coordination [12:8]
[6Eh] Draw Line/Square/Triangle End Y-coordination [7:0]
[6Fh] Draw Line/Square/Triangle End Y-coordination [12:8]
*/
  ER5517.LCD_CmdWrite(0x6C);
  ER5517.LCD_DataWrite(WX);

  ER5517.LCD_CmdWrite(0x6D);
  ER5517.LCD_DataWrite(WX>>8);

  ER5517.LCD_CmdWrite(0x6E);
  ER5517.LCD_DataWrite(HY);

  ER5517.LCD_CmdWrite(0x6F);
  ER5517.LCD_DataWrite(HY>>8);
}
//[76h]=========================================================================
/*
[bit7]
Draw Circle / Ellipse / Square /Circle Square Start Signal 
Write Function
0 : Stop the drawing function.
1 : Start the drawing function.
Read Function
0 : Drawing function complete.
1 : Drawing function is processing.
[bit6]
Fill the Circle / Ellipse / Square / Circle Square Signal
0 : Non fill.
1 : fill.
[bit5 bit4]
Draw Circle / Ellipse / Square / Ellipse Curve / Circle Square Select
00 : Draw Circle / Ellipse
01 : Draw Circle / Ellipse Curve
10 : Draw Square.
11 : Draw Circle Square.
[bit1 bit0]
Draw Circle / Ellipse Curve Part Select
00 : 
01 : 
10 : 
11 : 
*/
void ER5517Basic::Start_Circle_or_Ellipse(void)
{
  ER5517.LCD_CmdWrite(0x76);
  ER5517.LCD_DataWrite(0x80);//B1000_XXXX
  Check_Busy_Draw();  
}
void ER5517Basic::Start_Circle_or_Ellipse_Fill(void)
{
  ER5517.LCD_CmdWrite(0x76);
  ER5517.LCD_DataWrite(0xC0);//B1100_XXXX
  Check_Busy_Draw();  
}
//
void ER5517Basic::Start_Left_Down_Curve(void)
{
  ER5517.LCD_CmdWrite(0x76);
  ER5517.LCD_DataWrite(0x90);//B1001_XX00
  Check_Busy_Draw();  
}
void ER5517Basic::Start_Left_Up_Curve(void)
{
  ER5517.LCD_CmdWrite(0x76);
  ER5517.LCD_DataWrite(0x91);//B1001_XX01
  Check_Busy_Draw();  
}
void ER5517Basic::Start_Right_Up_Curve(void)
{
  ER5517.LCD_CmdWrite(0x76);
  ER5517.LCD_DataWrite(0x92);//B1001_XX10
  Check_Busy_Draw();  
}
void ER5517Basic::Start_Right_Down_Curve(void)
{
  ER5517.LCD_CmdWrite(0x76);
  ER5517.LCD_DataWrite(0x93);//B1001_XX11
  Check_Busy_Draw();  
}
//
void ER5517Basic::Start_Left_Down_Curve_Fill(void)
{
  ER5517.LCD_CmdWrite(0x76);
  ER5517.LCD_DataWrite(0xD0);//B1101_XX00
  Check_Busy_Draw();
}
void ER5517Basic::Start_Left_Up_Curve_Fill(void)
{
  ER5517.LCD_CmdWrite(0x76);
  ER5517.LCD_DataWrite(0xD1);//B1101_XX01
  Check_Busy_Draw();
}
void ER5517Basic::Start_Right_Up_Curve_Fill(void)
{
  ER5517.LCD_CmdWrite(0x76);
  ER5517.LCD_DataWrite(0xD2);//B1101_XX10
  Check_Busy_Draw();
}
void ER5517Basic::Start_Right_Down_Curve_Fill(void)
{
  ER5517.LCD_CmdWrite(0x76);
  ER5517.LCD_DataWrite(0xD3);//B1101_XX11
  Check_Busy_Draw();
}
//
void ER5517Basic::Start_Square(void)
{
  ER5517.LCD_CmdWrite(0x76);
  ER5517.LCD_DataWrite(0xA0);//B1010_XXXX
  Check_Busy_Draw();
}
void ER5517Basic::Start_Square_Fill(void)
{
  ER5517.LCD_CmdWrite(0x76);
  ER5517.LCD_DataWrite(0xE0);//B1110_XXXX
  Check_Busy_Draw();
}
void ER5517Basic::Start_Circle_Square(void)
{
  ER5517.LCD_CmdWrite(0x76);
  ER5517.LCD_DataWrite(0xB0);//B1011_XXXX
  Check_Busy_Draw();  
}
void ER5517Basic::Start_Circle_Square_Fill(void)
{
  ER5517.LCD_CmdWrite(0x76);
  ER5517.LCD_DataWrite(0xF0);//B1111_XXXX
  Check_Busy_Draw();  
}
//[77h]~[7Eh]=========================================================================

void ER5517Basic::Circle_Center_XY(unsigned short WX,unsigned short HY)
{
/*
[7Bh] Draw Circle/Ellipse/Circle Square Center X-coordination [7:0]
[7Ch] Draw Circle/Ellipse/Circle Square Center X-coordination [12:8]
[7Dh] Draw Circle/Ellipse/Circle Square Center Y-coordination [7:0]
[7Eh] Draw Circle/Ellipse/Circle Square Center Y-coordination [12:8]
*/
  ER5517.LCD_CmdWrite(0x7B);
  ER5517.LCD_DataWrite(WX);

  ER5517.LCD_CmdWrite(0x7C);
  ER5517.LCD_DataWrite(WX>>8);

  ER5517.LCD_CmdWrite(0x7D);
  ER5517.LCD_DataWrite(HY);

  ER5517.LCD_CmdWrite(0x7E);
  ER5517.LCD_DataWrite(HY>>8);
}

void ER5517Basic::Ellipse_Center_XY(unsigned short WX,unsigned short HY)
{
/*
[7Bh] Draw Circle/Ellipse/Circle Square Center X-coordination [7:0]
[7Ch] Draw Circle/Ellipse/Circle Square Center X-coordination [12:8]
[7Dh] Draw Circle/Ellipse/Circle Square Center Y-coordination [7:0]
[7Eh] Draw Circle/Ellipse/Circle Square Center Y-coordination [12:8]
*/
  ER5517.LCD_CmdWrite(0x7B);
  ER5517.LCD_DataWrite(WX);

  ER5517.LCD_CmdWrite(0x7C);
  ER5517.LCD_DataWrite(WX>>8);

  ER5517.LCD_CmdWrite(0x7D);
  ER5517.LCD_DataWrite(HY);

  ER5517.LCD_CmdWrite(0x7E);
  ER5517.LCD_DataWrite(HY>>8);
}

void ER5517Basic::Circle_Radius_R(unsigned short WX)
{
/*
[77h] Draw Circle/Ellipse/Circle Square Major radius [7:0]
[78h] Draw Circle/Ellipse/Circle Square Major radius [12:8]
[79h] Draw Circle/Ellipse/Circle Square Minor radius [7:0]
[7Ah] Draw Circle/Ellipse/Circle Square Minor radius [12:8]
*/
  ER5517.LCD_CmdWrite(0x77);
  ER5517.LCD_DataWrite(WX);

  ER5517.LCD_CmdWrite(0x78);
  ER5517.LCD_DataWrite(WX>>8);

  ER5517.LCD_CmdWrite(0x79);
  ER5517.LCD_DataWrite(WX);

  ER5517.LCD_CmdWrite(0x7A);
  ER5517.LCD_DataWrite(WX>>8);
}


void ER5517Basic::Ellipse_Radius_RxRy(unsigned short WX,unsigned short HY)
{
/*
[77h] Draw Circle/Ellipse/Circle Square Major radius [7:0]
[78h] Draw Circle/Ellipse/Circle Square Major radius [12:8]
[79h] Draw Circle/Ellipse/Circle Square Minor radius [7:0]
[7Ah] Draw Circle/Ellipse/Circle Square Minor radius [12:8]
*/
  ER5517.LCD_CmdWrite(0x77);
  ER5517.LCD_DataWrite(WX);

  ER5517.LCD_CmdWrite(0x78);
  ER5517.LCD_DataWrite(WX>>8);

  ER5517.LCD_CmdWrite(0x79);
  ER5517.LCD_DataWrite(HY);

  ER5517.LCD_CmdWrite(0x7A);
  ER5517.LCD_DataWrite(HY>>8);
}


void ER5517Basic::Circle_Square_Radius_RxRy(unsigned short WX,unsigned short HY)
{
/*
[77h] Draw Circle/Ellipse/Circle Square Major radius [7:0]
[78h] Draw Circle/Ellipse/Circle Square Major radius [12:8]
[79h] Draw Circle/Ellipse/Circle Square Minor radius [7:0]
[7Ah] Draw Circle/Ellipse/Circle Square Minor radius [12:8]
*/
  ER5517.LCD_CmdWrite(0x77);
  ER5517.LCD_DataWrite(WX);

  ER5517.LCD_CmdWrite(0x78);
  ER5517.LCD_DataWrite(WX>>8);

  ER5517.LCD_CmdWrite(0x79);
  ER5517.LCD_DataWrite(HY);

  ER5517.LCD_CmdWrite(0x7A);
  ER5517.LCD_DataWrite(HY>>8);
}

//[84h]=========================================================================
void ER5517Basic::Set_PWM_Prescaler_1_to_256(unsigned short WX)
{
/*
PWM Prescaler Register
These 8 bits determine prescaler value for Timer 0 and 1.
Time base is ��Core_Freq / (Prescaler + 1)��
*/
  WX=WX-1;
  ER5517.LCD_CmdWrite(0x84);
  ER5517.LCD_DataWrite(WX);
}
//[85h]=========================================================================
void ER5517Basic::Select_PWM1_Clock_Divided_By_1(void)
{
/*
Select MUX input for PWM Timer 1.
00 = 1; 01 = 1/2; 10 = 1/4 ; 11 = 1/8;
*/
  unsigned char temp;
  
  ER5517.LCD_CmdWrite(0x85);
  temp = ER5517.LCD_DataRead();
  temp &= cClrb7;
  temp &= cClrb6;
  ER5517.LCD_DataWrite(temp);
}
void ER5517Basic::Select_PWM1_Clock_Divided_By_2(void)
{
/*
Select MUX input for PWM Timer 1.
00 = 1; 01 = 1/2; 10 = 1/4 ; 11 = 1/8;
*/
  unsigned char temp;
  
  ER5517.LCD_CmdWrite(0x85);
  temp = ER5517.LCD_DataRead();
  temp &= cClrb7;
  temp |= cSetb6;
  ER5517.LCD_DataWrite(temp);
}
void ER5517Basic::Select_PWM1_Clock_Divided_By_4(void)
{
/*
Select MUX input for PWM Timer 1.
00 = 1; 01 = 1/2; 10 = 1/4 ; 11 = 1/8;
*/
  unsigned char temp;
  
  ER5517.LCD_CmdWrite(0x85);
  temp = ER5517.LCD_DataRead();
  temp |= cSetb7;
  temp &= cClrb6;
  ER5517.LCD_DataWrite(temp);
}
void ER5517Basic::Select_PWM1_Clock_Divided_By_8(void)
{
/*
Select MUX input for PWM Timer 1.
00 = 1; 01 = 1/2; 10 = 1/4 ; 11 = 1/8;
*/
  unsigned char temp;
  
  ER5517.LCD_CmdWrite(0x85);
  temp = ER5517.LCD_DataRead();
  temp |= cSetb7;
  temp |= cSetb6;
  ER5517.LCD_DataWrite(temp);
}
void ER5517Basic::Select_PWM0_Clock_Divided_By_1(void)
{
/*
Select MUX input for PWM Timer 0.
00 = 1; 01 = 1/2; 10 = 1/4 ; 11 = 1/8;
*/
  unsigned char temp;
  
  ER5517.LCD_CmdWrite(0x85);
  temp = ER5517.LCD_DataRead();
  temp &= cClrb5;
  temp &= cClrb4;
  ER5517.LCD_DataWrite(temp);
}
void ER5517Basic::Select_PWM0_Clock_Divided_By_2(void)
{
/*
Select MUX input for PWM Timer 0.
00 = 1; 01 = 1/2; 10 = 1/4 ; 11 = 1/8;
*/
  unsigned char temp;
  
  ER5517.LCD_CmdWrite(0x85);
  temp = ER5517.LCD_DataRead();
  temp &= cClrb5;
  temp |= cSetb4;
  ER5517.LCD_DataWrite(temp);
}
void ER5517Basic::Select_PWM0_Clock_Divided_By_4(void)
{
/*
Select MUX input for PWM Timer 0.
00 = 1; 01 = 1/2; 10 = 1/4 ; 11 = 1/8;
*/
  unsigned char temp;
  
  ER5517.LCD_CmdWrite(0x85);
  temp = ER5517.LCD_DataRead();
  temp |= cSetb5;
  temp &= cClrb4;
  ER5517.LCD_DataWrite(temp);
}
void ER5517Basic::Select_PWM0_Clock_Divided_By_8(void)
{
/*
Select MUX input for PWM Timer 0.
00 = 1; 01 = 1/2; 10 = 1/4 ; 11 = 1/8;
*/
  unsigned char temp;
  
  ER5517.LCD_CmdWrite(0x85);
  temp = ER5517.LCD_DataRead();
  temp |= cSetb5;
  temp |= cSetb4;
  ER5517.LCD_DataWrite(temp);
}
//[85h].[bit3][bit2]=========================================================================
/*
XPWM[1] pin function control
0X: XPWM[1] output system error flag (REG[00h] bit[1:0], Scan bandwidth insufficient + Memory access out of range)
10: XPWM[1] enabled and controlled by PWM timer 1
11: XPWM[1] output oscillator clock
//If XTEST[0] set high, then XPWM[1] will become panel scan clock input.
*/
void ER5517Basic::Select_PWM1_is_ErrorFlag(void)
{
  unsigned char temp;
  
  ER5517.LCD_CmdWrite(0x85);
  temp = ER5517.LCD_DataRead();
  temp &= cClrb3;
  ER5517.LCD_DataWrite(temp);
}
void ER5517Basic::Select_PWM1(void)
{
  unsigned char temp;
  
  ER5517.LCD_CmdWrite(0x85);
  temp = ER5517.LCD_DataRead();
  temp |= cSetb3;
  temp &= cClrb2;
  ER5517.LCD_DataWrite(temp);
}
void ER5517Basic::Select_PWM1_is_Osc_Clock(void)
{
  unsigned char temp;
  
  ER5517.LCD_CmdWrite(0x85);
  temp = ER5517.LCD_DataRead();
  temp |= cSetb3;
  temp |= cSetb2;
  ER5517.LCD_DataWrite(temp);
}
//[85h].[bit1][bit0]=========================================================================
/*
XPWM[0] pin function control
0X: XPWM[0] becomes GPIO-C[7]
10: XPWM[0] enabled and controlled by PWM timer 0
11: XPWM[0] output core clock
*/
void ER5517Basic::Select_PWM0_is_GPIO_C7(void)
{
  unsigned char temp;
  
  ER5517.LCD_CmdWrite(0x85);
  temp = ER5517.LCD_DataRead();
  temp &= cClrb1;
  ER5517.LCD_DataWrite(temp);
}
void ER5517Basic::Select_PWM0(void)
{
  unsigned char temp;
  
  ER5517.LCD_CmdWrite(0x85);
  temp = ER5517.LCD_DataRead();
  temp |= cSetb1;
  temp &= cClrb0;
  ER5517.LCD_DataWrite(temp);
}
void ER5517Basic::Select_PWM0_is_Core_Clock(void)
{
  unsigned char temp;
  
  ER5517.LCD_CmdWrite(0x85);
  temp = ER5517.LCD_DataRead();
  temp |= cSetb1;
  temp |= cSetb0;
  ER5517.LCD_DataWrite(temp);
}
//[86h]=========================================================================
//[86h]PWM1
void ER5517Basic::Enable_PWM1_Inverter(void)
{
/*
PWM Timer 1 output inverter on/off.
Determine the output inverter on/off for Timer 1. 
0 = Inverter off 
1 = Inverter on for PWM1
*/
  unsigned char temp;
  ER5517.LCD_CmdWrite(0x86);
  temp = ER5517.LCD_DataRead();
  temp |= cSetb6;
  ER5517.LCD_DataWrite(temp);
}
void ER5517Basic::Disable_PWM1_Inverter(void)
{
/*
PWM Timer 1 output inverter on/off.
Determine the output inverter on/off for Timer 1. 
0 = Inverter off 
1 = Inverter on for PWM1
*/
  unsigned char temp;
  ER5517.LCD_CmdWrite(0x86);
  temp = ER5517.LCD_DataRead();
  temp &= cClrb6;
  ER5517.LCD_DataWrite(temp);
}
void ER5517Basic::Auto_Reload_PWM1(void)
{
/*
PWM Timer 1 auto reload on/off
Determine auto reload on/off for Timer 1. 
0 = One-shot 
1 = Interval mode(auto reload)
*/
  unsigned char temp;
  ER5517.LCD_CmdWrite(0x86);
  temp = ER5517.LCD_DataRead();
  temp |= cSetb5;
  ER5517.LCD_DataWrite(temp);
}
void ER5517Basic::One_Shot_PWM1(void)
{
/*
PWM Timer 1 auto reload on/off
Determine auto reload on/off for Timer 1. 
0 = One-shot 
1 = Interval mode(auto reload)
*/
  unsigned char temp;
  ER5517.LCD_CmdWrite(0x86);
  temp = ER5517.LCD_DataRead();
  temp &= cClrb5;
  ER5517.LCD_DataWrite(temp);
}
void ER5517Basic::Start_PWM1(void)
{
/*
PWM Timer 1 start/stop
Determine start/stop for Timer 1. 
0 = Stop 
1 = Start for Timer 1
*/
  unsigned char temp;
  ER5517.LCD_CmdWrite(0x86);
  temp = ER5517.LCD_DataRead();
  temp |= cSetb4;
  ER5517.LCD_DataWrite(temp);
}
void ER5517Basic::Stop_PWM1(void)
{
/*
PWM Timer 1 start/stop
Determine start/stop for Timer 1. 
0 = Stop 
1 = Start for Timer 1
*/
  unsigned char temp;
  ER5517.LCD_CmdWrite(0x86);
  temp = ER5517.LCD_DataRead();
  temp &= cClrb4;
  ER5517.LCD_DataWrite(temp);
}
//[86h]PWM0
void ER5517Basic::Enable_PWM0_Dead_Zone(void)
{
/*
PWM Timer 0 Dead zone enable
Determine the dead zone operation. 0 = Disable. 1 = Enable.
*/
  unsigned char temp;
  ER5517.LCD_CmdWrite(0x86);
  temp = ER5517.LCD_DataRead();
  temp |= cSetb3;
  ER5517.LCD_DataWrite(temp);
}
void ER5517Basic::Disable_PWM0_Dead_Zone(void)
{
/*
PWM Timer 0 Dead zone enable
Determine the dead zone operation. 0 = Disable. 1 = Enable.
*/
  unsigned char temp;
  ER5517.LCD_CmdWrite(0x86);
  temp = ER5517.LCD_DataRead();
  temp &= cClrb3;
  ER5517.LCD_DataWrite(temp);
}
void ER5517Basic::Enable_PWM0_Inverter(void)
{
/*
PWM Timer 0 output inverter on/off
Determine the output inverter on/off for Timer 0. 
0 = Inverter off 
1 = Inverter on for PWM0
*/
  unsigned char temp;
  ER5517.LCD_CmdWrite(0x86);
  temp = ER5517.LCD_DataRead();
  temp |= cSetb2;
  ER5517.LCD_DataWrite(temp);
}
void ER5517Basic::Disable_PWM0_Inverter(void)
{
/*
PWM Timer 0 output inverter on/off
Determine the output inverter on/off for Timer 0. 
0 = Inverter off 
1 = Inverter on for PWM0
*/
  unsigned char temp;
  ER5517.LCD_CmdWrite(0x86);
  temp = ER5517.LCD_DataRead();
  temp &= cClrb2;
  ER5517.LCD_DataWrite(temp);
}
void ER5517Basic::Auto_Reload_PWM0(void)
{
/*
PWM Timer 0 auto reload on/off
Determine auto reload on/off for Timer 0. 
0 = One-shot 
1 = Interval mode(auto reload)
*/
  unsigned char temp;
  ER5517.LCD_CmdWrite(0x86);
  temp = ER5517.LCD_DataRead();
  temp |= cSetb1;
  ER5517.LCD_DataWrite(temp);
}
void ER5517Basic::One_Shot_PWM0(void)
{
/*
PWM Timer 1 auto reload on/off
Determine auto reload on/off for Timer 1. 
0 = One-shot 
1 = Interval mode(auto reload)
*/
  unsigned char temp;
  ER5517.LCD_CmdWrite(0x86);
  temp = ER5517.LCD_DataRead();
  temp &= cClrb1;
  ER5517.LCD_DataWrite(temp);
}
void ER5517Basic::Start_PWM0(void)
{
/*
PWM Timer 0 start/stop
Determine start/stop for Timer 0. 
0 = Stop 
1 = Start for Timer 0
*/
  unsigned char temp;
  ER5517.LCD_CmdWrite(0x86);
  temp = ER5517.LCD_DataRead();
  temp |= cSetb0;
  ER5517.LCD_DataWrite(temp);
}
void ER5517Basic::Stop_PWM0(void)
{
/*
PWM Timer 0 start/stop
Determine start/stop for Timer 0. 
0 = Stop 
1 = Start for Timer 0
*/
  unsigned char temp;
  ER5517.LCD_CmdWrite(0x86);
  temp = ER5517.LCD_DataRead();
  temp &= cClrb0;
  ER5517.LCD_DataWrite(temp);
}
//[87h]=========================================================================
void ER5517Basic::Set_Timer0_Dead_Zone_Length(unsigned char temp)
{
/*
Timer 0 Dead zone length register
These 8 bits determine the dead zone length. The 1 unit time of
the dead zone length is equal to that of timer 0.
*/
  ER5517.LCD_CmdWrite(0x87);
  ER5517.LCD_DataWrite(temp);
}
//[88h][89h]=========================================================================
void ER5517Basic::Set_Timer0_Compare_Buffer(unsigned short WX)
{
/*
Timer 0 compare buffer register
Compare buffer register total has 16 bits.
When timer counter equal or less than compare buffer register will cause PWM out
high level if inv_on bit is off.
*/
  ER5517.LCD_CmdWrite(0x88);
  ER5517.LCD_DataWrite(WX);
  ER5517.LCD_CmdWrite(0x89);
  ER5517.LCD_DataWrite(WX>>8);
}
//[8Ah][8Bh]=========================================================================
void ER5517Basic::Set_Timer0_Count_Buffer(unsigned short WX)
{
/*
Timer 0 count buffer register
Count buffer register total has 16 bits.
When timer counter equal to 0 will cause PWM timer reload Count buffer register if reload_en bit set as enable.
It may read back timer counter��s real time value when PWM timer start.
*/
  ER5517.LCD_CmdWrite(0x8A);
  ER5517.LCD_DataWrite(WX);
  ER5517.LCD_CmdWrite(0x8B);
  ER5517.LCD_DataWrite(WX>>8);
}
//[8Ch][8Dh]=========================================================================
void ER5517Basic::Set_Timer1_Compare_Buffer(unsigned short WX)
{
/*
Timer 0 compare buffer register
Compare buffer register total has 16 bits.
When timer counter equal or less than compare buffer register will cause PWM out
high level if inv_on bit is off.
*/
  ER5517.LCD_CmdWrite(0x8C);
  ER5517.LCD_DataWrite(WX);
  ER5517.LCD_CmdWrite(0x8D);
  ER5517.LCD_DataWrite(WX>>8);
}
//[8Eh][8Fh]=========================================================================
void ER5517Basic::Set_Timer1_Count_Buffer(unsigned short WX)
{
/*
Timer 0 count buffer register
Count buffer register total has 16 bits.
When timer counter equal to 0 will cause PWM timer reload Count buffer register if reload_en bit set as enable.
It may read back timer counter��s real time value when PWM timer start.
*/
  ER5517.LCD_CmdWrite(0x8E);
  ER5517.LCD_DataWrite(WX);
  ER5517.LCD_CmdWrite(0x8F);
  ER5517.LCD_DataWrite(WX>>8);
}


//[90h]~[B5h]=========================================================================

//[90h]=========================================================================
void ER5517Basic::BTE_Enable(void)
{ 
/*
BTE Function Enable
0 : BTE Function disable.
1 : BTE Function enable.
*/
    unsigned char temp;
    ER5517.LCD_CmdWrite(0x90);
    temp = ER5517.LCD_DataRead();
    temp |= cSetb4 ;
  ER5517.LCD_DataWrite(temp);  
}

//[90h]=========================================================================
void ER5517Basic::BTE_Disable(void)
{ 
/*
BTE Function Enable
0 : BTE Function disable.
1 : BTE Function enable.
*/
    unsigned char temp;
    ER5517.LCD_CmdWrite(0x90);
    temp = ER5517.LCD_DataRead();
    temp &= cClrb4 ;
  ER5517.LCD_DataWrite(temp);  
}

//[90h]=========================================================================
void ER5517Basic::Check_BTE_Busy(void)
{ 
/*
BTE Function Status
0 : BTE Function is idle.
1 : BTE Function is busy.
*/
  unsigned char temp;   
  do
  {
    temp=ER5517.LCD_StatusRead();
  }while(temp&0x08);

}
//[90h]=========================================================================
void ER5517Basic::Pattern_Format_8X8(void)
{ 
/*
Pattern Format
0 : 8X8
1 : 16X16
*/
    unsigned char temp;
    ER5517.LCD_CmdWrite(0x90);
    temp = ER5517.LCD_DataRead();
    temp &= cClrb0 ;
  ER5517.LCD_DataWrite(temp);
} 
//[90h]=========================================================================
void ER5517Basic::Pattern_Format_16X16(void)
{ 
/*
Pattern Format
0 : 8X8
1 : 16X16
*/
    unsigned char temp;
    ER5517.LCD_CmdWrite(0x90);
    temp = ER5517.LCD_DataRead();
    temp |= cSetb0 ;
    ER5517.LCD_DataWrite(temp);
} 

//[91h]=========================================================================
void ER5517Basic::BTE_ROP_Code(unsigned char setx)
{ 
/*
BTE ROP Code[Bit7:4]
  
0000 : 0(Blackness)
0001 : ~S0.~S1 or ~ ( S0+S1 )
0010 : ~S0.S1
0011 : ~S0
0100 : S0.~S1
0101 : ~S1
0110 : S0^S1
0111 : ~S0+~S1 or ~ ( S0.S1 )
1000 : S0.S1
1001 : ~ ( S0^S1 )
1010 : S1
1011 : ~S0+S1
1100 : S0
1101 : S0+~S1
1110 : S0+S1
1111 : 1 ( Whiteness )
*/
    unsigned char temp;
    ER5517.LCD_CmdWrite(0x91);
    temp = ER5517.LCD_DataRead();
    temp &= 0x0f ;
    temp |= (setx<<4);
    ER5517.LCD_DataWrite(temp);
}
  
//[91h]=========================================================================
void ER5517Basic::BTE_Operation_Code(unsigned char setx)
{ 
/*
BTE Operation Code[Bit3:0]
  
0000 : MPU Write BTE with ROP.
0001 : MPU Read BTE w/o ROP.
0010 : Memory copy (move) BTE in positive direction with ROP.
0011 : Memory copy (move) BTE in negative direction with ROP.
0100 : MPU Transparent Write BTE. (w/o ROP.)
0101 : Transparent Memory copy (move) BTE in positive direction (w/o ROP.)
0110 : Pattern Fill with ROP.
0111 : Pattern Fill with key-chroma
1000 : Color Expansion
1001 : Color Expansion with transparency
1010 : Move BTE in positive direction with Alpha blending
1011 : MPU Write BTE with Alpha blending
1100 : Solid Fill
1101 : Reserved
1110 : Reserved
1111 : Reserved
*/
    unsigned char temp;
    ER5517.LCD_CmdWrite(0x91);
    temp = ER5517.LCD_DataRead();
    temp &= 0xf0 ;
    temp |= setx ;
    ER5517.LCD_DataWrite(temp);

}
//[92h]=========================================================================
void ER5517Basic::BTE_S0_Color_8bpp(void)
{ 
/*
S0 Color Depth
00 : 256 Color
01 : 64k Color
1x : 16M Color
*/  
    unsigned char temp;
    ER5517.LCD_CmdWrite(0x92);
    temp = ER5517.LCD_DataRead();
    temp &= cClrb6 ;
    temp &= cClrb5 ;
    ER5517.LCD_DataWrite(temp);
} 
//[92h]=========================================================================
void ER5517Basic::BTE_S0_Color_16bpp(void)
{ 
/*
S0 Color Depth
00 : 256 Color
01 : 64k Color
1x : 16M Color
*/  
    unsigned char temp;
    ER5517.LCD_CmdWrite(0x92);
    temp = ER5517.LCD_DataRead();
    temp &= cClrb6 ;
    temp |= cSetb5 ;
    ER5517.LCD_DataWrite(temp);

} 
//[92h]=========================================================================
void ER5517Basic::BTE_S0_Color_24bpp(void)
{ 
/*
S0 Color Depth
00 : 256 Color
01 : 64k Color
1x : 16M Color
*/  
    unsigned char temp;
    ER5517.LCD_CmdWrite(0x92);
    temp = ER5517.LCD_DataRead();
    temp |= cSetb6 ;
    //temp |= cSetb5 ;
    ER5517.LCD_DataWrite(temp);
}
//[92h]=========================================================================
void ER5517Basic::BTE_S1_Color_8bpp(void)
{ 
/*
S1 Color Depth
000 : 256 Color
001 : 64k Color
010 : 16M Color
011 : Constant Color
100 : 8 bit pixel alpha blending
101 : 16 bit pixel alpha blending
*/  
    unsigned char temp;
    ER5517.LCD_CmdWrite(0x92);
    temp = ER5517.LCD_DataRead();
    temp &= cClrb4 ;
    temp &= cClrb3 ;
    temp &= cClrb2 ;
    ER5517.LCD_DataWrite(temp);
} 
//[92h]=========================================================================
void ER5517Basic::BTE_S1_Color_16bpp(void)
{ 
/*
S1 Color Depth
000 : 256 Color
001 : 64k Color
010 : 16M Color
011 : Constant Color
100 : 8 bit pixel alpha blending
101 : 16 bit pixel alpha blending
*/  
    unsigned char temp;
    ER5517.LCD_CmdWrite(0x92);
    temp = ER5517.LCD_DataRead();
    temp &= cClrb4 ;
    temp &= cClrb3 ;
    temp |= cSetb2 ;
    ER5517.LCD_DataWrite(temp);

}
//[92h]=========================================================================
void ER5517Basic::BTE_S1_Color_24bpp(void)
{ 
/*
S1 Color Depth
000 : 256 Color
001 : 64k Color
010 : 16M Color
011 : Constant Color
100 : 8 bit pixel alpha blending
101 : 16 bit pixel alpha blending
*/  
    unsigned char temp;
    ER5517.LCD_CmdWrite(0x92);
    temp = ER5517.LCD_DataRead();
    temp &= cClrb4 ;
    temp |= cSetb3 ;
    temp &= cClrb2 ;
    ER5517.LCD_DataWrite(temp);
}

//[92h]=========================================================================
void ER5517Basic::BTE_S1_Color_Constant(void)
{ 
/*
S1 Color Depth
000 : 256 Color
001 : 64k Color
010 : 16M Color
011 : Constant Color
100 : 8 bit pixel alpha blending
101 : 16 bit pixel alpha blending
*/  
    unsigned char temp;
    ER5517.LCD_CmdWrite(0x92);
    temp = ER5517.LCD_DataRead();
    temp &= cClrb4 ;
    temp |= cSetb3 ;
    temp |= cSetb2 ;
    ER5517.LCD_DataWrite(temp);
}



//[92h]=========================================================================
void ER5517Basic::BTE_S1_Color_8bit_Alpha(void)
{ 
/*
S1 Color Depth
000 : 256 Color
001 : 64k Color
010 : 16M Color
011 : Constant Color
100 : 8 bit pixel alpha blending
101 : 16 bit pixel alpha blending
*/  
    unsigned char temp;
    ER5517.LCD_CmdWrite(0x92);
    temp = ER5517.LCD_DataRead();
    temp |= cSetb4 ;
    temp &= cClrb3 ;
    temp &= cClrb2 ;
    ER5517.LCD_DataWrite(temp);
}

//[92h]=========================================================================
void ER5517Basic::BTE_S1_Color_16bit_Alpha(void)
{ 
/*
S1 Color Depth
000 : 256 Color
001 : 64k Color
010 : 16M Color
011 : Constant Color
100 : 8 bit pixel alpha blending
101 : 16 bit pixel alpha blending
*/  
    unsigned char temp;
    ER5517.LCD_CmdWrite(0x92);
    temp = ER5517.LCD_DataRead();
    temp |= cSetb4 ;
    temp &= cClrb3 ;
    temp |= cSetb2 ;
    ER5517.LCD_DataWrite(temp);
}

//[92h]=========================================================================
void ER5517Basic::BTE_Destination_Color_8bpp(void)
{ 
/*
Destination Color Depth
00 : 256 Color
01 : 64k Color
1x : 16M Color
*/  
    unsigned char temp;
    ER5517.LCD_CmdWrite(0x92);
    temp = ER5517.LCD_DataRead();
    temp &= cClrb1 ;
    temp &= cClrb0 ;
    ER5517.LCD_DataWrite(temp);
} 
//[92h]=========================================================================
void ER5517Basic::BTE_Destination_Color_16bpp(void)
{ 
/*
Destination Color Depth
00 : 256 Color
01 : 64k Color
1x : 16M Color
*/  
    unsigned char temp;
    ER5517.LCD_CmdWrite(0x92);
    temp = ER5517.LCD_DataRead();
    temp &= cClrb1 ;
    temp |= cSetb0 ;
    ER5517.LCD_DataWrite(temp);

} 
//[92h]=========================================================================
void ER5517Basic::BTE_Destination_Color_24bpp(void)
{ 
/*
Destination Color Depth
00 : 256 Color
10 : 64k Color
1x : 16M Color
*/  
    unsigned char temp;
    ER5517.LCD_CmdWrite(0x92);
    temp = ER5517.LCD_DataRead();
    temp |= cSetb1 ;
    //temp |= cSetb0 ;
    ER5517.LCD_DataWrite(temp);
}


//[93h][94h][95h][96h]=========================================================================
void ER5517Basic::BTE_S0_Memory_Start_Address(unsigned long Addr)  
{
/*
[93h] BTE S0 Memory Start Address [7:0]
[94h] BTE S0 Memory Start Address [15:8]
[95h] BTE S0 Memory Start Address [23:16]
[96h] BTE S0 Memory Start Address [31:24]
Bit [1:0] tie to ��0�� internally.
*/
  ER5517.LCD_RegisterWrite(0x93,Addr);
  ER5517.LCD_RegisterWrite(0x94,Addr>>8);
  ER5517.LCD_RegisterWrite(0x95,Addr>>16);
  ER5517.LCD_RegisterWrite(0x96,Addr>>24);
}


//[97h][98h]=========================================================================
void ER5517Basic::BTE_S0_Image_Width(unsigned short WX)  
{
/*
[97h] BTE S0 Image Width [7:0]
[98h] BTE S0 Image Width [12:8]
Unit: Pixel.
Bit [1:0] tie to ��0�� internally.
*/
  ER5517.LCD_RegisterWrite(0x97,WX);
  ER5517.LCD_RegisterWrite(0x98,WX>>8);
}


//[99h][9Ah][9Bh][9Ch]=========================================================================
void ER5517Basic::BTE_S0_Window_Start_XY(unsigned short WX,unsigned short HY)  
{
/*
[99h] BTE S0 Window Upper-Left corner X-coordination [7:0]
[9Ah] BTE S0 Window Upper-Left corner X-coordination [12:8]
[9Bh] BTE S0 Window Upper-Left corner Y-coordination [7:0]
[9Ch] BTE S0 Window Upper-Left corner Y-coordination [12:8]
*/
  ER5517.LCD_RegisterWrite(0x99,WX);
  ER5517.LCD_RegisterWrite(0x9A,WX>>8);

  ER5517.LCD_RegisterWrite(0x9B,HY);
  ER5517.LCD_RegisterWrite(0x9C,HY>>8);
}




//[9Dh][9Eh][9Fh][A0h]=========================================================================
void ER5517Basic::BTE_S1_Memory_Start_Address(unsigned long Addr)  
{
/*
[9Dh] BTE S1 Memory Start Address [7:0]
[9Eh] BTE S1 Memory Start Address [15:8]
[9Fh] BTE S1 Memory Start Address [23:16]
[A0h] BTE S1 Memory Start Address [31:24]
Bit [1:0] tie to ��0�� internally.
*/
  ER5517.LCD_RegisterWrite(0x9D,Addr);
  ER5517.LCD_RegisterWrite(0x9E,Addr>>8);
  ER5517.LCD_RegisterWrite(0x9F,Addr>>16);
  ER5517.LCD_RegisterWrite(0xA0,Addr>>24);
}


//Input data format:R3G3B2
void ER5517Basic::S1_Constant_color_256(unsigned char temp)
{
    ER5517.LCD_CmdWrite(0x9D);
    ER5517.LCD_DataWrite(temp);

    ER5517.LCD_CmdWrite(0x9E);
    ER5517.LCD_DataWrite(temp<<3);

    ER5517.LCD_CmdWrite(0x9F);
    ER5517.LCD_DataWrite(temp<<6);
}

//Input data format:R5G6B6
void ER5517Basic::S1_Constant_color_65k(unsigned short temp)
{
    ER5517.LCD_CmdWrite(0x9D);
    ER5517.LCD_DataWrite(temp>>8);

    ER5517.LCD_CmdWrite(0x9E);
    ER5517.LCD_DataWrite(temp>>3);

    ER5517.LCD_CmdWrite(0x9F);
    ER5517.LCD_DataWrite(temp<<3);
}

//Input data format:R8G8B8
void ER5517Basic::S1_Constant_color_16M(unsigned long temp)
{
    ER5517.LCD_CmdWrite(0x9D);
    ER5517.LCD_DataWrite(temp>>16);

    ER5517.LCD_CmdWrite(0x9E);
    ER5517.LCD_DataWrite(temp>>8);

    ER5517.LCD_CmdWrite(0x9F);
    ER5517.LCD_DataWrite(temp);
}




//[A1h][A2h]=========================================================================
void ER5517Basic::BTE_S1_Image_Width(unsigned short WX)  
{
/*
[A1h] BTE S1 Image Width [7:0]
[A2h] BTE S1 Image Width [12:8]
Unit: Pixel.
Bit [1:0] tie to ��0�� internally.
*/
  ER5517.LCD_RegisterWrite(0xA1,WX);
  ER5517.LCD_RegisterWrite(0xA2,WX>>8);
}


//[A3h][A4h][A5h][A6h]=========================================================================
void ER5517Basic::BTE_S1_Window_Start_XY(unsigned short WX,unsigned short HY)  
{
/*
[A3h] BTE S1 Window Upper-Left corner X-coordination [7:0]
[A4h] BTE S1 Window Upper-Left corner X-coordination [12:8]
[A5h] BTE S1 Window Upper-Left corner Y-coordination [7:0]
[A6h] BTE S1 Window Upper-Left corner Y-coordination [12:8]
*/
  ER5517.LCD_RegisterWrite(0xA3,WX);
  ER5517.LCD_RegisterWrite(0xA4,WX>>8);

  ER5517.LCD_RegisterWrite(0xA5,HY);
  ER5517.LCD_RegisterWrite(0xA6,HY>>8);
}




//[A7h][A8h][A9h][AAh]=========================================================================
void ER5517Basic::BTE_Destination_Memory_Start_Address(unsigned long Addr) 
{
/*
[A7h] BTE Destination Memory Start Address [7:0]
[A8h] BTE Destination Memory Start Address [15:8]
[A9h] BTE Destination Memory Start Address [23:16]
[AAh] BTE Destination Memory Start Address [31:24]
Bit [1:0] tie to ��0�� internally.
*/
  ER5517.LCD_RegisterWrite(0xA7,Addr);
  ER5517.LCD_RegisterWrite(0xA8,Addr>>8);
  ER5517.LCD_RegisterWrite(0xA9,Addr>>16);
  ER5517.LCD_RegisterWrite(0xAA,Addr>>24);
}


//[ABh][ACh]=========================================================================
void ER5517Basic::BTE_Destination_Image_Width(unsigned short WX) 
{
/*
[ABh] BTE Destination Image Width [7:0]
[ACh] BTE Destination Image Width [12:8]
Unit: Pixel.
Bit [1:0] tie to ��0�� internally.
*/
  ER5517.LCD_RegisterWrite(0xAB,WX);
  ER5517.LCD_RegisterWrite(0xAC,WX>>8);
}


//[ADh][AEh][AFh][B0h]=========================================================================
void ER5517Basic::BTE_Destination_Window_Start_XY(unsigned short WX,unsigned short HY) 
{
/*
[ADh] BTE Destination Window Upper-Left corner X-coordination [7:0]
[AEh] BTE Destination Window Upper-Left corner X-coordination [12:8]
[AFh] BTE Destination Window Upper-Left corner Y-coordination [7:0]
[B0h] BTE Destination Window Upper-Left corner Y-coordination [12:8]
*/
  ER5517.LCD_RegisterWrite(0xAD,WX);
  ER5517.LCD_RegisterWrite(0xAE,WX>>8);

  ER5517.LCD_RegisterWrite(0xAF,HY);
  ER5517.LCD_RegisterWrite(0xB0,HY>>8);
}


//[B1h][B2h][B3h][B4h]===============================================================

void ER5517Basic::BTE_Window_Size(unsigned short WX, unsigned short WY)

{
/*
[B1h] BTE Window Width [7:0]
[B2h] BTE Window Width [12:8]

[B3h] BTE Window Height [7:0]
[B4h] BTE Window Height [12:8]
*/
        ER5517.LCD_RegisterWrite(0xB1,WX);
        ER5517.LCD_RegisterWrite(0xB2,WX>>8);
  
      ER5517.LCD_RegisterWrite(0xB3,WY);
        ER5517.LCD_RegisterWrite(0xB4,WY>>8);
}

//[B5h]=========================================================================
void ER5517Basic::BTE_Alpha_Blending_Effect(unsigned char temp)
{ 
/*
Window Alpha Blending effect for S0 & S1
The value of alpha in the color code ranges from 0.0 to 1.0,
where 0.0 represents a fully transparent color, and 1.0
represents a fully opaque color.
00h: 0
01h: 1/32
02h: 2/32
:
1Eh: 30/32
1Fh: 31/32
2Xh: 1
Output Effect = (S0 image x (1 - alpha setting value)) + (S1 image x alpha setting value)
*/
    ER5517.LCD_CmdWrite(0xB5);
  ER5517.LCD_DataWrite(temp);  
}


//[B6h]=========================================================================
void ER5517Basic::Start_SFI_DMA(void)
{
  unsigned char temp;
  ER5517.LCD_CmdWrite(0xB6);
  temp = ER5517.LCD_DataRead();
    temp |= cSetb0;
  ER5517.LCD_DataWrite(temp);
}

void ER5517Basic::Check_Busy_SFI_DMA(void)
{
  ER5517.LCD_CmdWrite(0xB6);
  do
  {   
  }while((ER5517.LCD_DataRead()&0x01)==0x01);
}


//[B7h]=========================================================================
void ER5517Basic::Select_SFI_0(void)
{
/*[bit7]
Serial Flash/ROM I/F # Select
0: Serial Flash/ROM 0 I/F is selected.
1: Serial Flash/ROM 1 I/F is selected.
*/
  unsigned char temp;
  ER5517.LCD_CmdWrite(0xB7);
  temp = ER5517.LCD_DataRead();
    temp &= cClrb7;
  ER5517.LCD_DataWrite(temp);
}
void ER5517Basic::Select_SFI_1(void)
{
/*[bit7]
Serial Flash/ROM I/F # Select
0: Serial Flash/ROM 0 I/F is selected.
1: Serial Flash/ROM 1 I/F is selected.
*/
  unsigned char temp;
  ER5517.LCD_CmdWrite(0xB7);
  temp = ER5517.LCD_DataRead();
    temp |= cSetb7;
  ER5517.LCD_DataWrite(temp);
}
void ER5517Basic::Select_SFI_Font_Mode(void)
{
/*[bit6]
Serial Flash /ROM Access Mode
0: Font mode �V for external cgrom
1: DMA mode �V for cgram , pattern , bootstart image or osd
*/
  unsigned char temp;
  ER5517.LCD_CmdWrite(0xB7);
  temp = ER5517.LCD_DataRead();
    temp &= cClrb6;
  ER5517.LCD_DataWrite(temp);
}
void ER5517Basic::Select_SFI_DMA_Mode(void)
{
/*[bit6]
Serial Flash /ROM Access Mode
0: Font mode �V for external cgrom
1: DMA mode �V for cgram , pattern , bootstart image or osd
*/
  unsigned char temp;
  ER5517.LCD_CmdWrite(0xB7);
  temp = ER5517.LCD_DataRead();
    temp |= cSetb6;
  ER5517.LCD_DataWrite(temp);
}
void ER5517Basic::Select_SFI_24bit_Address(void)
{
/*[bit5]
Serial Flash/ROM Address Mode
0: 24 bits address mode
1: 32 bits address mode
*/
  unsigned char temp;
  ER5517.LCD_CmdWrite(0xB7);
  temp = ER5517.LCD_DataRead();
    temp &= cClrb5;
  ER5517.LCD_DataWrite(temp);
}
void ER5517Basic::Select_SFI_32bit_Address(void)
{
/*[bit5]
Serial Flash/ROM Address Mode
0: 24 bits address mode
1: 32 bits address mode
*/
  unsigned char temp;
  ER5517.LCD_CmdWrite(0xB7);
  temp = ER5517.LCD_DataRead();
    temp |= cSetb5;
  ER5517.LCD_DataWrite(temp);
}
void ER5517Basic::Select_SFI_Waveform_Mode_0(void)
{
/*[bit4]
Serial Flash/ROM Waveform Mode
Mode 0.
Mode 3.
*/
  unsigned char temp;
  ER5517.LCD_CmdWrite(0xB7);
  temp = ER5517.LCD_DataRead();
    temp &= cClrb4;
  ER5517.LCD_DataWrite(temp);
}
void ER5517Basic::Select_SFI_Waveform_Mode_3(void)
{
/*[bit4]
Serial Flash/ROM Waveform Mode
Mode 0.
Mode 3.
*/
  unsigned char temp;
  ER5517.LCD_CmdWrite(0xB7);
  temp = ER5517.LCD_DataRead();
    temp |= cSetb4;
  ER5517.LCD_DataWrite(temp);
}
void ER5517Basic::Select_SFI_0_DummyRead(void)
{
/*[bit3][bit2]
Serial Flash /ROM Read Cycle 0 RW
00b: no dummy cycle mode
01b: 1 dummy cycle mode
10b: 2 dummy cycle mode
11b: 4 dummy cycle mode
*/
  unsigned char temp;
  ER5517.LCD_CmdWrite(0xB7);
  temp = ER5517.LCD_DataRead();
  temp &= 0xF3;
  ER5517.LCD_DataWrite(temp);
}
void ER5517Basic::Select_SFI_8_DummyRead(void)
{
  unsigned char temp;
  ER5517.LCD_CmdWrite(0xB7);
  temp = ER5517.LCD_DataRead();
  temp &= 0xF3;
    temp |= cSetb2;
  ER5517.LCD_DataWrite(temp);
}
void ER5517Basic::Select_SFI_16_DummyRead(void)
{

  unsigned char temp;
  ER5517.LCD_CmdWrite(0xB7);
  temp = ER5517.LCD_DataRead();
  temp &= 0xF3;
    temp |= cSetb3;
  ER5517.LCD_DataWrite(temp);
}
void ER5517Basic::Select_SFI_24_DummyRead(void)
{
  unsigned char temp;
  ER5517.LCD_CmdWrite(0xB7);
  temp = ER5517.LCD_DataRead();
    temp |= 0x0c;
  ER5517.LCD_DataWrite(temp);
}
void ER5517Basic::Select_SFI_Single_Mode(void)
{
/*[bit1][bit0]
Serial Flash /ROM I/F Data Latch Mode Select
0Xb: Single Mode
10b: Dual Mode 0.
11b: Dual Mode 1.
*/
  unsigned char temp;
  ER5517.LCD_CmdWrite(0xB7);
  temp = ER5517.LCD_DataRead();
  temp &= 0xFC;
  ER5517.LCD_DataWrite(temp);
}
void ER5517Basic::Select_SFI_Dual_Mode0(void)
{
  unsigned char temp;
  ER5517.LCD_CmdWrite(0xB7);
  temp = ER5517.LCD_DataRead();
  temp &= 0xFC;
    temp |= cSetb1;
  ER5517.LCD_DataWrite(temp);
}
void ER5517Basic::Select_SFI_Dual_Mode1(void)
{
  unsigned char temp;
  ER5517.LCD_CmdWrite(0xB7);
  temp = ER5517.LCD_DataRead();
    temp |= 0x03;
  ER5517.LCD_DataWrite(temp);
}

//REG[B8h] SPI master Tx /Rx FIFO Data Register (SPIDR) 
unsigned char ER5517Basic::SPI_Master_FIFO_Data_Put(unsigned char Data)
{
    unsigned char temp;
  ER5517.LCD_CmdWrite(0xB8);
  ER5517.LCD_DataWrite(Data);
  while(Tx_FIFO_Empty_Flag()==0); 
  temp = SPI_Master_FIFO_Data_Get();
  return temp;
}

unsigned char ER5517Basic::SPI_Master_FIFO_Data_Get(void)
{
   unsigned char temp;

  while(Rx_FIFO_Empty_Flag()==1);
  ER5517.LCD_CmdWrite(0xB8);
  temp=ER5517.LCD_DataRead();
  //while(Rx_FIFO_full_flag());
   return temp;
}

//REG[B9h] SPI master Control Register (SPIMCR2) 
void ER5517Basic::Mask_SPI_Master_Interrupt_Flag(void)
{
  unsigned char temp;
  ER5517.LCD_CmdWrite(0xB9);
  temp = ER5517.LCD_DataRead();
  temp |= cSetb6;
  ER5517.LCD_DataWrite(temp);

} 

void ER5517Basic::Select_nSS_drive_on_xnsfcs0(void)
{
  unsigned char temp;
  ER5517.LCD_CmdWrite(0xB9);
  temp = ER5517.LCD_DataRead();
  temp &= cClrb5;
  ER5517.LCD_DataWrite(temp);

}

void ER5517Basic::Select_nSS_drive_on_xnsfcs1(void)
{
  unsigned char temp;
  ER5517.LCD_CmdWrite(0xB9);
  temp = ER5517.LCD_DataRead();
  temp |= cSetb5;
  ER5517.LCD_DataWrite(temp);
}

//0: inactive (nSS port will goes high) 
void ER5517Basic::nSS_Inactive(void)
{
  unsigned char temp;
  ER5517.LCD_CmdWrite(0xB9);
  temp = ER5517.LCD_DataRead();
  temp &= cClrb4;
  ER5517.LCD_DataWrite(temp);
}
//1: active (nSS port will goes low) 
void ER5517Basic::nSS_Active(void)
{
  unsigned char temp;
  ER5517.LCD_CmdWrite(0xB9);
  temp = ER5517.LCD_DataRead();
  temp |= cSetb4;
  ER5517.LCD_DataWrite(temp);
}

//Interrupt enable for FIFO overflow error [OVFIRQEN] 
void ER5517Basic::OVFIRQEN_Enable(void)
{
  unsigned char temp;
  ER5517.LCD_CmdWrite(0xB9);
  temp = ER5517.LCD_DataRead();
  temp |= cSetb3;
  ER5517.LCD_DataWrite(temp);
}
//Interrupt enable for while Tx FIFO empty & SPI engine/FSM idle
void ER5517Basic::EMTIRQEN_Enable(void)
{
  unsigned char temp;
  ER5517.LCD_CmdWrite(0xB9);
  temp = ER5517.LCD_DataRead();
  temp |= cSetb2;
  ER5517.LCD_DataWrite(temp);
}


//At CPOL=0 the base value of the clock is zero   
//o  For CPHA=0, data are read on the clock's rising edge (low->high transition) and 
//data are changed on a falling edge (high->low clock transition). 
//o  For CPHA=1, data are read on the clock's falling edge and data are changed on a 
//rising edge. 

//At CPOL=1 the base value of the clock is one (inversion of CPOL=0)   
//o  For CPHA=0, data are read on clock's falling edge and data are changed on a 
//rising edge. 
//o  For CPHA=1, data are read on clock's rising edge and data are changed on a 
//falling edge.

void ER5517Basic::Reset_CPOL(void)
{
  unsigned char temp;
  ER5517.LCD_CmdWrite(0xB9);
  temp = ER5517.LCD_DataRead();
  temp &= cClrb1;
  ER5517.LCD_DataWrite(temp);
}

void ER5517Basic::Set_CPOL(void)
{
  unsigned char temp;
  ER5517.LCD_CmdWrite(0xB9);
  temp = ER5517.LCD_DataRead();
  temp |= cSetb1;
  ER5517.LCD_DataWrite(temp);
}


void ER5517Basic::Reset_CPHA(void)
{
  unsigned char temp;
  ER5517.LCD_CmdWrite(0xB9);
  temp = ER5517.LCD_DataRead();
  temp &= cClrb0;
  ER5517.LCD_DataWrite(temp);
}

void ER5517Basic::Set_CPHA(void)
{
  unsigned char temp;
  ER5517.LCD_CmdWrite(0xB9);
  temp = ER5517.LCD_DataRead();
  temp |= cSetb0;
  ER5517.LCD_DataWrite(temp);
}


//REG[BAh] SPI master Status Register (SPIMSR) 
unsigned char ER5517Basic::Tx_FIFO_Empty_Flag(void)
{
  ER5517.LCD_CmdWrite(0xBA);
  if((ER5517.LCD_DataRead()&0x80)==0x80)
  return 1;
  else
  return 0;
}

unsigned char ER5517Basic::Tx_FIFO_Full_Flag(void)
{
  ER5517.LCD_CmdWrite(0xBA);
  if((ER5517.LCD_DataRead()&0x40)==0x40)
  return 1;
  else
  return 0;
} 

unsigned char ER5517Basic::Rx_FIFO_Empty_Flag(void)
{
  ER5517.LCD_CmdWrite(0xBA);
  if((ER5517.LCD_DataRead()&0x20)==0x20)
  return 1;
  else
  return 0;
} 

unsigned char ER5517Basic::Rx_FIFO_full_flag(void)
{
   ER5517.LCD_CmdWrite(0xBA);
   if((ER5517.LCD_DataRead()&0x10)==0x10)
   return 1;
   else
   return 0;
} 

unsigned char ER5517Basic::OVFI_Flag(void)
{
   ER5517.LCD_CmdWrite(0xBA);
   if((ER5517.LCD_DataRead()&0x08)==0x08)
   return 1;
   else
   return 0;
}

void ER5517Basic::Clear_OVFI_Flag(void)
{
   unsigned char temp;
   ER5517.LCD_CmdWrite(0xBA);
   temp = ER5517.LCD_DataRead();
   temp |= cSetb3;
   ER5517.LCD_DataWrite(temp);
}

unsigned char ER5517Basic::EMTI_Flag(void)
{
   ER5517.LCD_CmdWrite(0xBA);
   if((ER5517.LCD_DataRead()&0x04)==0x04)
   return 1;
   else
   return 0;
}

void ER5517Basic::Clear_EMTI_Flag(void)
{
   unsigned char temp;
   ER5517.LCD_CmdWrite(0xBA);
   temp = ER5517.LCD_DataRead();
   temp |= cSetb2;
   ER5517.LCD_DataWrite(temp);
}


//REG[BB] SPI Clock period (SPIDIV) 
void ER5517Basic::SPI_Clock_Period(unsigned char temp)
{
   ER5517.LCD_CmdWrite(0xBB);
   ER5517.LCD_DataWrite(temp);
} 

//[BCh][BDh][BEh][BFh]=========================================================================
void ER5517Basic::SFI_DMA_Source_Start_Address(unsigned long Addr)
{
/*
DMA Source START ADDRESS
This bits index serial flash address [7:0][15:8][23:16][31:24]
*/
  ER5517.LCD_CmdWrite(0xBC);
  ER5517.LCD_DataWrite(Addr);
  ER5517.LCD_CmdWrite(0xBD);
  ER5517.LCD_DataWrite(Addr>>8);
  ER5517.LCD_CmdWrite(0xBE);
  ER5517.LCD_DataWrite(Addr>>16);
  ER5517.LCD_CmdWrite(0xBF);
  ER5517.LCD_DataWrite(Addr>>24);
}
//[C0h][C1h][C2h][C3h]=========================================================================
void ER5517Basic::SFI_DMA_Destination_Start_Address(unsigned long Addr)
{
/*
DMA Destination START ADDRESS 
[1:0]Fix at 0
This bits index SDRAM address [7:0][15:8][23:16][31:24]
*/
  ER5517.LCD_CmdWrite(0xC0);
  ER5517.LCD_DataWrite(Addr);
  ER5517.LCD_CmdWrite(0xC1);
  ER5517.LCD_DataWrite(Addr>>8);
  ER5517.LCD_CmdWrite(0xC2);
  ER5517.LCD_DataWrite(Addr>>16);
  ER5517.LCD_CmdWrite(0xC3);
  ER5517.LCD_DataWrite(Addr>>24);
}
//[C0h][C1h][C2h][C3h]=========================================================================
void ER5517Basic::SFI_DMA_Destination_Upper_Left_Corner(unsigned short WX,unsigned short HY)
{
/*
C0h
This register defines DMA Destination Window Upper-Left corner 
X-coordination [7:0] on Canvas area. 
When REG DMACR bit 1 = 1 (Block Mode) 
This register defines Destination address [7:2] in SDRAM. 
C1h
When REG DMACR bit 1 = 0 (Linear Mode) 
This register defines DMA Destination Window Upper-Left corner 
X-coordination [12:8] on Canvas area. 
When REG DMACR bit 1 = 1 (Block Mode) 
This register defines Destination address [15:8] in SDRAM.
C2h
When REG DMACR bit 1 = 0 (Linear Mode) 
This register defines DMA Destination Window Upper-Left corner
Y-coordination [7:0] on Canvas area. 
When REG DMACR bit 1 = 1 (Block Mode) 
This register defines Destination address [23:16] in SDRAM. 
C3h
When REG DMACR bit 1 = 0 (Linear Mode) 
This register defines DMA Destination Window Upper-Left corner 
Y-coordination [12:8] on Canvas area. 
When REG DMACR bit 1 = 1 (Block Mode) 
This register defines Destination address [31:24] in SDRAM. 
*/
 
  ER5517.LCD_CmdWrite(0xC0);
  ER5517.LCD_DataWrite(WX);
  ER5517.LCD_CmdWrite(0xC1);
  ER5517.LCD_DataWrite(WX>>8);
 
  ER5517.LCD_CmdWrite(0xC2);
  ER5517.LCD_DataWrite(HY);
  ER5517.LCD_CmdWrite(0xC3);
  ER5517.LCD_DataWrite(HY>>8);
}



//[C6h][C7h][C8h][C9h]=========================================================================
void ER5517Basic::SFI_DMA_Transfer_Number(unsigned long Addr)
{
/*
Unit : Pixel
When REG DMACR bit 1 = 0 (Linear Mode)
DMA Transfer Number [7:0][15:8][23:16][31:24]

When REG DMACR bit 1 = 1 (Block Mode)
DMA Block Width [7:0][15:8]
DMA Block HIGH[7:0][15:8]
*/
  ER5517.LCD_CmdWrite(0xC6);
  ER5517.LCD_DataWrite(Addr);
  ER5517.LCD_CmdWrite(0xC7);
  ER5517.LCD_DataWrite(Addr>>8);
  ER5517.LCD_CmdWrite(0xC8);
  ER5517.LCD_DataWrite(Addr>>16);
  ER5517.LCD_CmdWrite(0xC9);
  ER5517.LCD_DataWrite(Addr>>24);
}
void ER5517Basic::SFI_DMA_Transfer_Width_Height(unsigned short WX,unsigned short HY)
{
/*
When REG DMACR bit 1 = 0 (Linear Mode)
DMA Transfer Number [7:0][15:8][23:16][31:24]

When REG DMACR bit 1 = 1 (Block Mode)
DMA Block Width [7:0][15:8]
DMA Block HIGH[7:0][15:8]
*/
  ER5517.LCD_CmdWrite(0xC6);
  ER5517.LCD_DataWrite(WX);
  ER5517.LCD_CmdWrite(0xC7);
  ER5517.LCD_DataWrite(WX>>8);

  ER5517.LCD_CmdWrite(0xC8);
  ER5517.LCD_DataWrite(HY);
  ER5517.LCD_CmdWrite(0xC9);
  ER5517.LCD_DataWrite(HY>>8);
}
//[CAh][CBh]=========================================================================
void ER5517Basic::SFI_DMA_Source_Width(unsigned short WX)
{
/*
DMA Source Picture Width [7:0][12:8]
Unit: pixel
*/
  ER5517.LCD_CmdWrite(0xCA);
  ER5517.LCD_DataWrite(WX);
  ER5517.LCD_CmdWrite(0xCB);
  ER5517.LCD_DataWrite(WX>>8);
}

//[CCh]=========================================================================

void ER5517Basic::Font_Select_UserDefine_Mode(void)
{
/*[bit7-6]
User-defined Font /CGROM Font Selection Bit in Text Mode
00 : Internal CGROM
01 : Genitop serial flash
10 : User-defined Font
*/
  unsigned char temp;
  ER5517.LCD_CmdWrite(0xCC);
  temp = ER5517.LCD_DataRead();
    temp |= cSetb7;
  temp &= cClrb6;
  ER5517.LCD_DataWrite(temp);
}
void ER5517Basic::CGROM_Select_Internal_CGROM(void)
{
/*[bit7-6]
User-defined Font /CGROM Font Selection Bit in Text Mode
00 : Internal CGROM
01 : Genitop serial flash
10 : User-defined Font
*/
  unsigned char temp;
  ER5517.LCD_CmdWrite(0xCC);
  temp = ER5517.LCD_DataRead();
  temp &= cClrb7;
    temp &= cClrb6;
  ER5517.LCD_DataWrite(temp);
}
void ER5517Basic::CGROM_Select_Genitop_FontROM(void)
{
/*[bit7-6]
User-defined Font /CGROM Font Selection Bit in Text Mode
00 : Internal CGROM
01 : Genitop serial flash
10 : User-defined Font
*/
  unsigned char temp;
  ER5517.LCD_CmdWrite(0xCC);
  temp = ER5517.LCD_DataRead();
  temp &= cClrb7;
    temp |= cSetb6;
  ER5517.LCD_DataWrite(temp);
}
void ER5517Basic::Font_Select_8x16_16x16(void)
{
/*[bit5-4]
Font Height Setting
00b : 8x16 / 16x16.
01b : 12x24 / 24x24.
10b : 16x32 / 32x32.
*** User-defined Font width is decided by font code. Genitop
serial flash��s font width is decided by font code or GT Font ROM
control register.
*/
  unsigned char temp;
  ER5517.LCD_CmdWrite(0xCC);
  temp = ER5517.LCD_DataRead();
    temp &= cClrb5;
    temp &= cClrb4;
  ER5517.LCD_DataWrite(temp);
}
void ER5517Basic::Font_Select_12x24_24x24(void)
{
/*[bit5-4]
Font Height Setting
00b : 8x16 / 16x16.
01b : 12x24 / 24x24.
10b : 16x32 / 32x32.
*** User-defined Font width is decided by font code. Genitop
serial flash��s font width is decided by font code or GT Font ROM
control register.
*/
  unsigned char temp;
  ER5517.LCD_CmdWrite(0xCC);
  temp = ER5517.LCD_DataRead();
    temp &= cClrb5;
    temp |= cSetb4;
  ER5517.LCD_DataWrite(temp);
}
void ER5517Basic::Font_Select_16x32_32x32(void)
{
/*[bit5-4]
Font Height Setting
00b : 8x16 / 16x16.
01b : 12x24 / 24x24.
10b : 16x32 / 32x32.
*** User-defined Font width is decided by font code. Genitop
serial flash��s font width is decided by font code or GT Font ROM
control register.
*/
  unsigned char temp;
  ER5517.LCD_CmdWrite(0xCC);
  temp = ER5517.LCD_DataRead();
    temp |= cSetb5;
    temp &= cClrb4;
  ER5517.LCD_DataWrite(temp);
}
void ER5517Basic::Internal_CGROM_Select_ISOIEC8859_1(void)
{
/*
Font Selection for internal CGROM
When FNCR0 B7 = 0 and B5 = 0, Internal CGROM supports the
8x16 character sets with the standard coding of ISO/IEC 8859-1~4, 
which supports English and most of European country languages.
00b : ISO/IEC 8859-1.
01b : ISO/IEC 8859-2.
10b : ISO/IEC 8859-3.
11b : ISO/IEC 8859-4.
*/
  unsigned char temp;
  ER5517.LCD_CmdWrite(0xCC);
  temp = ER5517.LCD_DataRead();
    temp &= cClrb1;
    temp &= cClrb0;
  ER5517.LCD_DataWrite(temp);
}
void ER5517Basic::Internal_CGROM_Select_ISOIEC8859_2(void)
{
/*
Font Selection for internal CGROM
When FNCR0 B7 = 0 and B5 = 0, Internal CGROM supports the
8x16 character sets with the standard coding of ISO/IEC 8859-1~4, 
which supports English and most of European country languages.
00b : ISO/IEC 8859-1.
01b : ISO/IEC 8859-2.
10b : ISO/IEC 8859-3.
11b : ISO/IEC 8859-4.
*/
  unsigned char temp;
  ER5517.LCD_CmdWrite(0xCC);
  temp = ER5517.LCD_DataRead();
    temp &= cClrb1;
    temp |= cSetb0;
  ER5517.LCD_DataWrite(temp);
}
void ER5517Basic::Internal_CGROM_Select_ISOIEC8859_3(void)
{
/*
Font Selection for internal CGROM
When FNCR0 B7 = 0 and B5 = 0, Internal CGROM supports the
8x16 character sets with the standard coding of ISO/IEC 8859-1~4, 
which supports English and most of European country languages.
00b : ISO/IEC 8859-1.
01b : ISO/IEC 8859-2.
10b : ISO/IEC 8859-3.
11b : ISO/IEC 8859-4.
*/
  unsigned char temp;
  ER5517.LCD_CmdWrite(0xCC);
  temp = ER5517.LCD_DataRead();
    temp |= cSetb1;
    temp &= cClrb0;
  ER5517.LCD_DataWrite(temp);
}
void ER5517Basic::Internal_CGROM_Select_ISOIEC8859_4(void)
{
/*
Font Selection for internal CGROM
When FNCR0 B7 = 0 and B5 = 0, Internal CGROM supports the
8x16 character sets with the standard coding of ISO/IEC 8859-1~4, 
which supports English and most of European country languages.
00b : ISO/IEC 8859-1.
01b : ISO/IEC 8859-2.
10b : ISO/IEC 8859-3.
11b : ISO/IEC 8859-4.
*/
  unsigned char temp;
  ER5517.LCD_CmdWrite(0xCC);
  temp = ER5517.LCD_DataRead();
    temp |= cSetb1;
    temp |= cSetb0;
  ER5517.LCD_DataWrite(temp);
}
//[CDh]=========================================================================
void ER5517Basic::Enable_Font_Alignment(void)
{
/*
Full Alignment Selection Bit
0 : Full alignment disable.
1 : Full alignment enable.
*/
  unsigned char temp;
  ER5517.LCD_CmdWrite(0xCD);
  temp = ER5517.LCD_DataRead();
    temp |= cSetb7;
  ER5517.LCD_DataWrite(temp);
}
void ER5517Basic::Disable_Font_Alignment(void)
{
/*
Full Alignment Selection Bit
0 : Full alignment disable.
1 : Full alignment enable.
*/
  unsigned char temp;
  ER5517.LCD_CmdWrite(0xCD);
  temp = ER5517.LCD_DataRead();
    temp &= cClrb7;
  ER5517.LCD_DataWrite(temp);
}
void ER5517Basic::Font_Background_select_Transparency(void)
{
/*
Font Transparency
0 : Font with background color.
1 : Font with background transparency.
*/
  unsigned char temp;
  ER5517.LCD_CmdWrite(0xCD);
  temp = ER5517.LCD_DataRead();
    temp |= cSetb6;
  ER5517.LCD_DataWrite(temp);
}
void ER5517Basic::Font_Background_select_Color(void)
{
/*
Font Transparency
0 : Font with background color.
1 : Font with background transparency.
*/
  unsigned char temp;
  ER5517.LCD_CmdWrite(0xCD);
  temp = ER5517.LCD_DataRead();
    temp &= cClrb6;
  ER5517.LCD_DataWrite(temp);
}
void ER5517Basic::Font_0_degree(void)
{
/*
Font Rotation
0 : Normal
Text direction from left to right then from top to bottom
1 : Counterclockwise 90 degree & horizontal flip
Text direction from top to bottom then from left to right
(it should accommodate with set VDIR as 1)
This attribute can be changed only when previous font write
finished (core_busy = 0)
*/
  unsigned char temp;
  ER5517.LCD_CmdWrite(0xCD);
  temp = ER5517.LCD_DataRead();
    temp &= cClrb4;
  ER5517.LCD_DataWrite(temp);
}
void ER5517Basic::Font_90_degree(void)
{
/*
Font Rotation
0 : Normal
Text direction from left to right then from top to bottom
1 : Counterclockwise 90 degree & horizontal flip
Text direction from top to bottom then from left to right
(it should accommodate with set VDIR as 1)
This attribute can be changed only when previous font write
finished (core_busy = 0)
*/
  unsigned char temp;
  ER5517.LCD_CmdWrite(0xCD);
  temp = ER5517.LCD_DataRead();
    temp |= cSetb4;
  ER5517.LCD_DataWrite(temp);
}
void ER5517Basic::Font_Width_X1(void)
{
/*
Horizontal Font Enlargement
00b : X1.
01b : X2.
10b : X3.
11b : X4.
*/
  unsigned char temp;
  ER5517.LCD_CmdWrite(0xCD);
  temp = ER5517.LCD_DataRead();
    temp &= cClrb3;
    temp &= cClrb2;
  ER5517.LCD_DataWrite(temp);
}
void ER5517Basic::Font_Width_X2(void)
{
/*
Horizontal Font Enlargement
00b : X1.
01b : X2.
10b : X3.
11b : X4.
*/
  unsigned char temp;
  ER5517.LCD_CmdWrite(0xCD);
  temp = ER5517.LCD_DataRead();
    temp &= cClrb3;
    temp |= cSetb2;
  ER5517.LCD_DataWrite(temp);
}
void ER5517Basic::Font_Width_X3(void)
{
/*
Horizontal Font Enlargement
00b : X1.
01b : X2.
10b : X3.
11b : X4.
*/
  unsigned char temp;
  ER5517.LCD_CmdWrite(0xCD);
  temp = ER5517.LCD_DataRead();
    temp |= cSetb3;
    temp &= cClrb2;
  ER5517.LCD_DataWrite(temp);
}
void ER5517Basic::Font_Width_X4(void)
{
/*
Horizontal Font Enlargement
00b : X1.
01b : X2.
10b : X3.
11b : X4.
*/
  unsigned char temp;
  ER5517.LCD_CmdWrite(0xCD);
  temp = ER5517.LCD_DataRead();
    temp |= cSetb3;
    temp |= cSetb2;
  ER5517.LCD_DataWrite(temp);
}
void ER5517Basic::Font_Height_X1(void)
{
/*
Vertical Font Enlargement
00b : X1.
01b : X2.
10b : X3.
11b : X4.
*/
  unsigned char temp;
  ER5517.LCD_CmdWrite(0xCD);
  temp = ER5517.LCD_DataRead();
    temp &= cClrb1;
    temp &= cClrb0;
  ER5517.LCD_DataWrite(temp);
}
void ER5517Basic::Font_Height_X2(void)
{
/*
Vertical Font Enlargement
00b : X1.
01b : X2.
10b : X3.
11b : X4.
*/
  unsigned char temp;
  ER5517.LCD_CmdWrite(0xCD);
  temp = ER5517.LCD_DataRead();
    temp &= cClrb1;
    temp |= cSetb0;
  ER5517.LCD_DataWrite(temp);
}
void ER5517Basic::Font_Height_X3(void)
{
/*
Vertical Font Enlargement
00b : X1.
01b : X2.
10b : X3.
11b : X4.
*/
  unsigned char temp;
  ER5517.LCD_CmdWrite(0xCD);
  temp = ER5517.LCD_DataRead();
    temp |= cSetb1;
    temp &= cClrb0;
  ER5517.LCD_DataWrite(temp);
}
void ER5517Basic::Font_Height_X4(void)
{
/*
Vertical Font Enlargement
00b : X1.
01b : X2.
10b : X3.
11b : X4.
*/
  unsigned char temp;
  ER5517.LCD_CmdWrite(0xCD);
  temp = ER5517.LCD_DataRead();
    temp |= cSetb1;
    temp |= cSetb0;
  ER5517.LCD_DataWrite(temp);
}



//[D0h]=========================================================================
void ER5517Basic::Font_Line_Distance(unsigned char temp)
{
/*[bit4-0]
Font Line Distance Setting
Setting the font character line distance when setting memory font
write cursor auto move. (Unit: pixel)
*/
  ER5517.LCD_CmdWrite(0xD0);
  ER5517.LCD_DataWrite(temp);
}
//[D1h]=========================================================================
void ER5517Basic::Set_Font_to_Font_Width(unsigned char temp)
{
/*[bit5-0]
Font to Font Width Setting (Unit: pixel)
*/
  ER5517.LCD_CmdWrite(0xD1);
  ER5517.LCD_DataWrite(temp);
}



void ER5517Basic::MemWrite_Left_Right_Top_Down(void)
{
  unsigned char temp;
  ER5517.LCD_CmdWrite(0x02);
  temp = ER5517.LCD_DataRead();
  temp &= cClrb2;
  temp &= cClrb1;
  ER5517.LCD_DataWrite(temp);
}

void ER5517Basic::System_Check_Temp(void)
{
  unsigned char i=0,j=0;
  unsigned char temp=0;
  unsigned char system_ok=0;
  do
  {
    j = ER5517.LCD_StatusRead();
    if((j&0x02)==0x00)    
    {
      delay(2);                  //MCU too fast, necessary
      ER5517.LCD_CmdWrite(0x01);
      delay(2);                  //MCU too fast, necessary
      temp = ER5517.LCD_DataRead();
      if((temp & 0x80) == 0x80)       //Check CCR register's PLL is ready or not
      {
        system_ok=1;
        i=0;
      }
      else
      {
        delay(2); //MCU too fast, necessary
        ER5517.LCD_CmdWrite(0x01);
        delay(2); //MCU too fast, necessary
        ER5517.LCD_DataWrite(0x80);
      }
    }
    else
    {
      system_ok=0;
      i++;
    }
    if(system_ok==0 && i==5)
    {
      ER5517.HW_Reset(); //note1
      i=0;
    }
  }while(system_ok==0);
}

void ER5517Basic::PLL_Initial(void) 
{
	unsigned short lpllOD_sclk, lpllOD_cclk, lpllOD_mclk;
	unsigned short lpllR_sclk, lpllR_cclk, lpllR_mclk;
	unsigned short lpllN_sclk, lpllN_cclk, lpllN_mclk;

	//Fout = Fin*(N/R)/OD
	//Fout = 10*N/(2*5) = N
	lpllOD_sclk = 2;
	lpllOD_cclk = 2;
	lpllOD_mclk = 2;
	lpllR_sclk  = 5;
	lpllR_cclk  = 5;
	lpllR_mclk  = 5;
	lpllN_sclk  = 60;   // TFT PCLK out put frequency:65
	lpllN_cclk  = 100;    // Core CLK:100
	lpllN_mclk  = 100;    // SRAM CLK:100
	  
	ER5517.LCD_CmdWrite(0x05);
	ER5517.LCD_DataWrite((lpllOD_sclk<<6) | (lpllR_sclk<<1) | ((lpllN_sclk>>8)&0x1));
	ER5517.LCD_CmdWrite(0x07);
	ER5517.LCD_DataWrite((lpllOD_mclk<<6) | (lpllR_mclk<<1) | ((lpllN_mclk>>8)&0x1));
	ER5517.LCD_CmdWrite(0x09);
	ER5517.LCD_DataWrite((lpllOD_cclk<<6) | (lpllR_cclk<<1) | ((lpllN_cclk>>8)&0x1));

	ER5517.LCD_CmdWrite(0x06);
	ER5517.LCD_DataWrite(lpllN_sclk);
	ER5517.LCD_CmdWrite(0x08);
	ER5517.LCD_DataWrite(lpllN_mclk);
	ER5517.LCD_CmdWrite(0x0a);
	ER5517.LCD_DataWrite(lpllN_cclk);

	ER5517.LCD_CmdWrite(0x00);
	delayMicroseconds(1);
	ER5517.LCD_DataWrite(0x80);
	delay(1);
	//set pwm0 pwm1 100%
	ER5517.LCD_CmdWrite(0x85);
	ER5517.LCD_DataWrite(0x0a);
	ER5517.LCD_CmdWrite(0x88);
	ER5517.LCD_DataWrite(0x64);
	ER5517.LCD_CmdWrite(0x8a);
	ER5517.LCD_DataWrite(0x64);
	ER5517.LCD_CmdWrite(0x8c);
	ER5517.LCD_DataWrite(0x64);
	ER5517.LCD_CmdWrite(0x8e);
	ER5517.LCD_DataWrite(0x64);
	ER5517.LCD_CmdWrite(0x86);
	ER5517.LCD_DataWrite(0x33);
/*
        unsigned char CCLK = 0;
        unsigned char MCLK = 0;
        unsigned char SCLK = 0;
        unsigned long temp = 0;
	unsigned long temp1 = 0;
	unsigned long temp2 = 0;
	unsigned long temp3 = 0;
	
	unsigned short lpllOD_sclk, lpllOD_cclk, lpllOD_mclk;
	unsigned short lpllR_sclk, lpllR_cclk, lpllR_mclk;
	unsigned short lpllN_sclk, lpllN_cclk, lpllN_mclk;
	
	
	//temp = (LCD_HBPD + LCD_HFPD + LCD_HSPW + LCD_XSIZE_TFT) * (LCD_VBPD + LCD_VFPD + LCD_VSPW+LCD_YSIZE_TFT) * 60;   
	temp1 = LCD_HBPD + LCD_HFPD + LCD_HSPW + LCD_XSIZE_TFT;
	temp2 = LCD_VBPD + LCD_VFPD + LCD_VSPW+LCD_YSIZE_TFT;
	temp = temp1 * temp2 * 60;
	

	temp3 = ((temp%1000000)/100000);
	if(temp3>=5)
		 temp = temp / 1000000 + 1;
	else temp = temp / 1000000;
	
	SCLK = temp;
	temp = temp * 3;
	MCLK = temp;
	CCLK = temp;
	
	if(CCLK > 100)	CCLK = 100;
	if(MCLK > 100)	MCLK = 100;
	if(SCLK > 65)	SCLK = 65;



////// XI_10M 	
	
	lpllOD_sclk = 3;
	lpllOD_cclk = 2;
	lpllOD_mclk = 2;
	lpllR_sclk  = 5;
	lpllR_cclk  = 5;
	lpllR_mclk  = 5;
	lpllN_mclk  = MCLK;      
	lpllN_cclk  = CCLK;    
	lpllN_sclk  = 2*SCLK; 
	


	ER5517.LCD_CmdWrite(0x05);
	ER5517.LCD_DataWrite((lpllOD_sclk<<6) | (lpllR_sclk<<1) | ((lpllN_sclk>>8)&0x1));
	ER5517.LCD_CmdWrite(0x07);
	ER5517.LCD_DataWrite((lpllOD_mclk<<6) | (lpllR_mclk<<1) | ((lpllN_mclk>>8)&0x1));
	ER5517.LCD_CmdWrite(0x09);
	ER5517.LCD_DataWrite((lpllOD_cclk<<6) | (lpllR_cclk<<1) | ((lpllN_cclk>>8)&0x1));

	ER5517.LCD_CmdWrite(0x06);
	ER5517.LCD_DataWrite(lpllN_sclk);
	ER5517.LCD_CmdWrite(0x08);
	ER5517.LCD_DataWrite(lpllN_mclk);
	ER5517.LCD_CmdWrite(0x0a);
	ER5517.LCD_DataWrite(lpllN_cclk);
      
	ER5517.LCD_CmdWrite(0x00);
	delayMicroseconds(1);
	ER5517.LCD_DataWrite(0x80);

	delay(1);
*/
}


void ER5517Basic::SDRAM_initail(void)
{
  unsigned short sdram_itv;
  
  ER5517.LCD_RegisterWrite(0xe0,0x29);      
  ER5517.LCD_RegisterWrite(0xe1,0x03); //CAS:2=0x02�ACAS:3=0x03
  sdram_itv = (64000000 / 8192) / (1000/60) ;
  sdram_itv-=2;

  ER5517.LCD_RegisterWrite(0xe2,sdram_itv);
  ER5517.LCD_RegisterWrite(0xe3,sdram_itv >>8);
  ER5517.LCD_RegisterWrite(0xe4,0x01);
  ER5517.Check_SDRAM_Ready();
  delay(1);
}
void ER5517Basic::HW_Reset(void)
{
	pinMode(LCD_RESET, OUTPUT);
  digitalWrite(LCD_RESET, LOW);
  delay(500);
  digitalWrite(LCD_RESET, HIGH);
  delay(500);
}

void ER5517Basic::initial(void)
{

    ER5517.PLL_Initial();
  
    ER5517.SDRAM_initail();

//**[01h]**//
    ER5517.TFT_16bit();
  ER5517.Host_Bus_16bit(); //Host bus 16bit
      
//**[02h]**//
  ER5517.RGB_16b_16bpp();
  ER5517.MemWrite_Left_Right_Top_Down(); 
      
//**[03h]**//
  ER5517.Graphic_Mode();
  ER5517.Memory_Select_SDRAM();

  ER5517.HSCAN_L_to_R();     //REG[12h]:from left to right
  ER5517.VSCAN_T_to_B();       //REG[12h]:from top to bottom
  ER5517.PDATA_Set_RGB();        //REG[12h]:Select RGB output

  ER5517.Set_PCLK(LCD_PCLK_Falling_Rising);   //LCD_PCLK_Falling_Rising
  ER5517.Set_HSYNC_Active(LCD_HSYNC_Active_Polarity);
  ER5517.Set_VSYNC_Active(LCD_VSYNC_Active_Polarity);
  ER5517.Set_DE_Active(LCD_DE_Active_Polarity);
 
  ER5517.LCD_HorizontalWidth_VerticalHeight(LCD_XSIZE_TFT ,LCD_YSIZE_TFT);
  ER5517.LCD_Horizontal_Non_Display(LCD_HBPD);                          
  ER5517.LCD_HSYNC_Start_Position(LCD_HFPD);                              
  ER5517.LCD_HSYNC_Pulse_Width(LCD_HSPW);                              
  ER5517.LCD_Vertical_Non_Display(LCD_VBPD);                               
  ER5517.LCD_VSYNC_Start_Position(LCD_VFPD);                               
  ER5517.LCD_VSYNC_Pulse_Width(LCD_VSPW);                              
      
  ER5517.Select_Main_Window_16bpp();

  ER5517.Memory_XY_Mode(); //Block mode (X-Y coordination addressing)
  ER5517.Memory_16bpp_Mode();
  ER5517.Select_Main_Window_16bpp();
}
void ER5517Basic::Display_ON(void)
{
/*  
Display ON/OFF
0b: Display Off.
1b: Display On.
*/
  unsigned char temp;
  
  ER5517.LCD_CmdWrite(0x12);
  temp = ER5517.LCD_DataRead();
  temp |= cSetb6;
  ER5517.LCD_DataWrite(temp);
}

void ER5517Basic::DMA_24bit_Block
(
 unsigned char SCS         // Select SPI : SCS��0       SCS��1
,unsigned char Clk         // SPI Clock = System Clock /{(Clk+1)*2}
,unsigned short X1         // Transfer to SDRAM address:X1
,unsigned short Y1         // Transfer to SDRAM address:Y1
,unsigned short X_W        // DMA data width
,unsigned short Y_H        // DMA data height
,unsigned short P_W        // Picture's width
,unsigned long Addr        // Flash address
)
{
  ER5517.Enable_SFlash_SPI();                            
  if(SCS == 0)  ER5517.Select_SFI_0();                   // Select SPI0
  if(SCS == 1)  ER5517.Select_SFI_1();                   // Select SPI1
	
  ER5517.Memory_XY_Mode();                     
  ER5517.Select_SFI_DMA_Mode();                          // Select SPI DMA mode
  ER5517.SPI_Clock_Period(Clk);                          // Select SPI clock

  ER5517.Goto_Pixel_XY(X1,Y1);                           // Setting the location of memory in the graphic mode
  ER5517.SFI_DMA_Destination_Upper_Left_Corner(X1,Y1);   // DMA destination(SDRAM address)
  ER5517.SFI_DMA_Transfer_Width_Height(X_W,Y_H);         // Setting Block data: width&height
  ER5517.SFI_DMA_Source_Width(P_W);                      // Setting the width of the source data
  ER5517.SFI_DMA_Source_Start_Address(Addr);             // Setting the FLASH address of the source data

  ER5517.Start_SFI_DMA();                                
  ER5517.Check_Busy_SFI_DMA();                        
}

void ER5517Basic::Text_Mode(void)
{
  unsigned char temp;
  ER5517.LCD_CmdWrite(0x03);
  temp = ER5517.LCD_DataRead();
    temp |= cSetb2;
  ER5517.LCD_DataWrite(temp);
}

void ER5517Basic::Show_String(char *str)
{   
    Text_Mode();     
    ER5517.LCD_CmdWrite(0x04);
    while(*str != '\0')
    {
      ER5517.LCD_DataWrite(*str);
      Check_Mem_WR_FIFO_not_Full();
      ++str;   
    }
    Check_2D_Busy();

    Graphic_Mode(); //back to graphic mode;
}

void ER5517Basic::DrawPixel(unsigned short x,unsigned short y,unsigned short color)
{  
 //   ER5517.Goto_Pixel_XY(x,y);
    ER5517.LCD_CmdWrite(0x04); 
    ER5517.LCD_DataWrite(color);
    Check_Mem_WR_FIFO_not_Full();
    ER5517.LCD_DataWrite(color>>8);
    Check_Mem_WR_FIFO_not_Full();  
}  


void ER5517Basic::Show_picture(unsigned long numbers,const unsigned char *datap)
{   
  unsigned long i;

  ER5517.LCD_CmdWrite(0x04);  
  for(i=0;i<numbers*2;i+=2)
  {
    ER5517.LCD_DataWrite(pgm_read_byte(&datap[i+1]));
    Check_Mem_WR_FIFO_not_Full();
    ER5517.LCD_DataWrite(pgm_read_byte(&datap[i]));
    Check_Mem_WR_FIFO_not_Full();
  }

}

ER5517Basic ER5517=ER5517Basic();

