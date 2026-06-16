-- BASED ON....
-------------------------------------------------------------------------------
--  Copyright (c) 2018-2021 Eclektek LLC. All rights reserved.
--
--
--  Developed by: William Carter
--
--  Permission is hereby granted, free of charge, to any person obtaining a copy of this software and
--  associated documentation files (the "Software"), to deal with the Software without restriction,
--  including without limitation the rights to use, copy, modify, merge, publish, sublicense and/or
--  distribute copies of the Software, and to permit persons to whom the Software is furnished to do so,
--  subject to the following conditions:
--
--      Redistributions of source code must retain the above copyright notice, this list of conditions
--      and the following disclaimers.
--      Redistributions in binary form must reproduce the above copyright notice, this list of conditions
--      and the following disclaimers in the documentation and/or other materials provided with the distribution.
--      Neither the names of William Carter, Eclektek LLC, nor the names of its
--      contributors may be used to endorse or promote products derived from this Software without
--      specific prior written permission from Eclektek LLC.
--      This Software is provided free of charge and Eclektek LLC reserves the right to sell copies of the
--      Software in it original form. Anyone sub-licensing this Software will provide it free of charge.
--
--  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT
--  LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.
--  IN NO EVENT SHALL THE CONTRIBUTORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY,
--  WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE
--  SOFTWARE OR THE USE OR OTHER DEALINGS WITH THE SOFTWARE.
-------------------------------------------------------------------------------
--  History :
--
--  Date      By    Comments
--  --------  ----  ------------------------------------------------------------
--  10/09/21  W.C.  Created
--
-------------------------------------------------------------------------------
--  Project       : Xilinx DDR Demo
--  PCB           : Nexys Video
--  Device        : XC7A200T-1SBG484C
--  Toolchain     : Vivado 2019.1
--  Entity Name   : NexysVideoDdrDemo
--  File Name     : NexysVideoDdrDemo.vhd
--  Design Parent : none
--

Library ieee;
  use ieee.std_logic_1164.all;
  use ieee.std_logic_arith.all;
  use ieee.std_logic_unsigned.all;

library UNISIM;
  use UNISIM.vcomponents.all;

entity ems_ddr_test is
  port(
  -- GLOBAL SIGNALS
  sysclk         : in     std_logic; -- global external 100 MHz clock
  cpu_resetn     : in     std_logic; -- normally '1', '0' when Reset button pressed

  -- General I/O resources
  btnc           : in     std_logic; -- Vadj HR Bank 16 normally '0', '1' when pressed
  btnd           : in     std_logic; -- Vadj HR Bank 16 normally '0', '1' when pressed
  btnl           : in     std_logic; -- Vadj HR Bank 16 normally '0', '1' when pressed
  btnr           : in     std_logic; -- Vadj HR Bank 16 normally '0', '1' when pressed
  btnu           : in     std_logic; -- Vadj HR Bank 16 normally '0', '1' when pressed
  sw             : in     std_logic_vector(7 downto 0); -- Vadj HR Bank 15 or 16
  led            : out    std_logic_vector(7 downto 0); -- VCC2V5 HR bank 13

  JA             : inout  std_logic_vector(7 downto 0);

  -- UART
  uart_rx_out    : out   std_logic;
  uart_tx_in     : in    std_logic;

  -- DDR3 PHY interface
  ddr3_dq        : inout  std_logic_vector(15 downto 0);
--  ddr3_addr      : out    std_logic_vector(14 downto 0);
  ddr3_addr      : out    std_logic_vector(13 downto 0);

  ddr3_ba        : out    std_logic_vector(2 downto 0);
  ddr3_ck_p      : out    std_logic_vector(0 downto 0);
  ddr3_ck_n      : out    std_logic_vector(0 downto 0);
  ddr3_cke       : out    std_logic_vector(0 downto 0);
  ddr3_cas_n     : out    std_logic;
  ddr3_ras_n     : out    std_logic;
  ddr3_we_n      : out    std_logic;
  ddr3_odt       : out    std_logic_vector(0 downto 0);
  ddr3_dm        : out    std_logic_vector(1 downto 0);
  ddr3_dqs_p     : inout  std_logic_vector(1 downto 0);
  ddr3_dqs_n     : inout  std_logic_vector(1 downto 0);
  ddr3_reset_n   : out    std_logic
  );
end entity;

architecture rtl of ems_ddr_test is

-------------------------------------------------------------------------------
--  Component Declarations
-------------------------------------------------------------------------------

component mig_7series_0
  Port (
    ddr3_dq             : inout STD_LOGIC_VECTOR ( 15 downto 0 );
    ddr3_dqs_n          : inout STD_LOGIC_VECTOR ( 1 downto 0 );
    ddr3_dqs_p          : inout STD_LOGIC_VECTOR ( 1 downto 0 );
--    ddr3_addr           : out STD_LOGIC_VECTOR ( 14 downto 0 );
    ddr3_addr           : out STD_LOGIC_VECTOR ( 13 downto 0 );

    ddr3_ba             : out STD_LOGIC_VECTOR ( 2 downto 0 );
    ddr3_ras_n          : out STD_LOGIC;
    ddr3_cas_n          : out STD_LOGIC;
    ddr3_we_n           : out STD_LOGIC;
    ddr3_reset_n        : out STD_LOGIC;
    ddr3_ck_p           : out STD_LOGIC_VECTOR ( 0 to 0 );
    ddr3_ck_n           : out STD_LOGIC_VECTOR ( 0 to 0 );
    ddr3_cke            : out STD_LOGIC_VECTOR ( 0 to 0 );
    ddr3_dm             : out STD_LOGIC_VECTOR ( 1 downto 0 );
    ddr3_odt            : out STD_LOGIC_VECTOR ( 0 to 0 );
    app_addr            : in STD_LOGIC_VECTOR ( 28 downto 0 );
    app_cmd             : in STD_LOGIC_VECTOR ( 2 downto 0 );
    app_en              : in STD_LOGIC;
    app_wdf_data        : in STD_LOGIC_VECTOR ( 127 downto 0 );
    app_wdf_end         : in STD_LOGIC;
    app_wdf_mask        : in STD_LOGIC_VECTOR ( 15 downto 0 );
    app_wdf_wren        : in STD_LOGIC;
    app_rd_data         : out STD_LOGIC_VECTOR ( 127 downto 0 );
    app_rd_data_end     : out STD_LOGIC;
    app_rd_data_valid   : out STD_LOGIC;
    app_rdy             : out STD_LOGIC;
    app_wdf_rdy         : out STD_LOGIC;
    app_sr_req          : in STD_LOGIC;
    app_ref_req         : in STD_LOGIC;
    app_zq_req          : in STD_LOGIC;
    app_sr_active       : out STD_LOGIC;
    app_ref_ack         : out STD_LOGIC;
    app_zq_ack          : out STD_LOGIC;
    ui_clk              : out STD_LOGIC;
    ui_clk_sync_rst     : out STD_LOGIC;
    init_calib_complete : out STD_LOGIC;
    device_temp         : out STD_LOGIC_VECTOR ( 11 downto 0 );
    sys_clk_i           : in  std_logic;
    sys_rst             : in STD_LOGIC
  );
  end component;

-- Native First Word Fall Through FIFO to hole DDR playback data
-- Independent Clocks BlockRAM
-- 32-bit write data 1024 words deep ( r_fifo_wdata'length )
-- 128-bit read data 256 words deep ( app_wdf_data'length )
-- Active High Read Data Valid flag enabled
-- Write and Read Data Counts enabled
-- More Accurate Data Counts enabled
COMPONENT fifo_w32x1024_r128x256
  PORT (
    rst           : IN STD_LOGIC;
    wr_clk        : IN STD_LOGIC;
    rd_clk        : IN STD_LOGIC;
    din           : IN STD_LOGIC_VECTOR(31 DOWNTO 0);
    wr_en         : IN STD_LOGIC;
    rd_en         : IN STD_LOGIC;
    dout          : OUT STD_LOGIC_VECTOR(127 DOWNTO 0);
    full          : OUT STD_LOGIC;
    empty         : OUT STD_LOGIC;
    valid         : OUT STD_LOGIC;
    rd_data_count : OUT STD_LOGIC_VECTOR(8 DOWNTO 0);
    wr_data_count : OUT STD_LOGIC_VECTOR(10 DOWNTO 0);
    wr_rst_busy   : OUT STD_LOGIC;
    rd_rst_busy   : OUT STD_LOGIC
  );
END COMPONENT;

-- Native First Word Fall Through FIFO to hole DDR playback data
-- Independent Clocks BlockRAM
-- 128-bit write data 256 words deep ( app_rd_data'length )
-- 32-bit read data 1024 words deep  ( p_fifo_rdata'length )
-- Active High Read Data Valid flag enabled
-- Write and Read Data Counts enabled
-- More Accurate Data Counts enabled
COMPONENT fifo_w128x256_r32x1024
  PORT (
    rst           : IN STD_LOGIC;
    wr_clk        : IN STD_LOGIC;
    rd_clk        : IN STD_LOGIC;
    din           : IN STD_LOGIC_VECTOR(127 DOWNTO 0);
    wr_en         : IN STD_LOGIC;
    rd_en         : IN STD_LOGIC;
    dout          : OUT STD_LOGIC_VECTOR(31 DOWNTO 0);
    full          : OUT STD_LOGIC;
    empty         : OUT STD_LOGIC;
    valid         : OUT STD_LOGIC;
    rd_data_count : OUT STD_LOGIC_VECTOR(10 DOWNTO 0);
    wr_data_count : OUT STD_LOGIC_VECTOR(8 DOWNTO 0);
    wr_rst_busy   : OUT STD_LOGIC;
    rd_rst_busy   : OUT STD_LOGIC
  );
END COMPONENT;


component clk_wiz_0
port
 (-- Clock in ports
  -- Clock out ports
  clk_out1          : out    std_logic;
  clk_out2          : out    std_logic;
--  clk_out3          : out    std_logic;
  -- Status and control signals
  reset             : in     std_logic;
  locked            : out    std_logic;
  clk_in1           : in     std_logic
 );
end component;

-------------------------------------------------------------------------------
--  Constant Declarations
-------------------------------------------------------------------------------

  constant UART_DATA_WIDTH      : natural := 36/4; -- logging data width in nibbles
  constant MAX_SAMPLES          : std_logic_vector(31 downto 0) := X"01DCD650"; -- 5 seconds at 6.25 MHz fs_clk
  constant DDR_SIZE             : natural := 512*1024*1024;
  constant DDR_FIFO_DEPTH       : natural := 256;
  constant PHY_BYTES            : natural := 2;  -- 16-bit DQ for Nexys Video
  constant BURST_BYTES          : natural := 8;  -- MIG burst size BL8 = 8
  constant UI_APP_WORD_BYTES    : natural := 16; -- 128-bit UI read write DATA length
  constant USER_WORD_BYTES      : natural := 4;  -- 25-bit timestamp + 2 buttons + 1 switch + 4 PMOD inputs
  constant UI_BURST_WORDS       : natural := PHY_BYTES*BURST_BYTES/UI_APP_WORD_BYTES; -- 2*8/16 = 1 for Nexys Video 4:1 Controller
  constant CMD_WRITE            : std_logic_vector(2 downto 0) := "000";
  constant CMD_READ             : std_logic_vector(2 downto 0) := "001";
  constant TXT_MSG_LEN          : natural := 14;

-------------------------------------------------------------------------------
--  Type Declarations
-------------------------------------------------------------------------------

  type u_states is (us_idle, us_rec0, us_rec1, us_rec2, us_rec3, us_play0, us_play1, us_play2);
  type r_states is (rs_idle, rs_record);
  type p_states is (ps_idle, ps_play0, ps_play1, ps_play2, ps_msg0, ps_msgw0, ps_msg1, ps_msgw1);
  type msm_states is (m_idle, m_load, m_wr0, m_wr1, m_wait, m_end); -- Text Message state machine
  type strarray is array(0 to TXT_MSG_LEN-1) of std_logic_vector(7 downto 0);

-------------------------------------------------------------------------------
--  Signal Declarations
-------------------------------------------------------------------------------

signal ustate                     : u_states;
signal rstate                     : r_states;
signal pstate                     : p_states;
signal cstate                     : Msm_states;
signal init_calib_complete        : std_logic;
signal sys_rst_n                  : std_logic := '1';
signal areset                     : std_logic;
signal app_addr                   : std_logic_vector(28 downto 0) := (others => '0');
signal app_cmd                    : std_logic_vector(2 downto 0);
signal app_en                     : std_logic;
signal app_rdy                    : std_logic;
signal app_rd_data                : std_logic_vector(127 downto 0);
signal app_rd_data_end            : std_logic;
signal app_rd_data_valid          : std_logic;
signal app_wdf_data               : std_logic_vector(127 downto 0);
signal app_wdf_end                : std_logic;
signal app_wdf_mask               : std_logic_vector(15 downto 0);
signal app_wdf_rdy                : std_logic;
signal app_wdf_wren               : std_logic;

signal clk                        : std_logic;
signal rst                        : std_logic;

signal burst_count                : natural range 0 to 3;

signal ts                         : std_logic_vector(31 downto 0);
signal ts_clr                     : std_logic;
signal ts_cnten                   : std_logic;

signal pll_locked                 : std_logic;

signal r_fifo_reset               : std_logic;
signal fs_clk                     : std_logic;
signal ui_clk                     : std_logic;
signal clk100                     : std_logic;
signal clk200                     : std_logic;
signal r_fifo_wdata               : std_logic_vector(31 downto 0);
signal r_fifo_wren                : std_logic;
signal r_fifo_rden                : std_logic;
signal r_fifo_rdata               : std_logic_vector(127 downto 0);
signal r_fifo_wfull               : std_logic;
signal r_fifo_rempty              : std_logic;
signal r_fifo_valid               : std_logic;
signal r_fifo_rd_count            : std_logic_vector(8 downto 0);
signal r_fifo_wr_count            : std_logic_vector(10 downto 0);
signal p_fifo_reset               : std_logic;
signal p_fifo_wdata               : std_logic_vector(127 downto 0);
signal p_fifo_wren                : std_logic;
signal p_fifo_rden                : std_logic;
signal p_fifo_rdata               : std_logic_vector(31 downto 0);
signal p_fifo_rdata_r             : std_logic_vector(31 downto 0);
signal p_fifo_wfull               : std_logic;
signal p_fifo_rempty              : std_logic;
signal p_fifo_valid               : std_logic;
signal p_fifo_rd_count            : std_logic_vector(10 downto 0);
signal p_fifo_wr_count            : std_logic_vector(8 downto 0);

signal r_flg                      : std_logic;
signal p_flg                      : std_logic;
signal rcount                     : std_logic_vector(31 downto 0);
signal pcount                     : std_logic_vector(31 downto 0);
signal rst_cnt                    : std_logic_vector(31 downto 0);
signal burst_word                 : std_logic_vector(2 downto 0);
signal ADDRESS_BLOCK_SIZE         : std_logic_vector(app_addr'length-1 downto 0) := CONV_STD_LOGIC_VECTOR(BURST_BYTES,app_addr'length);
signal MIN_DDR_WRITE_WORDS        : std_logic_vector(r_fifo_rd_count'length-1 downto 0) := CONV_STD_LOGIC_VECTOR(UI_BURST_WORDS,r_fifo_rd_count'length);
signal MAX_DDR_READ_WORDS         : std_logic_vector(p_fifo_wr_count'length-1 downto 0) := CONV_STD_LOGIC_VECTOR(DDR_FIFO_DEPTH-2-UI_BURST_WORDS,p_fifo_wr_count'length);
signal data_write_stb             : std_logic;
signal uart_data                  : std_logic_vector(4*UART_DATA_WIDTH-1 downto 0);
signal busy                       : std_logic;

signal d_fifo_datain              : std_logic_vector(31 downto 0);
signal d_fifo_dataout             : std_logic_vector(31 downto 0);
signal d_fifo_wr_en               : std_logic;
signal d_fifo_rd_en               : std_logic;
signal d_fifo_full                : std_logic;
signal d_fifo_empty               : std_logic;

signal rec_btn_r                  : std_logic;
signal rec_btn_stb                : std_logic;
signal rec_btn_dbcnt              : std_logic;
signal rec_btn_lockout            : std_logic;
signal play_btn_r                 : std_logic;
signal play_btn_stb               : std_logic;
signal play_btn_dbcnt             : std_logic;
signal play_btn_lockout           : std_logic;

signal msg0   : strarray := (X"20", X"50", X"6C", X"61", X"79", X"20", X"53", X"74", X"61", X"72", X"74", X"73", X"0D", X"0A"); -- ' Play Starts'
signal msg1   : strarray := (X"20", X"50", X"6C", X"61", X"79", X"20", X"45", X"6E", X"64", X"73", X"2E", X"2E", X"0D", X"0A"); -- ' Play Ends..'
signal msg_ptr                    : natural range 0 to 3;
signal char_cnt                   : natural range 0 to TXT_MSG_LEN-1;
signal msg_sent_flg               : std_logic;
signal send_msg_flg               : std_logic;
signal uart_ascii_in              : std_logic_vector(7 downto 0);
signal uart_ascii_write_stb       : std_logic;


signal probe0                     : std_logic_vector(15 downto 0);
signal probe1                     : std_logic_vector(127 downto 0);
signal probe2                     : std_logic_vector(127 downto 0);
signal probe3                     : std_logic_vector(15 downto 0);
signal probe4                     : std_logic_vector(15 downto 0);
signal probe10                    : std_logic_vector(7 downto 0);
signal probe11                    : std_logic_vector(27 downto 0);
signal probe12                    : std_logic_vector(7 downto 0);

signal dgb_ts                     : std_logic_vector(27 downto 0);
signal dbg_data                   : std_logic_vector(7 downto 0);

signal dly_counter                : std_logic_vector(23 downto 0);

signal gdb_ui_states              : std_logic_vector(3 downto 0);

begin


-------------------------------------------------------------------------------
--  Component Instantiations
-------------------------------------------------------------------------------

  MMCM_inst : clk_wiz_0
   port map (
--   clk_out1   => clk100,  -- UART clock
   clk_out1   => clk200,  -- MIG system_clk
   clk_out2   => fs_clk,  -- 100Mhz MHz Sample clock
   reset      => '0',
   locked     => pll_locked,
   clk_in1    => sysclk
  );


-- MIG User Interface instantiation

  DDR_INF_inst : mig_7series_0
  Port map (
    ddr3_dq             => ddr3_dq,
    ddr3_dqs_n          => ddr3_dqs_n,
    ddr3_dqs_p          => ddr3_dqs_p,
    ddr3_addr           => ddr3_addr,-- wrong width 
    ddr3_ba             => ddr3_ba,
    ddr3_ras_n          => ddr3_ras_n,
    ddr3_cas_n          => ddr3_cas_n,
    ddr3_we_n           => ddr3_we_n ,
    ddr3_reset_n        => ddr3_reset_n,
    ddr3_ck_p           => ddr3_ck_p,
    ddr3_ck_n           => ddr3_ck_n,
    ddr3_cke            => ddr3_cke,
    ddr3_dm             => ddr3_dm,
    ddr3_odt            => ddr3_odt,
    app_addr            => app_addr(28 downto 0),
    app_cmd             => app_cmd,
    app_en              => app_en,
    app_wdf_data        => app_wdf_data,
    app_wdf_end         => app_wdf_end ,
    app_wdf_mask        => app_wdf_mask,
    app_wdf_wren        => app_wdf_wren,
    app_rd_data         => app_rd_data,
    app_rd_data_end     => app_rd_data_end,
    app_rd_data_valid   => app_rd_data_valid,
    app_rdy             => app_rdy,
    app_wdf_rdy         => app_wdf_rdy,
    app_sr_req          => '0',
    app_ref_req         => '0',
    app_zq_req          => '0',
    app_sr_active       => open,
    app_ref_ack         => open,
    app_zq_ack          => open,
    ui_clk              => ui_clk,
    ui_clk_sync_rst     => rst,
    init_calib_complete => init_calib_complete,
    device_temp         => open,
    sys_clk_i           => clk200,
    sys_rst             => sys_rst_n  -- in the MIG Wizard this is active low by default
  );

  RECORD_FIFO_inst : fifo_w32x1024_r128x256
  PORT MAP (
    rst           => r_fifo_reset,
    wr_clk        => fs_clk,
    rd_clk        => ui_clk,
    din           => r_fifo_wdata,
    wr_en         => r_fifo_wren,
    rd_en         => r_fifo_rden,
    dout          => r_fifo_rdata,
    full          => r_fifo_wfull,
    empty         => r_fifo_rempty,
    valid         => r_fifo_valid,
    rd_data_count => r_fifo_rd_count,
    wr_data_count => r_fifo_wr_count,
    wr_rst_busy   => open,
    rd_rst_busy   => open
  );


  PLAY_FIFO_inst : fifo_w128x256_r32x1024
  PORT MAP (
    rst           => p_fifo_reset,
    wr_clk        => ui_clk,
    rd_clk        => clk100,  -- UART clock domain
    din           => p_fifo_wdata,
    wr_en         => p_fifo_wren,
    rd_en         => p_fifo_rden,
    dout          => p_fifo_rdata,
    full          => p_fifo_wfull,
    empty         => p_fifo_rempty,
    valid         => p_fifo_valid,
    rd_data_count => p_fifo_rd_count,
    wr_data_count => p_fifo_wr_count,
    wr_rst_busy   => open,
    rd_rst_busy   => open
  );

-------------------------------------------------------------------------------
--  Concurrent Assignments
-------------------------------------------------------------------------------

  areset        <=  not cpu_resetn;

--  p_fifo_reset  <= '1' when r_flg = '1' else
--                   '1' when areset = '1' else
--                   '0';
  r_fifo_reset  <= '1' when areset = '1' else '0';

  -- you should define the buttons and switch as appropriate for your board
  r_fifo_wdata  <= ts(24 downto 0) & btnl & btnr & sw(0) & JA(3 downto 0);

  -- wire up the component signals that haven't been assigned yet.
  app_wdf_data  <= r_fifo_rdata;
  app_wdf_mask  <= (others => '0');

  


-------------------------------------------------------------------------------
--  Process Declarations
-------------------------------------------------------------------------------

  -- The UI_SM simply tries to keep the Record FIFO empty and the Play FIFO full.
  -- Because we can't have uninterupted writing of data samples to the DDR we've selected a sample rate to
  -- guarantee that the DDR Controller can write or read faster than the UI_SM can read or write data
  -- to make this application simpler to follow

--  type u_states is (us_idle, us_rec0, us_rec1, us_rec2, us_rec3, us_play0, us_play1, us_play2);
  UI_SM : process (ui_clk, areset)
  begin
    if (areset = '1') then
      app_en            <= '0';
      app_cmd           <= CMD_WRITE;
      app_addr          <= (others => '0');
      app_wdf_wren      <= '0';
      app_wdf_end       <= '0';
      burst_word        <= (others => '0');
      ustate     <= us_idle;
    elsif rising_edge(ui_clk) then
      app_en            <= '0';
      app_wdf_wren      <= '0';
      app_wdf_end       <= '0';
      r_fifo_rden       <= '0';
      p_fifo_wren       <= '0';
      case ustate is
        when us_idle =>
          burst_word    <= CONV_STD_LOGIC_VECTOR(UI_BURST_WORDS-1, burst_word'length);
          app_cmd       <= CMD_WRITE;
          if (init_calib_complete = '1' and r_flg = '1' and r_fifo_rd_count >= MIN_DDR_WRITE_WORDS) then
            ustate <= us_rec0;
          elsif (init_calib_complete = '1' and p_flg = '1' and p_fifo_wr_count < MAX_DDR_READ_WORDS) then
            ustate <= us_play0;
          end if;
          if r_flg = '0' and p_flg = '0' then
            app_addr  <= (others => '0');
          end if;

        -- write enough data to the MIG UI to do 8 burst writes
        when us_rec0 =>
          if app_wdf_rdy = '1' and r_fifo_valid = '1' and burst_word > 0 then
            r_fifo_rden   <= '1';
            app_wdf_wren  <= '1';
            app_wdf_end   <= '0';
            burst_word    <= burst_word -1;
            ustate <= us_rec0;
          elsif app_wdf_rdy = '1' and r_fifo_valid = '1' and burst_word = 0 then
            r_fifo_rden   <= '1';
            app_wdf_wren  <= '1';
            app_wdf_end   <= '1';
            ustate <= us_rec1;
          else
            ustate <= us_rec0;
          end if;


        when us_rec1 =>
          app_en        <= '1';
          app_cmd       <= CMD_WRITE;
          ustate <= us_rec2;

        when us_rec2 =>
          if app_rdy = '1' then
            app_addr <= app_addr + ADDRESS_BLOCK_SIZE;
            ustate <= us_rec3;
          else
            app_en        <= '1';
            app_cmd       <= CMD_WRITE;
            ustate <= us_rec2;
          end if;

        when us_rec3 =>
          ustate <= us_idle;


        when us_play0 =>
          app_en        <= '1';
          app_cmd       <= CMD_READ;
          ustate <= us_play1;

        when us_play1 =>
          if app_rdy = '1' then
            app_cmd       <= CMD_READ;
            app_addr <= app_addr + ADDRESS_BLOCK_SIZE;
            ustate <= us_play2;
          else
            app_en        <= '1';
            app_cmd       <= CMD_READ;
            ustate <= us_play1;
          end if;

        -- read enough data from the MIG UI to do 8 burst reads
        when us_play2 =>
          if app_rd_data_valid = '1' and  burst_word > 0 then
            p_fifo_wren   <= '1';
            p_fifo_wdata  <= app_rd_data;
            burst_word    <= burst_word -1;
            ustate <= us_play2;
          elsif app_rd_data_valid = '1' and  burst_word = 0 then
            p_fifo_wren   <= '1';
            p_fifo_wdata  <= app_rd_data;
            ustate <= us_idle;
          else
            ustate <= us_play2;
          end if;

        when others =>
          ustate  <= us_idle;

      end case;
    end if;
  end process UI_SM;


--  type r_states is (rs_idle, rs_record);
  RECORD_SM : process (fs_clk, areset)
  begin
    if (areset = '1') then
      rcount        <= (others => '0');
      r_fifo_wren   <= '0';
      rstate        <= rs_idle;
    elsif rising_edge(fs_clk) then
      r_fifo_wren   <= '0';
      r_flg         <= '0';
      case rstate is
        when rs_idle =>
          rcount  <= (others => '0');
          -- press btnu to start recording
          if btnu = '1' then
            rstate <= rs_record;
          else
            rstate <= rs_idle;
          end if;

        when rs_record =>
          r_flg         <= '1';
          r_fifo_wren   <= '1';
          if rcount < MAX_SAMPLES then
            rcount <= rcount + 1;
            rstate <= rs_record;
          else
            rstate <= rs_idle;
          end if;

        when others =>
          rstate  <= rs_idle;

      end case;
    end if;
  end process RECORD_SM;

--  type p_states is (ps_idle, ps_play0, ps_play1, ps_play2, ps_msg0, ps_msgw0 ps_msg1, ps_msgw1);
  PLAY_SM : process (clk100, areset)
  begin
    if (areset = '1') then
      pcount        <= (others => '0');
      p_fifo_rden   <= '0';
      dly_counter   <= (others => '0');
      pstate        <= ps_idle;
      msg_ptr       <= 0;
      p_fifo_reset  <= '1';
      send_msg_flg  <= '0';
    elsif rising_edge(clk100) then
      p_fifo_rden   <= '0';
      p_flg         <= '0';
      send_msg_flg  <= '0';
      p_fifo_reset  <= '0';
      case pstate is
        when ps_idle =>
          p_fifo_reset  <= '1';
          pcount        <= (others => '0');
          dly_counter   <= (others => '0');
          -- press btnd to start play back and display transitions
          if btnd = '1' then
            pstate <= ps_msg0;
          else
            pstate <= ps_idle;
          end if;

        when ps_msg0 =>
          send_msg_flg  <= '1';
          msg_ptr       <= 0;
          pstate        <= ps_msgw0;

        when ps_msgw0 =>
          msg_ptr       <= 0;
          if msg_sent_flg = '1' then
            pstate  <= ps_play0;
          else
            pstate  <= ps_msgw0;
          end if;


        -- wait for valid data
        when ps_play0 =>
          p_flg         <= '1';
          if p_fifo_valid = '1' then
            p_fifo_rden   <= '1';
            pstate <= ps_play1;
          else
            pstate <= ps_play0;
          end if;

        when ps_play1 =>
          p_flg         <= '1';
          if pcount <= MAX_SAMPLES then
            pcount <= pcount + 1;
            pstate <= ps_play0;
          else
            pstate <= ps_play2;
          end if;

        when ps_play2 =>
          if dly_counter < X"1312D0" then
            dly_counter <= dly_counter + 1;
            pstate <= ps_play2;
          else
            pstate  <= ps_msg1;
          end if;

        when ps_msg1 =>
          msg_ptr       <= 1;
          if d_fifo_empty = '1' and busy = '0' then
            send_msg_flg  <= '1';
            pstate        <= ps_msgw1;
          else
            pstate        <= ps_msg1;
          end if;

        when ps_msgw1 =>
          msg_ptr       <= 1;
          if msg_sent_flg = '1' then
            pstate  <= ps_idle;
          else
            pstate  <= ps_msgw1;
          end if;

        when others =>
          pstate  <= ps_idle;

      end case;
    end if;
  end process PLAY_SM;

  MIG_RESET_proc : process(clk100)
  begin
    if rising_edge(clk100) then
      if rst_cnt < X"00080000" then
        rst_cnt <= rst_cnt + 1;
        sys_rst_n <= '0';
      else
        rst_cnt <= rst_cnt;
        sys_rst_n <= '1';
      end if;
    end if;
  end process MIG_RESET_proc;



---------------------------------------------------------------------------------
----  Other Output Assignments
---------------------------------------------------------------------------------
  --
  led(7)  <= '1' when pll_locked = '1' else '0';
  led(6)  <= '1' when init_calib_complete = '1' else 'Z';
  led(5)  <= '1' when r_flg = '1' else '0';
  led(4)  <= '1' when p_flg = '1' else '0';
  led(3)  <= '0';
  led(2)  <= '0';
  led(1)  <= '0';
  led(0)  <= '0';

  JA(3 downto 0)  <= "ZZZZ";
  JA(4)           <= '1' when btnl = '1' or btnr = '1' else '0';
  JA(7 downto 5)  <= "ZZZ";

end rtl;
