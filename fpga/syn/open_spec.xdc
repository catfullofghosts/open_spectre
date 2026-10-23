## This file is a general .xdc for the ARTY Z7-7020 Rev.B
## To use it in a project:
## - uncomment the lines corresponding to used pins
## - rename the used ports (in each line, after get_ports) according to the top level signal names in the project

## Clock signal

#set_property -dict { PACKAGE_PIN H16    IOSTANDARD LVCMOS33 } [get_ports { clk }]; #IO_L13P_T2_MRCC_35 Sch=SYSCLK


##Switches

set_property -dict {PACKAGE_PIN M20 IOSTANDARD LVCMOS33} [get_ports sw0]
#set_property -dict { PACKAGE_PIN M19  IOSTANDARD LVCMOS33 } [get_ports { sw[1] }]; #IO_L7P_T1_AD2P_35 Sch=SW1

##RGB LEDs

#set_property -dict { PACKAGE_PIN L15    IOSTANDARD LVCMOS33 } [get_ports { led4_b }]; #IO_L22N_T3_AD7P_35 Sch=LED4_B
#set_property -dict { PACKAGE_PIN G17    IOSTANDARD LVCMOS33 } [get_ports { led4_g }]; #IO_L16P_T2_35 Sch=LED4_G
#set_property -dict { PACKAGE_PIN N15    IOSTANDARD LVCMOS33 } [get_ports { led4_r }]; #IO_L21P_T3_DQS_AD14P_35 Sch=LED4_R
#set_property -dict { PACKAGE_PIN G14    IOSTANDARD LVCMOS33 } [get_ports { led5_b }]; #IO_0_35 Sch=LED5_B
#set_property -dict { PACKAGE_PIN L14    IOSTANDARD LVCMOS33 } [get_ports { led5_g }]; #IO_L22P_T3_AD7P_35 Sch=LED5_G
#set_property -dict { PACKAGE_PIN M15    IOSTANDARD LVCMOS33 } [get_ports { led5_r }]; #IO_L23N_T3_35 Sch=LED5_R

##LEDs

#set_property -dict { PACKAGE_PIN R14    IOSTANDARD LVCMOS33 } [get_ports { led[0] }]; #IO_L6N_T0_VREF_34 Sch=LED0
#set_property -dict { PACKAGE_PIN P14    IOSTANDARD LVCMOS33 } [get_ports { led[1] }]; #IO_L6P_T0_34 Sch=LED1
#set_property -dict { PACKAGE_PIN N16    IOSTANDARD LVCMOS33 } [get_ports { led[2] }]; #IO_L21N_T3_DQS_AD14N_35 Sch=LED2
#set_property -dict { PACKAGE_PIN M14    IOSTANDARD LVCMOS33 } [get_ports { led[3] }]; #IO_L23P_T3_35 Sch=LED3

##Buttons

#set_property -dict { PACKAGE_PIN D19    IOSTANDARD LVCMOS33 } [get_ports { btn[0] }]; #IO_L4P_T0_35 Sch=BTN0
#set_property -dict { PACKAGE_PIN D20    IOSTANDARD LVCMOS33 } [get_ports { btn[1] }]; #IO_L4N_T0_35 Sch=BTN1
#set_property -dict { PACKAGE_PIN L20    IOSTANDARD LVCMOS33 } [get_ports { btn[2] }]; #IO_L9N_T1_DQS_AD3N_35 Sch=BTN2
#set_property -dict { PACKAGE_PIN L19    IOSTANDARD LVCMOS33 } [get_ports { btn[3] }]; #IO_L9P_T1_DQS_AD3P_35 Sch=BTN3

##Pmod Header JA (PmodA) — Digilent Pmod I2S2, left-channel ADC input
## Top row: MCLK/LRCK/BCLK/SDIN(DAC). Bottom row clocks are wired on-module.
## Pin 10 (JA10) = A/D SDOUT into FPGA.
set_property -dict {PACKAGE_PIN Y18 IOSTANDARD LVCMOS33} [get_ports pmod_i2s_mclk]
set_property -dict {PACKAGE_PIN Y16 IOSTANDARD LVCMOS33} [get_ports pmod_i2s_lrck]
set_property -dict {PACKAGE_PIN U18 IOSTANDARD LVCMOS33} [get_ports pmod_i2s_bclk]
set_property -dict {PACKAGE_PIN W18 IOSTANDARD LVCMOS33} [get_ports pmod_i2s_sdout]
set_property -dict {PACKAGE_PIN W19 IOSTANDARD LVCMOS33} [get_ports pmod_i2s_sdin]

##Pmod Header JA (legacy differential naming — keep commented)

#set_property -dict { PACKAGE_PIN Y18   IOSTANDARD LVCMOS33 } [get_ports { UART1_RX }]; #IO_L17P_T2_34 Sch=JA1_P
#set_property -dict { PACKAGE_PIN Y19   IOSTANDARD LVCMOS33 } [get_ports { UART1_TX }]; #IO_L17N_T2_34 Sch=JA1_N
#set_property -dict { PACKAGE_PIN Y16   IOSTANDARD LVCMOS33 } [get_ports { ja_p[2] }]; #IO_L7P_T1_34 Sch=JA2_P
#set_property -dict { PACKAGE_PIN Y17   IOSTANDARD LVCMOS33 } [get_ports { ja_n[2] }]; #IO_L7N_T1_34 Sch=JA2_N
#set_property -dict { PACKAGE_PIN U18   IOSTANDARD LVCMOS33 } [get_ports { ja_p[3] }]; #IO_L12P_T1_MRCC_34 Sch=JA3_P
#set_property -dict { PACKAGE_PIN U19   IOSTANDARD LVCMOS33 } [get_ports { ja_n[3] }]; #IO_L12N_T1_MRCC_34 Sch=JA3_N
#set_property -dict { PACKAGE_PIN W18   IOSTANDARD LVCMOS33 } [get_ports { ja_p[4] }]; #IO_L22P_T3_34 Sch=JA4_P
#set_property -dict { PACKAGE_PIN W19   IOSTANDARD LVCMOS33 } [get_ports { ja_n[4] }]; #IO_L22N_T3_34 Sch=JA4_N

##Pmod Header JB

set_property -dict {PACKAGE_PIN Y14 IOSTANDARD LVCMOS33} [get_ports UART1_RX]
set_property -dict {PACKAGE_PIN W14 IOSTANDARD LVCMOS33} [get_ports UART1_TX]
#set_property -dict { PACKAGE_PIN T10   IOSTANDARD LVCMOS33 } [get_ports { jb_n[2] }]; #IO_L1N_T0_34 Sch=JB2_N
#set_property -dict { PACKAGE_PIN T11   IOSTANDARD LVCMOS33 } [get_ports { jb_p[2] }]; #IO_L1P_T0_34 Sch=JB2_P
#set_property -dict { PACKAGE_PIN W16   IOSTANDARD LVCMOS33 } [get_ports { jb_n[3] }]; #IO_L18N_T2_34 Sch=JB3_N
#set_property -dict { PACKAGE_PIN V16   IOSTANDARD LVCMOS33 } [get_ports { jb_p[3] }]; #IO_L18P_T2_34 Sch=JB3_P
#set_property -dict { PACKAGE_PIN W13   IOSTANDARD LVCMOS33 } [get_ports { jb_n[4] }]; #IO_L4N_T0_34 Sch=JB4_N
#set_property -dict { PACKAGE_PIN V12   IOSTANDARD LVCMOS33 } [get_ports { jb_p[4] }]; #IO_L4P_T0_34 Sch=JB4_P

##Audio Out

#set_property -dict { PACKAGE_PIN R18   IOSTANDARD LVCMOS33 } [get_ports { aud_pwm }]; #IO_L20N_T3_34 Sch=AUD_PWM
#set_property -dict { PACKAGE_PIN T17   IOSTANDARD LVCMOS33 } [get_ports { aud_sd }]; #IO_L20P_T3_34 Sch=AUD_SD

##Crypto SDA

#set_property -dict { PACKAGE_PIN J15   IOSTANDARD LVCMOS33 } [get_ports { crypto_sda }]; #IO_25_35 Sch=CRYPTO_SDA

##HDMI RX Signals

#set_property -dict { PACKAGE_PIN H17   IOSTANDARD LVCMOS33 } [get_ports { hdmi_rx_cec }]; #IO_L13N_T2_MRCC_35 Sch=HDMI_RX_CEC
set_property -dict {PACKAGE_PIN P19 IOSTANDARD TMDS_33} [get_ports TMDS_clk_n]
set_property -dict {PACKAGE_PIN N18 IOSTANDARD TMDS_33} [get_ports TMDS_clk_p]
# P pin only. A second create_clock on TMDS_clk_n makes Vivado time one
# MMCM as two pixel clocks 1.346 ns apart.
create_clock -period 13.461 -waveform {0.000 6.730} [get_ports TMDS_clk_p]
set_property -dict {PACKAGE_PIN W20 IOSTANDARD TMDS_33} [get_ports {TMDS_data_n[0]}]
set_property -dict {PACKAGE_PIN V20 IOSTANDARD TMDS_33} [get_ports {TMDS_data_p[0]}]
set_property -dict {PACKAGE_PIN U20 IOSTANDARD TMDS_33} [get_ports {TMDS_data_n[1]}]
set_property -dict {PACKAGE_PIN T20 IOSTANDARD TMDS_33} [get_ports {TMDS_data_p[1]}]
set_property -dict {PACKAGE_PIN P20 IOSTANDARD TMDS_33} [get_ports {TMDS_data_n[2]}]
set_property -dict {PACKAGE_PIN N20 IOSTANDARD TMDS_33} [get_ports {TMDS_data_p[2]}]
set_property -dict {PACKAGE_PIN T19 IOSTANDARD LVCMOS33} [get_ports {hdmi_hpd_tri_o[0]}]
set_property -dict {PACKAGE_PIN U14 IOSTANDARD LVCMOS33} [get_ports DDC_scl_io]
set_property -dict {PACKAGE_PIN U15 IOSTANDARD LVCMOS33} [get_ports DDC_sda_io]

##HDMI TX Signals

#set_property -dict { PACKAGE_PIN G15   IOSTANDARD LVCMOS33 } [get_ports { hdmi_tx_cec }]; #IO_L19N_T3_VREF_35 Sch=HDMI_TX_CEC
set_property -dict {PACKAGE_PIN L17 IOSTANDARD TMDS_33} [get_ports TMDS_1_clk_n]
set_property -dict {PACKAGE_PIN L16 IOSTANDARD TMDS_33} [get_ports TMDS_1_clk_p]
set_property -dict {PACKAGE_PIN K18 IOSTANDARD TMDS_33} [get_ports {TMDS_1_data_n[0]}]
set_property -dict {PACKAGE_PIN K17 IOSTANDARD TMDS_33} [get_ports {TMDS_1_data_p[0]}]
set_property -dict {PACKAGE_PIN J19 IOSTANDARD TMDS_33} [get_ports {TMDS_1_data_n[1]}]
set_property -dict {PACKAGE_PIN K19 IOSTANDARD TMDS_33} [get_ports {TMDS_1_data_p[1]}]
set_property -dict {PACKAGE_PIN H18 IOSTANDARD TMDS_33} [get_ports {TMDS_1_data_n[2]}]
set_property -dict {PACKAGE_PIN J18 IOSTANDARD TMDS_33} [get_ports {TMDS_1_data_p[2]}]
#set_property -dict { PACKAGE_PIN R19   IOSTANDARD LVCMOS33 } [get_ports { hdmi_hpd_tri_o[0] }]; #IO_0_34 Sch=HDMI_TX_HPDN
#set_property -dict { PACKAGE_PIN M17   IOSTANDARD LVCMOS33 } [get_ports { hdmi_tx_scl }]; #IO_L8P_T1_AD10P_35 Sch=HDMI_TX_SCL
#set_property -dict { PACKAGE_PIN M18   IOSTANDARD LVCMOS33 } [get_ports { hdmi_tx_sda }]; #IO_L8N_T1_AD10N_35 Sch=HDMI_TX_SDA


##ChipKit Single Ended Analog Inputs
##NOTE: The ck_an_p pins can be used as single ended analog inputs with voltages from 0-3.3V (Chipkit Analog pins A0-A5).
##      These signals should only be connected to the XADC core. When using these pins as digital I/O, use pins CK_A[0-5].

#set_property -dict { PACKAGE_PIN D18   IOSTANDARD LVCMOS33 } [get_ports { ck_an_n[0] }]; #IO_L3N_T0_DQS_AD1N_35 Sch=CK_AN0_N
#set_property -dict { PACKAGE_PIN E17   IOSTANDARD LVCMOS33 } [get_ports { ck_an_p[0] }]; #IO_L3P_T0_DQS_AD1P_35 Sch=CK_AN0_P
#set_property -dict { PACKAGE_PIN E19   IOSTANDARD LVCMOS33 } [get_ports { ck_an_n[1] }]; #IO_L5N_T0_AD9N_35 Sch=CK_AN1_N
#set_property -dict { PACKAGE_PIN E18   IOSTANDARD LVCMOS33 } [get_ports { ck_an_p[1] }]; #IO_L5P_T0_AD9P_35 Sch=CK_AN1_P
#set_property -dict { PACKAGE_PIN J14   IOSTANDARD LVCMOS33 } [get_ports { ck_an_n[2] }]; #IO_L20N_T3_AD6N_35 Sch=CK_AN2_N
#set_property -dict { PACKAGE_PIN K14   IOSTANDARD LVCMOS33 } [get_ports { ck_an_p[2] }]; #IO_L20P_T3_AD6P_35 Sch=CK_AN2_P
#set_property -dict { PACKAGE_PIN J16   IOSTANDARD LVCMOS33 } [get_ports { ck_an_n[3] }]; #IO_L24N_T3_AD15N_35 Sch=CK_AN3_N
#set_property -dict { PACKAGE_PIN K16   IOSTANDARD LVCMOS33 } [get_ports { ck_an_p[3] }]; #IO_L24P_T3_AD15P_35 Sch=CK_AN3_P
#set_property -dict { PACKAGE_PIN H20   IOSTANDARD LVCMOS33 } [get_ports { ck_an_n[4] }]; #IO_L17N_T2_AD5N_35 Sch=CK_AN4_N
#set_property -dict { PACKAGE_PIN J20   IOSTANDARD LVCMOS33 } [get_ports { ck_an_p[4] }]; #IO_L17P_T2_AD5P_35 Sch=CK_AN4_P
#set_property -dict { PACKAGE_PIN G20   IOSTANDARD LVCMOS33 } [get_ports { ck_an_n[5] }]; #IO_L18N_T2_AD13N_35 Sch=CK_AN5_N
#set_property -dict { PACKAGE_PIN G19   IOSTANDARD LVCMOS33 } [get_ports { ck_an_p[5] }]; #IO_L18P_T2_AD13P_35 Sch=CK_AN5_P

##ChipKit Digital I/O On Outer Analog Header
##NOTE: These pins should be used when using the analog header signals A0-A5 as digital I/O (Chipkit digital pins 0-5)

#set_property -dict { PACKAGE_PIN Y11   IOSTANDARD LVCMOS33 } [get_ports { ck_a[0] }]; #IO_L18N_T2_13 Sch=CK_A0
#set_property -dict { PACKAGE_PIN Y12   IOSTANDARD LVCMOS33 } [get_ports { ck_a[1] }]; #IO_L20P_T3_13 Sch=CK_A1
#set_property -dict { PACKAGE_PIN W11   IOSTANDARD LVCMOS33 } [get_ports { ck_a[2] }]; #IO_L18P_T2_13 Sch=CK_A2
#set_property -dict { PACKAGE_PIN V11   IOSTANDARD LVCMOS33 } [get_ports { ck_a[3] }]; #IO_L21P_T3_DQS_13 Sch=CK_A3
#set_property -dict { PACKAGE_PIN T5    IOSTANDARD LVCMOS33 } [get_ports { ck_a[4] }]; #IO_L19P_T3_13 Sch=CK_A4
#set_property -dict { PACKAGE_PIN U10   IOSTANDARD LVCMOS33 } [get_ports { ck_a[5] }]; #IO_L12N_T1_MRCC_13 Sch=CK_A5

##ChipKit Digital I/O On Inner Analog Header
##NOTE: These pins will need to be connected to the XADC core when used as differential analog inputs (Chipkit analog pins A6-A11)

#set_property -dict { PACKAGE_PIN B20   IOSTANDARD LVCMOS33 } [get_ports { ad_n[0] }]; #IO_L1N_T0_AD0N_35 Sch=AD0_N
#set_property -dict { PACKAGE_PIN C20   IOSTANDARD LVCMOS33 } [get_ports { ad_p[0] }]; #IO_L1P_T0_AD0P_35 Sch=AD0_P
#set_property -dict { PACKAGE_PIN F20   IOSTANDARD LVCMOS33 } [get_ports { ad_n[12] }]; #IO_L15N_T2_DQS_AD12N_35 Sch=AD12_N
#set_property -dict { PACKAGE_PIN F19   IOSTANDARD LVCMOS33 } [get_ports { ad_p[12] }]; #IO_L15P_T2_DQS_AD12P_35 Sch=AD12_P
#set_property -dict { PACKAGE_PIN A20   IOSTANDARD LVCMOS33 } [get_ports { ad_n[8] }]; #IO_L2N_T0_AD8N_35 Sch=AD8_N
#set_property -dict { PACKAGE_PIN B19   IOSTANDARD LVCMOS33 } [get_ports { ad_p[8] }]; #IO_L2P_T0_AD8P_35 Sch=AD8_P

##ChipKit Digital I/O Low

#set_property -dict { PACKAGE_PIN T14   IOSTANDARD LVCMOS33 } [get_ports { ck_io[0] }]; #IO_L5P_T0_34 Sch=CK_IO0
#set_property -dict { PACKAGE_PIN U12   IOSTANDARD LVCMOS33 } [get_ports { ck_io[1] }]; #IO_L2N_T0_34 Sch=CK_IO1
#set_property -dict { PACKAGE_PIN U13   IOSTANDARD LVCMOS33 } [get_ports { ck_io[2] }]; #IO_L3P_T0_DQS_PUDC_B_34 Sch=CK_IO2
#set_property -dict { PACKAGE_PIN V13   IOSTANDARD LVCMOS33 } [get_ports { ck_io[3] }]; #IO_L3N_T0_DQS_34 Sch=CK_IO3
#set_property -dict { PACKAGE_PIN V15   IOSTANDARD LVCMOS33 } [get_ports { ck_io[4] }]; #IO_L10P_T1_34 Sch=CK_IO4
#set_property -dict { PACKAGE_PIN T15   IOSTANDARD LVCMOS33 } [get_ports { ck_io[5] }]; #IO_L5N_T0_34 Sch=CK_IO5
#set_property -dict { PACKAGE_PIN R16   IOSTANDARD LVCMOS33 } [get_ports { ck_io[6] }]; #IO_L19P_T3_34 Sch=CK_IO6
#set_property -dict { PACKAGE_PIN U17   IOSTANDARD LVCMOS33 } [get_ports { ck_io[7] }]; #IO_L9N_T1_DQS_34 Sch=CK_IO7
#set_property -dict { PACKAGE_PIN V17   IOSTANDARD LVCMOS33 } [get_ports { ck_io[8] }]; #IO_L21P_T3_DQS_34 Sch=CK_IO8
#set_property -dict { PACKAGE_PIN V18   IOSTANDARD LVCMOS33 } [get_ports { ck_io[9] }]; #IO_L21N_T3_DQS_34 Sch=CK_IO9
#set_property -dict { PACKAGE_PIN T16   IOSTANDARD LVCMOS33 } [get_ports { ck_io[10] }]; #IO_L9P_T1_DQS_34 Sch=CK_IO10
#set_property -dict { PACKAGE_PIN R17   IOSTANDARD LVCMOS33 } [get_ports { ck_io[11] }]; #IO_L19N_T3_VREF_34 Sch=CK_IO11
#set_property -dict { PACKAGE_PIN P18   IOSTANDARD LVCMOS33 } [get_ports { ck_io[12] }]; #IO_L23N_T3_34 Sch=CK_IO12
#set_property -dict { PACKAGE_PIN N17   IOSTANDARD LVCMOS33 } [get_ports { ck_io[13] }]; #IO_L23P_T3_34 Sch=CK_IO13

##ChipKit Digital I/O High

#set_property -dict { PACKAGE_PIN U5    IOSTANDARD LVCMOS33 } [get_ports { ck_io[26] }]; #IO_L19N_T3_VREF_13 Sch=CK_IO26
#set_property -dict { PACKAGE_PIN V5    IOSTANDARD LVCMOS33 } [get_ports { ck_io[27] }]; #IO_L6N_T0_VREF_13 Sch=CK_IO27
#set_property -dict { PACKAGE_PIN V6    IOSTANDARD LVCMOS33 } [get_ports { ck_io[28] }]; #IO_L22P_T3_13 Sch=CK_IO28
#set_property -dict { PACKAGE_PIN U7    IOSTANDARD LVCMOS33 } [get_ports { ck_io[29] }]; #IO_L11P_T1_SRCC_13 Sch=CK_IO29
#set_property -dict { PACKAGE_PIN V7    IOSTANDARD LVCMOS33 } [get_ports { ck_io[30] }]; #IO_L11N_T1_SRCC_13 Sch=CK_IO30
#set_property -dict { PACKAGE_PIN U8    IOSTANDARD LVCMOS33 } [get_ports { ck_io[31] }]; #IO_L17N_T2_13 Sch=CK_IO31
#set_property -dict { PACKAGE_PIN V8    IOSTANDARD LVCMOS33 } [get_ports { ck_io[32] }]; #IO_L15P_T2_DQS_13 Sch=CK_IO32
#set_property -dict { PACKAGE_PIN V10   IOSTANDARD LVCMOS33 } [get_ports { ck_io[33] }]; #IO_L21N_T3_DQS_13 Sch=CK_IO33
#set_property -dict { PACKAGE_PIN W10   IOSTANDARD LVCMOS33 } [get_ports { ck_io[34] }]; #IO_L16P_T2_13 Sch=CK_IO34
#set_property -dict { PACKAGE_PIN W6    IOSTANDARD LVCMOS33 } [get_ports { ck_io[35] }]; #IO_L22N_T3_13 Sch=CK_IO35
#set_property -dict { PACKAGE_PIN Y6    IOSTANDARD LVCMOS33 } [get_ports { ck_io[36] }]; #IO_L13N_T2_MRCC_13 Sch=CK_IO36
#set_property -dict { PACKAGE_PIN Y7    IOSTANDARD LVCMOS33 } [get_ports { ck_io[37] }]; #IO_L13P_T2_MRCC_13 Sch=cCK_IO37
#set_property -dict { PACKAGE_PIN W8    IOSTANDARD LVCMOS33 } [get_ports { ck_io[38] }]; #IO_L15N_T2_DQS_13 Sch=CK_IO38
#set_property -dict { PACKAGE_PIN Y8    IOSTANDARD LVCMOS33 } [get_ports { ck_io[39] }]; #IO_L14N_T2_SRCC_13 Sch=CK_IO39
#set_property -dict { PACKAGE_PIN W9    IOSTANDARD LVCMOS33 } [get_ports { ck_io[40] }]; #IO_L16N_T2_13 Sch=CK_IO40
#set_property -dict { PACKAGE_PIN Y9    IOSTANDARD LVCMOS33 } [get_ports { ck_io[41] }]; #IO_L14P_T2_SRCC_13 Sch=CK_IO41

## ChipKit SPI

#set_property -dict { PACKAGE_PIN W15   IOSTANDARD LVCMOS33 } [get_ports { ck_miso }]; #IO_L10N_T1_34 Sch=CK_MISO
#set_property -dict { PACKAGE_PIN T12   IOSTANDARD LVCMOS33 } [get_ports { ck_mosi }]; #IO_L2P_T0_34 Sch=CK_MISO
#set_property -dict { PACKAGE_PIN H15   IOSTANDARD LVCMOS33 } [get_ports { ck_sck }];  #IO_L19P_T3_35 Sch=CK_SCK
#set_property -dict { PACKAGE_PIN F16   IOSTANDARD LVCMOS33 } [get_ports { ck_ss }];   #IO_L6P_T0_35 Sch=CK_SS

## ChipKit I2C

#set_property -dict { PACKAGE_PIN P16   IOSTANDARD LVCMOS33 } [get_ports { ck_scl }]; #IO_L24N_T3_34 Sch=CK_SCL
#set_property -dict { PACKAGE_PIN P15   IOSTANDARD LVCMOS33 } [get_ports { ck_sda }]; #IO_L24P_T3_34 Sch=CK_SDA

##Misc. ChipKit signals

#set_property -dict { PACKAGE_PIN Y13   IOSTANDARD LVCMOS33 } [get_ports { ck_ioa }]; #IO_L20N_T3_13 Sch=CK_IOA

## Not Connected Pins

#set_property PACKAGE_PIN F17 [get_ports {netic20_f17}]; #IO_L6N_T0_VREF_35
#set_property PACKAGE_PIN G18 [get_ports {netic20_g18}]; #IO_L16N_T2_35
#set_property PACKAGE_PIN T9 [get_ports {netic20_t9}]; #IO_L12P_T1_MRCC_13
#set_property PACKAGE_PIN U9 [get_ports {netic20_u9}]; #IO_L17P_T2_13


set_property MARK_DEBUG true [get_nets {hdmi_in_i/spector_wrapper_zynq_0_video_out[6]}]
set_property MARK_DEBUG true [get_nets {hdmi_in_i/spector_wrapper_zynq_0_video_out[7]}]
set_property MARK_DEBUG true [get_nets {hdmi_in_i/spector_wrapper_zynq_0_video_out[10]}]
set_property MARK_DEBUG true [get_nets {hdmi_in_i/spector_wrapper_zynq_0_video_out[12]}]
set_property MARK_DEBUG true [get_nets {hdmi_in_i/spector_wrapper_zynq_0_video_out[21]}]
set_property MARK_DEBUG true [get_nets {hdmi_in_i/spector_wrapper_zynq_0_video_out[22]}]
set_property MARK_DEBUG true [get_nets {hdmi_in_i/spector_wrapper_zynq_0_video_out[3]}]
set_property MARK_DEBUG true [get_nets {hdmi_in_i/spector_wrapper_zynq_0_video_out[4]}]
set_property MARK_DEBUG true [get_nets {hdmi_in_i/spector_wrapper_zynq_0_video_out[8]}]
set_property MARK_DEBUG true [get_nets {hdmi_in_i/spector_wrapper_zynq_0_video_out[9]}]
set_property MARK_DEBUG true [get_nets {hdmi_in_i/spector_wrapper_zynq_0_video_out[11]}]
set_property MARK_DEBUG true [get_nets {hdmi_in_i/spector_wrapper_zynq_0_video_out[13]}]
set_property MARK_DEBUG true [get_nets {hdmi_in_i/spector_wrapper_zynq_0_video_out[15]}]
set_property MARK_DEBUG true [get_nets {hdmi_in_i/spector_wrapper_zynq_0_video_out[14]}]
set_property MARK_DEBUG true [get_nets {hdmi_in_i/spector_wrapper_zynq_0_video_out[16]}]
set_property MARK_DEBUG true [get_nets {hdmi_in_i/spector_wrapper_zynq_0_video_out[18]}]
set_property MARK_DEBUG true [get_nets {hdmi_in_i/spector_wrapper_zynq_0_video_out[19]}]
set_property MARK_DEBUG true [get_nets {hdmi_in_i/spector_wrapper_zynq_0_video_out[0]}]
set_property MARK_DEBUG true [get_nets {hdmi_in_i/spector_wrapper_zynq_0_video_out[1]}]
set_property MARK_DEBUG true [get_nets {hdmi_in_i/spector_wrapper_zynq_0_video_out[2]}]
set_property MARK_DEBUG true [get_nets {hdmi_in_i/spector_wrapper_zynq_0_video_out[5]}]
set_property MARK_DEBUG true [get_nets {hdmi_in_i/spector_wrapper_zynq_0_video_out[17]}]
set_property MARK_DEBUG true [get_nets {hdmi_in_i/spector_wrapper_zynq_0_video_out[20]}]
set_property MARK_DEBUG true [get_nets {hdmi_in_i/spector_wrapper_zynq_0_video_out[23]}]
set_property MARK_DEBUG true [get_nets {hdmi_in_i/video_bufr_reg_0_vid_pData[4]}]
set_property MARK_DEBUG true [get_nets {hdmi_in_i/video_bufr_reg_0_vid_pData[11]}]
set_property MARK_DEBUG true [get_nets {hdmi_in_i/video_bufr_reg_0_vid_pData[16]}]
set_property MARK_DEBUG true [get_nets {hdmi_in_i/video_bufr_reg_0_vid_pData[20]}]
set_property MARK_DEBUG true [get_nets {hdmi_in_i/video_bufr_reg_0_vid_pData[23]}]
set_property MARK_DEBUG true [get_nets {hdmi_in_i/video_bufr_reg_0_vid_pData[2]}]
set_property MARK_DEBUG true [get_nets {hdmi_in_i/video_bufr_reg_0_vid_pData[3]}]
set_property MARK_DEBUG true [get_nets {hdmi_in_i/video_bufr_reg_0_vid_pData[8]}]
set_property MARK_DEBUG true [get_nets {hdmi_in_i/video_bufr_reg_0_vid_pData[10]}]
set_property MARK_DEBUG true [get_nets {hdmi_in_i/video_bufr_reg_0_vid_pData[17]}]
set_property MARK_DEBUG true [get_nets {hdmi_in_i/video_bufr_reg_0_vid_pData[1]}]
set_property MARK_DEBUG true [get_nets {hdmi_in_i/video_bufr_reg_0_vid_pData[5]}]
set_property MARK_DEBUG true [get_nets {hdmi_in_i/video_bufr_reg_0_vid_pData[6]}]
set_property MARK_DEBUG true [get_nets {hdmi_in_i/video_bufr_reg_0_vid_pData[7]}]
set_property MARK_DEBUG true [get_nets {hdmi_in_i/video_bufr_reg_0_vid_pData[12]}]
set_property MARK_DEBUG true [get_nets {hdmi_in_i/video_bufr_reg_0_vid_pData[13]}]
set_property MARK_DEBUG true [get_nets {hdmi_in_i/video_bufr_reg_0_vid_pData[21]}]
set_property MARK_DEBUG true [get_nets {hdmi_in_i/video_bufr_reg_0_vid_pData[0]}]
set_property MARK_DEBUG true [get_nets {hdmi_in_i/video_bufr_reg_0_vid_pData[9]}]
set_property MARK_DEBUG true [get_nets {hdmi_in_i/video_bufr_reg_0_vid_pData[14]}]
set_property MARK_DEBUG true [get_nets {hdmi_in_i/video_bufr_reg_0_vid_pData[15]}]
set_property MARK_DEBUG true [get_nets {hdmi_in_i/video_bufr_reg_0_vid_pData[18]}]
set_property MARK_DEBUG true [get_nets {hdmi_in_i/video_bufr_reg_0_vid_pData[19]}]
set_property MARK_DEBUG true [get_nets {hdmi_in_i/video_bufr_reg_0_vid_pData[22]}]
set_property MARK_DEBUG true [get_nets hdmi_in_i/spector_wrapper_zynq_0_v_sync_o]
set_property MARK_DEBUG true [get_nets hdmi_in_i/spector_wrapper_zynq_0_start_of_frame_o]
set_property MARK_DEBUG true [get_nets hdmi_in_i/spector_wrapper_zynq_0_h_sync_o]
set_property MARK_DEBUG true [get_nets hdmi_in_i/sw0]
set_property MARK_DEBUG true [get_nets hdmi_in_i/v_axi4s_vid_out_0_vid_vsync]
set_property MARK_DEBUG true [get_nets hdmi_in_i/v_axi4s_vid_out_0_vid_active_video]
set_property MARK_DEBUG true [get_nets hdmi_in_i/v_axi4s_vid_out_0_vid_hsync]
set_property MARK_DEBUG true [get_nets {hdmi_in_i/v_axi4s_vid_out_0_vid_data[1]}]
set_property MARK_DEBUG true [get_nets {hdmi_in_i/v_axi4s_vid_out_0_vid_data[5]}]
set_property MARK_DEBUG true [get_nets {hdmi_in_i/v_axi4s_vid_out_0_vid_data[11]}]
set_property MARK_DEBUG true [get_nets {hdmi_in_i/v_axi4s_vid_out_0_vid_data[13]}]
set_property MARK_DEBUG true [get_nets {hdmi_in_i/v_axi4s_vid_out_0_vid_data[18]}]
set_property MARK_DEBUG true [get_nets {hdmi_in_i/v_axi4s_vid_out_0_vid_data[20]}]
set_property MARK_DEBUG true [get_nets {hdmi_in_i/v_axi4s_vid_out_0_vid_data[21]}]
set_property MARK_DEBUG true [get_nets {hdmi_in_i/v_axi4s_vid_out_0_vid_data[4]}]
set_property MARK_DEBUG true [get_nets {hdmi_in_i/v_axi4s_vid_out_0_vid_data[6]}]
set_property MARK_DEBUG true [get_nets {hdmi_in_i/v_axi4s_vid_out_0_vid_data[8]}]
set_property MARK_DEBUG true [get_nets {hdmi_in_i/v_axi4s_vid_out_0_vid_data[16]}]
set_property MARK_DEBUG true [get_nets {hdmi_in_i/v_axi4s_vid_out_0_vid_data[0]}]
set_property MARK_DEBUG true [get_nets {hdmi_in_i/v_axi4s_vid_out_0_vid_data[3]}]
set_property MARK_DEBUG true [get_nets {hdmi_in_i/v_axi4s_vid_out_0_vid_data[7]}]
set_property MARK_DEBUG true [get_nets {hdmi_in_i/v_axi4s_vid_out_0_vid_data[9]}]
set_property MARK_DEBUG true [get_nets {hdmi_in_i/v_axi4s_vid_out_0_vid_data[10]}]
set_property MARK_DEBUG true [get_nets {hdmi_in_i/v_axi4s_vid_out_0_vid_data[12]}]
set_property MARK_DEBUG true [get_nets {hdmi_in_i/v_axi4s_vid_out_0_vid_data[14]}]
set_property MARK_DEBUG true [get_nets {hdmi_in_i/v_axi4s_vid_out_0_vid_data[2]}]
set_property MARK_DEBUG true [get_nets {hdmi_in_i/v_axi4s_vid_out_0_vid_data[15]}]
set_property MARK_DEBUG true [get_nets {hdmi_in_i/v_axi4s_vid_out_0_vid_data[17]}]
set_property MARK_DEBUG true [get_nets {hdmi_in_i/v_axi4s_vid_out_0_vid_data[19]}]
set_property MARK_DEBUG true [get_nets {hdmi_in_i/v_axi4s_vid_out_0_vid_data[22]}]
set_property MARK_DEBUG true [get_nets {hdmi_in_i/v_axi4s_vid_out_0_vid_data[23]}]
set_property MARK_DEBUG true [get_nets {hdmi_in_i/spector_wrapper_zynq_0/U0/digital_side_inst/matrix_in_inv[7]}]
set_property MARK_DEBUG true [get_nets {hdmi_in_i/spector_wrapper_zynq_0/U0/digital_side_inst/matrix_in_inv[5]}]
set_property MARK_DEBUG true [get_nets {hdmi_in_i/spector_wrapper_zynq_0/U0/digital_side_inst/matrix_in_inv[4]}]
set_property MARK_DEBUG true [get_nets {hdmi_in_i/spector_wrapper_zynq_0/U0/digital_side_inst/matrix_in_inv[2]}]
set_property MARK_DEBUG true [get_nets {hdmi_in_i/spector_wrapper_zynq_0/U0/digital_side_inst/matrix_in_inv[1]}]
set_property MARK_DEBUG true [get_nets {hdmi_in_i/spector_wrapper_zynq_0/U0/digital_side_inst/matrix_in_inv[8]}]
set_property MARK_DEBUG true [get_nets {hdmi_in_i/spector_wrapper_zynq_0/U0/digital_side_inst/matrix_in_inv[6]}]
set_property MARK_DEBUG true [get_nets {hdmi_in_i/spector_wrapper_zynq_0/U0/digital_side_inst/matrix_in_inv[3]}]
set_property MARK_DEBUG true [get_nets {hdmi_in_i/spector_wrapper_zynq_0/U0/digital_side_inst/matrix_in_inv[0]}]
set_property MARK_DEBUG true [get_nets {hdmi_in_i/spector_wrapper_zynq_0/U0/YUV_in[6]}]
set_property MARK_DEBUG true [get_nets {hdmi_in_i/spector_wrapper_zynq_0/U0/YUV_in[9]}]
set_property MARK_DEBUG true [get_nets {hdmi_in_i/spector_wrapper_zynq_0/U0/YUV_in[14]}]
set_property MARK_DEBUG true [get_nets {hdmi_in_i/spector_wrapper_zynq_0/U0/YUV_in[19]}]
set_property MARK_DEBUG true [get_nets {hdmi_in_i/spector_wrapper_zynq_0/U0/YUV_in[5]}]
set_property MARK_DEBUG true [get_nets {hdmi_in_i/spector_wrapper_zynq_0/U0/YUV_in[11]}]
set_property MARK_DEBUG true [get_nets {hdmi_in_i/spector_wrapper_zynq_0/U0/YUV_in[13]}]
set_property MARK_DEBUG true [get_nets {hdmi_in_i/spector_wrapper_zynq_0/U0/YUV_in[15]}]
set_property MARK_DEBUG true [get_nets {hdmi_in_i/spector_wrapper_zynq_0/U0/YUV_in[17]}]
set_property MARK_DEBUG true [get_nets {hdmi_in_i/spector_wrapper_zynq_0/U0/YUV_in[18]}]
set_property MARK_DEBUG true [get_nets {hdmi_in_i/spector_wrapper_zynq_0/U0/YUV_in[2]}]
set_property MARK_DEBUG true [get_nets {hdmi_in_i/spector_wrapper_zynq_0/U0/YUV_in[0]}]
set_property MARK_DEBUG true [get_nets {hdmi_in_i/spector_wrapper_zynq_0/U0/YUV_in[3]}]
set_property MARK_DEBUG true [get_nets {hdmi_in_i/spector_wrapper_zynq_0/U0/YUV_in[4]}]
set_property MARK_DEBUG true [get_nets {hdmi_in_i/spector_wrapper_zynq_0/U0/YUV_in[10]}]
set_property MARK_DEBUG true [get_nets {hdmi_in_i/spector_wrapper_zynq_0/U0/YUV_in[12]}]
set_property MARK_DEBUG true [get_nets {hdmi_in_i/spector_wrapper_zynq_0/U0/YUV_in[23]}]
set_property MARK_DEBUG true [get_nets {hdmi_in_i/spector_wrapper_zynq_0/U0/YUV_in[16]}]
set_property MARK_DEBUG true [get_nets {hdmi_in_i/spector_wrapper_zynq_0/U0/YUV_in[21]}]
set_property MARK_DEBUG true [get_nets {hdmi_in_i/spector_wrapper_zynq_0/U0/YUV_in[22]}]
set_property MARK_DEBUG true [get_nets {hdmi_in_i/spector_wrapper_zynq_0/U0/YUV_in[1]}]
set_property MARK_DEBUG true [get_nets {hdmi_in_i/spector_wrapper_zynq_0/U0/YUV_in[7]}]
set_property MARK_DEBUG true [get_nets {hdmi_in_i/spector_wrapper_zynq_0/U0/YUV_in[8]}]
set_property MARK_DEBUG true [get_nets {hdmi_in_i/spector_wrapper_zynq_0/U0/YUV_in[20]}]
set_property MARK_DEBUG true [get_nets {hdmi_in_i/spector_wrapper_zynq_0/U0/y_analog[0]}]
set_property MARK_DEBUG true [get_nets {hdmi_in_i/spector_wrapper_zynq_0/U0/y_analog[3]}]
set_property MARK_DEBUG true [get_nets {hdmi_in_i/spector_wrapper_zynq_0/U0/y_analog[5]}]
set_property MARK_DEBUG true [get_nets {hdmi_in_i/spector_wrapper_zynq_0/U0/v_analog[0]}]
set_property MARK_DEBUG true [get_nets {hdmi_in_i/spector_wrapper_zynq_0/U0/v_analog[2]}]
set_property MARK_DEBUG true [get_nets {hdmi_in_i/spector_wrapper_zynq_0/U0/v_analog[5]}]
set_property MARK_DEBUG true [get_nets {hdmi_in_i/spector_wrapper_zynq_0/U0/u_analog[1]}]
set_property MARK_DEBUG true [get_nets {hdmi_in_i/spector_wrapper_zynq_0/U0/y_analog[2]}]
set_property MARK_DEBUG true [get_nets {hdmi_in_i/spector_wrapper_zynq_0/U0/v_analog[7]}]
set_property MARK_DEBUG true [get_nets {hdmi_in_i/spector_wrapper_zynq_0/U0/u_analog[6]}]
set_property MARK_DEBUG true [get_nets {hdmi_in_i/spector_wrapper_zynq_0/U0/v_analog[3]}]
set_property MARK_DEBUG true [get_nets {hdmi_in_i/spector_wrapper_zynq_0/U0/v_analog[6]}]
set_property MARK_DEBUG true [get_nets {hdmi_in_i/spector_wrapper_zynq_0/U0/u_analog[0]}]
set_property MARK_DEBUG true [get_nets {hdmi_in_i/spector_wrapper_zynq_0/U0/u_analog[3]}]
set_property MARK_DEBUG true [get_nets {hdmi_in_i/spector_wrapper_zynq_0/U0/u_analog[5]}]
set_property MARK_DEBUG true [get_nets {hdmi_in_i/spector_wrapper_zynq_0/U0/u_analog[7]}]
set_property MARK_DEBUG true [get_nets {hdmi_in_i/spector_wrapper_zynq_0/U0/y_analog[1]}]
set_property MARK_DEBUG true [get_nets {hdmi_in_i/spector_wrapper_zynq_0/U0/y_analog[4]}]
set_property MARK_DEBUG true [get_nets {hdmi_in_i/spector_wrapper_zynq_0/U0/y_analog[6]}]
set_property MARK_DEBUG true [get_nets {hdmi_in_i/spector_wrapper_zynq_0/U0/y_analog[7]}]
set_property MARK_DEBUG true [get_nets {hdmi_in_i/spector_wrapper_zynq_0/U0/v_analog[1]}]
set_property MARK_DEBUG true [get_nets {hdmi_in_i/spector_wrapper_zynq_0/U0/v_analog[4]}]
set_property MARK_DEBUG true [get_nets {hdmi_in_i/spector_wrapper_zynq_0/U0/u_analog[2]}]
set_property MARK_DEBUG true [get_nets {hdmi_in_i/spector_wrapper_zynq_0/U0/u_analog[4]}]
create_debug_core u_ila_0 ila
set_property ALL_PROBE_SAME_MU true [get_debug_cores u_ila_0]
set_property ALL_PROBE_SAME_MU_CNT 2 [get_debug_cores u_ila_0]
set_property C_ADV_TRIGGER false [get_debug_cores u_ila_0]
set_property C_DATA_DEPTH 1024 [get_debug_cores u_ila_0]
set_property C_EN_STRG_QUAL true [get_debug_cores u_ila_0]
set_property C_INPUT_PIPE_STAGES 0 [get_debug_cores u_ila_0]
set_property C_TRIGIN_EN false [get_debug_cores u_ila_0]
set_property C_TRIGOUT_EN false [get_debug_cores u_ila_0]
set_property port_width 1 [get_debug_ports u_ila_0/clk]
connect_debug_port u_ila_0/clk [get_nets [list hdmi_in_i/axi_dynclk_0/U0/PXL_CLK_G_O]]
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe0]
set_property port_width 24 [get_debug_ports u_ila_0/probe0]
connect_debug_port u_ila_0/probe0 [get_nets [list {hdmi_in_i/spector_wrapper_zynq_0_video_out[0]} {hdmi_in_i/spector_wrapper_zynq_0_video_out[1]} {hdmi_in_i/spector_wrapper_zynq_0_video_out[2]} {hdmi_in_i/spector_wrapper_zynq_0_video_out[3]} {hdmi_in_i/spector_wrapper_zynq_0_video_out[4]} {hdmi_in_i/spector_wrapper_zynq_0_video_out[5]} {hdmi_in_i/spector_wrapper_zynq_0_video_out[6]} {hdmi_in_i/spector_wrapper_zynq_0_video_out[7]} {hdmi_in_i/spector_wrapper_zynq_0_video_out[8]} {hdmi_in_i/spector_wrapper_zynq_0_video_out[9]} {hdmi_in_i/spector_wrapper_zynq_0_video_out[10]} {hdmi_in_i/spector_wrapper_zynq_0_video_out[11]} {hdmi_in_i/spector_wrapper_zynq_0_video_out[12]} {hdmi_in_i/spector_wrapper_zynq_0_video_out[13]} {hdmi_in_i/spector_wrapper_zynq_0_video_out[14]} {hdmi_in_i/spector_wrapper_zynq_0_video_out[15]} {hdmi_in_i/spector_wrapper_zynq_0_video_out[16]} {hdmi_in_i/spector_wrapper_zynq_0_video_out[17]} {hdmi_in_i/spector_wrapper_zynq_0_video_out[18]} {hdmi_in_i/spector_wrapper_zynq_0_video_out[19]} {hdmi_in_i/spector_wrapper_zynq_0_video_out[20]} {hdmi_in_i/spector_wrapper_zynq_0_video_out[21]} {hdmi_in_i/spector_wrapper_zynq_0_video_out[22]} {hdmi_in_i/spector_wrapper_zynq_0_video_out[23]}]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe1]
set_property port_width 12 [get_debug_ports u_ila_0/probe1]
connect_debug_port u_ila_0/probe1 [get_nets [list {hdmi_in_i/spector_wrapper_zynq_0/U0/analog_side_inst/y_signal1[0]} {hdmi_in_i/spector_wrapper_zynq_0/U0/analog_side_inst/y_signal1[1]} {hdmi_in_i/spector_wrapper_zynq_0/U0/analog_side_inst/y_signal1[2]} {hdmi_in_i/spector_wrapper_zynq_0/U0/analog_side_inst/y_signal1[3]} {hdmi_in_i/spector_wrapper_zynq_0/U0/analog_side_inst/y_signal1[4]} {hdmi_in_i/spector_wrapper_zynq_0/U0/analog_side_inst/y_signal1[5]} {hdmi_in_i/spector_wrapper_zynq_0/U0/analog_side_inst/y_signal1[6]} {hdmi_in_i/spector_wrapper_zynq_0/U0/analog_side_inst/y_signal1[7]} {hdmi_in_i/spector_wrapper_zynq_0/U0/analog_side_inst/y_signal1[8]} {hdmi_in_i/spector_wrapper_zynq_0/U0/analog_side_inst/y_signal1[9]} {hdmi_in_i/spector_wrapper_zynq_0/U0/analog_side_inst/y_signal1[10]} {hdmi_in_i/spector_wrapper_zynq_0/U0/analog_side_inst/y_signal1[11]}]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe2]
set_property port_width 12 [get_debug_ports u_ila_0/probe2]
connect_debug_port u_ila_0/probe2 [get_nets [list {hdmi_in_i/spector_wrapper_zynq_0/U0/analog_side_inst/y_digital[0]} {hdmi_in_i/spector_wrapper_zynq_0/U0/analog_side_inst/y_digital[1]} {hdmi_in_i/spector_wrapper_zynq_0/U0/analog_side_inst/y_digital[2]} {hdmi_in_i/spector_wrapper_zynq_0/U0/analog_side_inst/y_digital[3]} {hdmi_in_i/spector_wrapper_zynq_0/U0/analog_side_inst/y_digital[4]} {hdmi_in_i/spector_wrapper_zynq_0/U0/analog_side_inst/y_digital[5]} {hdmi_in_i/spector_wrapper_zynq_0/U0/analog_side_inst/y_digital[6]} {hdmi_in_i/spector_wrapper_zynq_0/U0/analog_side_inst/y_digital[7]} {hdmi_in_i/spector_wrapper_zynq_0/U0/analog_side_inst/y_digital[8]} {hdmi_in_i/spector_wrapper_zynq_0/U0/analog_side_inst/y_digital[9]} {hdmi_in_i/spector_wrapper_zynq_0/U0/analog_side_inst/y_digital[10]} {hdmi_in_i/spector_wrapper_zynq_0/U0/analog_side_inst/y_digital[11]}]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe3]
set_property port_width 12 [get_debug_ports u_ila_0/probe3]
connect_debug_port u_ila_0/probe3 [get_nets [list {hdmi_in_i/spector_wrapper_zynq_0/U0/analog_side_inst/y_anna[0]} {hdmi_in_i/spector_wrapper_zynq_0/U0/analog_side_inst/y_anna[1]} {hdmi_in_i/spector_wrapper_zynq_0/U0/analog_side_inst/y_anna[2]} {hdmi_in_i/spector_wrapper_zynq_0/U0/analog_side_inst/y_anna[3]} {hdmi_in_i/spector_wrapper_zynq_0/U0/analog_side_inst/y_anna[4]} {hdmi_in_i/spector_wrapper_zynq_0/U0/analog_side_inst/y_anna[5]} {hdmi_in_i/spector_wrapper_zynq_0/U0/analog_side_inst/y_anna[6]} {hdmi_in_i/spector_wrapper_zynq_0/U0/analog_side_inst/y_anna[7]} {hdmi_in_i/spector_wrapper_zynq_0/U0/analog_side_inst/y_anna[8]} {hdmi_in_i/spector_wrapper_zynq_0/U0/analog_side_inst/y_anna[9]} {hdmi_in_i/spector_wrapper_zynq_0/U0/analog_side_inst/y_anna[10]} {hdmi_in_i/spector_wrapper_zynq_0/U0/analog_side_inst/y_anna[11]}]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe4]
set_property port_width 8 [get_debug_ports u_ila_0/probe4]
connect_debug_port u_ila_0/probe4 [get_nets [list {hdmi_in_i/spector_wrapper_zynq_0/U0/y_analog[0]} {hdmi_in_i/spector_wrapper_zynq_0/U0/y_analog[1]} {hdmi_in_i/spector_wrapper_zynq_0/U0/y_analog[2]} {hdmi_in_i/spector_wrapper_zynq_0/U0/y_analog[3]} {hdmi_in_i/spector_wrapper_zynq_0/U0/y_analog[4]} {hdmi_in_i/spector_wrapper_zynq_0/U0/y_analog[5]} {hdmi_in_i/spector_wrapper_zynq_0/U0/y_analog[6]} {hdmi_in_i/spector_wrapper_zynq_0/U0/y_analog[7]}]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe5]
set_property port_width 9 [get_debug_ports u_ila_0/probe5]
connect_debug_port u_ila_0/probe5 [get_nets [list {hdmi_in_i/spector_wrapper_zynq_0/U0/digital_side_inst/matrix_in_inv[0]} {hdmi_in_i/spector_wrapper_zynq_0/U0/digital_side_inst/matrix_in_inv[1]} {hdmi_in_i/spector_wrapper_zynq_0/U0/digital_side_inst/matrix_in_inv[2]} {hdmi_in_i/spector_wrapper_zynq_0/U0/digital_side_inst/matrix_in_inv[3]} {hdmi_in_i/spector_wrapper_zynq_0/U0/digital_side_inst/matrix_in_inv[4]} {hdmi_in_i/spector_wrapper_zynq_0/U0/digital_side_inst/matrix_in_inv[5]} {hdmi_in_i/spector_wrapper_zynq_0/U0/digital_side_inst/matrix_in_inv[6]} {hdmi_in_i/spector_wrapper_zynq_0/U0/digital_side_inst/matrix_in_inv[7]} {hdmi_in_i/spector_wrapper_zynq_0/U0/digital_side_inst/matrix_in_inv[8]}]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe6]
set_property port_width 24 [get_debug_ports u_ila_0/probe6]
connect_debug_port u_ila_0/probe6 [get_nets [list {hdmi_in_i/spector_wrapper_zynq_0/U0/YUV_in[0]} {hdmi_in_i/spector_wrapper_zynq_0/U0/YUV_in[1]} {hdmi_in_i/spector_wrapper_zynq_0/U0/YUV_in[2]} {hdmi_in_i/spector_wrapper_zynq_0/U0/YUV_in[3]} {hdmi_in_i/spector_wrapper_zynq_0/U0/YUV_in[4]} {hdmi_in_i/spector_wrapper_zynq_0/U0/YUV_in[5]} {hdmi_in_i/spector_wrapper_zynq_0/U0/YUV_in[6]} {hdmi_in_i/spector_wrapper_zynq_0/U0/YUV_in[7]} {hdmi_in_i/spector_wrapper_zynq_0/U0/YUV_in[8]} {hdmi_in_i/spector_wrapper_zynq_0/U0/YUV_in[9]} {hdmi_in_i/spector_wrapper_zynq_0/U0/YUV_in[10]} {hdmi_in_i/spector_wrapper_zynq_0/U0/YUV_in[11]} {hdmi_in_i/spector_wrapper_zynq_0/U0/YUV_in[12]} {hdmi_in_i/spector_wrapper_zynq_0/U0/YUV_in[13]} {hdmi_in_i/spector_wrapper_zynq_0/U0/YUV_in[14]} {hdmi_in_i/spector_wrapper_zynq_0/U0/YUV_in[15]} {hdmi_in_i/spector_wrapper_zynq_0/U0/YUV_in[16]} {hdmi_in_i/spector_wrapper_zynq_0/U0/YUV_in[17]} {hdmi_in_i/spector_wrapper_zynq_0/U0/YUV_in[18]} {hdmi_in_i/spector_wrapper_zynq_0/U0/YUV_in[19]} {hdmi_in_i/spector_wrapper_zynq_0/U0/YUV_in[20]} {hdmi_in_i/spector_wrapper_zynq_0/U0/YUV_in[21]} {hdmi_in_i/spector_wrapper_zynq_0/U0/YUV_in[22]} {hdmi_in_i/spector_wrapper_zynq_0/U0/YUV_in[23]}]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe7]
set_property port_width 8 [get_debug_ports u_ila_0/probe7]
connect_debug_port u_ila_0/probe7 [get_nets [list {hdmi_in_i/spector_wrapper_zynq_0/U0/u_analog[0]} {hdmi_in_i/spector_wrapper_zynq_0/U0/u_analog[1]} {hdmi_in_i/spector_wrapper_zynq_0/U0/u_analog[2]} {hdmi_in_i/spector_wrapper_zynq_0/U0/u_analog[3]} {hdmi_in_i/spector_wrapper_zynq_0/U0/u_analog[4]} {hdmi_in_i/spector_wrapper_zynq_0/U0/u_analog[5]} {hdmi_in_i/spector_wrapper_zynq_0/U0/u_analog[6]} {hdmi_in_i/spector_wrapper_zynq_0/U0/u_analog[7]}]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe8]
set_property port_width 8 [get_debug_ports u_ila_0/probe8]
connect_debug_port u_ila_0/probe8 [get_nets [list {hdmi_in_i/spector_wrapper_zynq_0/U0/v_analog[0]} {hdmi_in_i/spector_wrapper_zynq_0/U0/v_analog[1]} {hdmi_in_i/spector_wrapper_zynq_0/U0/v_analog[2]} {hdmi_in_i/spector_wrapper_zynq_0/U0/v_analog[3]} {hdmi_in_i/spector_wrapper_zynq_0/U0/v_analog[4]} {hdmi_in_i/spector_wrapper_zynq_0/U0/v_analog[5]} {hdmi_in_i/spector_wrapper_zynq_0/U0/v_analog[6]} {hdmi_in_i/spector_wrapper_zynq_0/U0/v_analog[7]}]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe9]
set_property port_width 1 [get_debug_ports u_ila_0/probe9]
connect_debug_port u_ila_0/probe9 [get_nets [list hdmi_in_i/spector_wrapper_zynq_0_h_sync_o]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe10]
set_property port_width 1 [get_debug_ports u_ila_0/probe10]
connect_debug_port u_ila_0/probe10 [get_nets [list hdmi_in_i/spector_wrapper_zynq_0_start_of_frame_o]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe11]
set_property port_width 1 [get_debug_ports u_ila_0/probe11]
connect_debug_port u_ila_0/probe11 [get_nets [list hdmi_in_i/spector_wrapper_zynq_0_v_sync_o]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe12]
set_property port_width 1 [get_debug_ports u_ila_0/probe12]
connect_debug_port u_ila_0/probe12 [get_nets [list hdmi_in_i/v_axi4s_vid_out_0_vid_active_video]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe13]
set_property port_width 1 [get_debug_ports u_ila_0/probe13]
connect_debug_port u_ila_0/probe13 [get_nets [list hdmi_in_i/v_axi4s_vid_out_0_vid_hsync]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe14]
set_property port_width 1 [get_debug_ports u_ila_0/probe14]
connect_debug_port u_ila_0/probe14 [get_nets [list hdmi_in_i/v_axi4s_vid_out_0_vid_vsync]]
create_debug_core u_ila_1 ila
set_property ALL_PROBE_SAME_MU true [get_debug_cores u_ila_1]
set_property ALL_PROBE_SAME_MU_CNT 2 [get_debug_cores u_ila_1]
set_property C_ADV_TRIGGER false [get_debug_cores u_ila_1]
set_property C_DATA_DEPTH 1024 [get_debug_cores u_ila_1]
set_property C_EN_STRG_QUAL true [get_debug_cores u_ila_1]
set_property C_INPUT_PIPE_STAGES 0 [get_debug_cores u_ila_1]
set_property C_TRIGIN_EN false [get_debug_cores u_ila_1]
set_property C_TRIGOUT_EN false [get_debug_cores u_ila_1]
set_property port_width 1 [get_debug_ports u_ila_1/clk]
connect_debug_port u_ila_1/clk [get_nets [list hdmi_in_i/axi_dynclk_0/U0/PXL_CLK_O]]
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_1/probe0]
set_property port_width 24 [get_debug_ports u_ila_1/probe0]
connect_debug_port u_ila_1/probe0 [get_nets [list {hdmi_in_i/video_bufr_reg_0_vid_pData[0]} {hdmi_in_i/video_bufr_reg_0_vid_pData[1]} {hdmi_in_i/video_bufr_reg_0_vid_pData[2]} {hdmi_in_i/video_bufr_reg_0_vid_pData[3]} {hdmi_in_i/video_bufr_reg_0_vid_pData[4]} {hdmi_in_i/video_bufr_reg_0_vid_pData[5]} {hdmi_in_i/video_bufr_reg_0_vid_pData[6]} {hdmi_in_i/video_bufr_reg_0_vid_pData[7]} {hdmi_in_i/video_bufr_reg_0_vid_pData[8]} {hdmi_in_i/video_bufr_reg_0_vid_pData[9]} {hdmi_in_i/video_bufr_reg_0_vid_pData[10]} {hdmi_in_i/video_bufr_reg_0_vid_pData[11]} {hdmi_in_i/video_bufr_reg_0_vid_pData[12]} {hdmi_in_i/video_bufr_reg_0_vid_pData[13]} {hdmi_in_i/video_bufr_reg_0_vid_pData[14]} {hdmi_in_i/video_bufr_reg_0_vid_pData[15]} {hdmi_in_i/video_bufr_reg_0_vid_pData[16]} {hdmi_in_i/video_bufr_reg_0_vid_pData[17]} {hdmi_in_i/video_bufr_reg_0_vid_pData[18]} {hdmi_in_i/video_bufr_reg_0_vid_pData[19]} {hdmi_in_i/video_bufr_reg_0_vid_pData[20]} {hdmi_in_i/video_bufr_reg_0_vid_pData[21]} {hdmi_in_i/video_bufr_reg_0_vid_pData[22]} {hdmi_in_i/video_bufr_reg_0_vid_pData[23]}]]
set_property C_CLK_INPUT_FREQ_HZ 300000000 [get_debug_cores dbg_hub]
set_property C_ENABLE_CLK_DIVIDER false [get_debug_cores dbg_hub]
set_property C_USER_SCAN_CHAIN 1 [get_debug_cores dbg_hub]
connect_debug_port dbg_hub/clk [get_nets u_ila_1_PXL_CLK_O]
