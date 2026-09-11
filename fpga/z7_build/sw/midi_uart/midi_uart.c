#include "midi_uart.h"

#include "xil_io.h"
#include "xparameters.h"
#include "xuartps.h"

#if defined(XPAR_XUARTPS_1_DEVICE_ID)
#define MIDI_UART_DEVICE_ID XPAR_XUARTPS_1_DEVICE_ID
#elif defined(XPAR_PS7_UART_1_DEVICE_ID)
#define MIDI_UART_DEVICE_ID XPAR_PS7_UART_1_DEVICE_ID
#else
#define MIDI_UART_DEVICE_ID 1U
#endif

#if defined(XPAR_AXI_BRAM_CTRL_0_S_AXI_BASEADDR)
#define MIDI_REGS_BASE XPAR_AXI_BRAM_CTRL_0_S_AXI_BASEADDR
#elif defined(XPAR_AXI_BRAM_CTRL_0_BASEADDR)
#define MIDI_REGS_BASE XPAR_AXI_BRAM_CTRL_0_BASEADDR
#else
#define MIDI_REGS_BASE 0x40000000U
#endif

#define REG_AUDIO     0x0CU
#define REG_CA        0x18U
#define REG_YUV_YCR   0x58U
#define REG_YUV_CB    0x5CU
#define REG_NOISE     0x60U
#define REG_NOISE_CTL 0x64U
#define REG_OSC1      0x68U
#define REG_OSC2      0x6CU
#define REG_OSC1_PWM  0x70U
#define REG_OSC2_PWM  0x74U
#define REG_VIDEO     0x78U
#define REG_OSC1_A    0xCCU
#define REG_OSC2_A    0xD0U
#define REG_NOISE_A   0xDCU

static XUartPs MidiUart;

static u8 g_runningStatus;
static u8 g_needed;
static u8 g_got;
static u8 g_data[2];
static u8 g_inSysex;
static u32 g_msgCount;
static u8 g_lastStatus;
static u8 g_lastData1;
static u8 g_lastData2;

static u8 g_osc1_f_msb, g_osc1_f_lsb;
static u8 g_osc2_f_msb, g_osc2_f_lsb;
static u8 g_noise_f_msb, g_noise_f_lsb;
static u8 g_y_msb, g_y_lsb;
static u8 g_cr_msb, g_cr_lsb;
static u8 g_cb_msb, g_cb_lsb;

static u32 MidiRegRd(u32 offset)
{
	return Xil_In32(MIDI_REGS_BASE + offset);
}

static void MidiRegFld(u32 offset, u32 mask, u32 shift, u32 value)
{
	u32 word;

	word = MidiRegRd(offset);
	word &= ~(mask << shift);
	word |= ((value & mask) << shift);
	Xil_Out32(MIDI_REGS_BASE + offset, word);
}

static u32 MidiU14(u8 msb, u8 lsb)
{
	return ((u32)msb << 7) | (u32)lsb;
}

static u32 MidiU12(u8 msb, u8 lsb)
{
	return MidiU14(msb, lsb) >> 2;
}

static void MidiSplit14(u32 value14, u8 *msb, u8 *lsb)
{
	*msb = (u8)((value14 >> 7) & 0x7FU);
	*lsb = (u8)(value14 & 0x7FU);
}

static void MidiSplit12(u32 value12, u8 *msb, u8 *lsb)
{
	MidiSplit14(value12 << 2, msb, lsb);
}

static u32 MidiScale(u8 val, u32 maxv)
{
	return ((u32)val * maxv) / 127U;
}

static void MidiMapCc(u8 cc, u8 val)
{
	val &= 0x7FU;

	switch (cc)
	{
	case 1:
		g_osc1_f_msb = val;
		MidiRegFld(REG_OSC1, 0x3FFFU, 0U, MidiU14(g_osc1_f_msb, g_osc1_f_lsb));
		break;
	case 2:
		g_osc1_f_lsb = val;
		MidiRegFld(REG_OSC1, 0x3FFFU, 0U, MidiU14(g_osc1_f_msb, g_osc1_f_lsb));
		break;
	case 3:
		MidiRegFld(REG_OSC1, 0xFFU, 16U, val);
		break;
	case 4:
		MidiRegFld(REG_OSC1_PWM, 0x1FFU, 0U, MidiScale(val, 360U));
		break;
	case 5:
		MidiRegFld(REG_OSC1_PWM, 0x3U, 10U, (u32)val >> 5);
		break;
	case 6:
		MidiRegFld(REG_OSC1, 0x3U, 30U, (u32)val >> 5);
		break;
	case 7:
		MidiRegFld(REG_OSC1, 0x1U, 28U, (val >= 64U) ? 1U : 0U);
		break;
	case 8:
		MidiRegFld(REG_OSC1_A, 0xFFFU, 0U, MidiScale(val, 4095U));
		break;

	case 9:
		g_osc2_f_msb = val;
		MidiRegFld(REG_OSC2, 0x3FFFU, 0U, MidiU14(g_osc2_f_msb, g_osc2_f_lsb));
		break;
	case 10:
		g_osc2_f_lsb = val;
		MidiRegFld(REG_OSC2, 0x3FFFU, 0U, MidiU14(g_osc2_f_msb, g_osc2_f_lsb));
		break;
	case 11:
		MidiRegFld(REG_OSC2, 0xFFU, 16U, val);
		break;
	case 12:
		MidiRegFld(REG_OSC2_PWM, 0x1FFU, 0U, MidiScale(val, 360U));
		break;
	case 13:
		MidiRegFld(REG_OSC2_PWM, 0x3U, 10U, (u32)val >> 5);
		break;
	case 14:
		MidiRegFld(REG_OSC2, 0x3U, 30U, (u32)val >> 5);
		break;
	case 15:
		MidiRegFld(REG_OSC2, 0x1U, 28U, (val >= 64U) ? 1U : 0U);
		break;
	case 16:
		MidiRegFld(REG_OSC2_A, 0xFFFU, 0U, MidiScale(val, 4095U));
		break;

	case 17:
		g_noise_f_msb = val;
		MidiRegFld(REG_NOISE, 0x3FFFU, 0U, MidiU14(g_noise_f_msb, g_noise_f_lsb));
		break;
	case 18:
		g_noise_f_lsb = val;
		MidiRegFld(REG_NOISE, 0x3FFFU, 0U, MidiU14(g_noise_f_msb, g_noise_f_lsb));
		break;
	case 19:
		MidiRegFld(REG_NOISE, 0x7U, 17U, (u32)val >> 4);
		break;
	case 20:
		MidiRegFld(REG_NOISE, 0x3U, 28U, (u32)val >> 5);
		break;
	case 21:
		MidiRegFld(REG_NOISE_CTL, 0x1U, 0U, (val >= 64U) ? 1U : 0U);
		break;
	case 22:
		MidiRegFld(REG_NOISE_A, 0xFFFU, 0U, MidiScale(val, 4095U));
		break;

	case 23:
		MidiRegFld(REG_AUDIO, 0xFFU, 0U, MidiScale(val, 255U));
		break;
	case 24:
		MidiRegFld(REG_AUDIO, 0x7U, 11U, (u32)val >> 4);
		break;
	case 25:
		MidiRegFld(REG_AUDIO, 0x7U, 8U, (u32)val >> 4);
		break;

	case 26:
		g_y_msb = val;
		MidiRegFld(REG_YUV_YCR, 0xFFFU, 0U, MidiU12(g_y_msb, g_y_lsb));
		break;
	case 27:
		g_y_lsb = val;
		MidiRegFld(REG_YUV_YCR, 0xFFFU, 0U, MidiU12(g_y_msb, g_y_lsb));
		break;
	case 28:
		g_cr_msb = val;
		MidiRegFld(REG_YUV_YCR, 0xFFFU, 16U, MidiU12(g_cr_msb, g_cr_lsb));
		break;
	case 29:
		g_cr_lsb = val;
		MidiRegFld(REG_YUV_YCR, 0xFFFU, 16U, MidiU12(g_cr_msb, g_cr_lsb));
		break;
	case 30:
		g_cb_msb = val;
		MidiRegFld(REG_YUV_CB, 0xFFFU, 0U, MidiU12(g_cb_msb, g_cb_lsb));
		break;
	case 31:
		g_cb_lsb = val;
		MidiRegFld(REG_YUV_CB, 0xFFFU, 0U, MidiU12(g_cb_msb, g_cb_lsb));
		break;

	case 32:
		MidiRegFld(REG_VIDEO, 0x3U, 4U, (u32)val >> 5);
		break;
	case 33:
		MidiRegFld(REG_VIDEO, 0x1U, 7U, (val >= 64U) ? 1U : 0U);
		break;
	case 34:
		MidiRegFld(REG_VIDEO, 0x1U, 8U, (val >= 64U) ? 1U : 0U);
		break;
	case 35:
		MidiRegFld(REG_CA, 0xFFU, 0U, val);
		break;

	default:
		break;
	}
}

static void MidiMapSeed(void)
{
	u32 w;

	w = MidiRegRd(REG_OSC1);
	MidiSplit14(w & 0x3FFFU, &g_osc1_f_msb, &g_osc1_f_lsb);
	w = MidiRegRd(REG_OSC2);
	MidiSplit14(w & 0x3FFFU, &g_osc2_f_msb, &g_osc2_f_lsb);
	w = MidiRegRd(REG_NOISE);
	MidiSplit14(w & 0x3FFFU, &g_noise_f_msb, &g_noise_f_lsb);
	w = MidiRegRd(REG_YUV_YCR);
	MidiSplit12(w & 0xFFFU, &g_y_msb, &g_y_lsb);
	MidiSplit12((w >> 16) & 0xFFFU, &g_cr_msb, &g_cr_lsb);
	w = MidiRegRd(REG_YUV_CB);
	MidiSplit12(w & 0xFFFU, &g_cb_msb, &g_cb_lsb);
}

static u8 MidiDataBytes(u8 status)
{
	u8 hi;

	if (status >= 0xF8U)
	{
		return 0U;
	}

	switch (status)
	{
	case 0xF1U:
	case 0xF3U:
		return 1U;
	case 0xF2U:
		return 2U;
	case 0xF0U:
	case 0xF4U:
	case 0xF5U:
	case 0xF6U:
	case 0xF7U:
		return 0U;
	default:
		break;
	}

	hi = status & 0xF0U;
	if ((hi == 0xC0U) || (hi == 0xD0U))
	{
		return 1U;
	}
	return 2U;
}

static void MidiMapApply(u8 status, u8 data1, u8 data2)
{
	if ((status & 0xF0U) != 0xB0U)
	{
		return;
	}
	if ((status & 0x0FU) != 0U)
	{
		return;
	}
	MidiMapCc(data1, data2);
}

static void MidiComplete(u8 status, u8 data1, u8 data2)
{
	g_lastStatus = status;
	g_lastData1 = data1;
	g_lastData2 = data2;
	g_msgCount++;
	MidiMapApply(status, data1, data2);
}

static void MidiByte(u8 byte)
{
	u8 status;

	if (byte >= 0xF8U)
	{
		/* Realtime: do not disturb running status or sysex. */
		return;
	}

	if (byte & 0x80U)
	{
		if (byte == 0xF0U)
		{
			g_inSysex = 1U;
			g_runningStatus = 0U;
			g_needed = 0U;
			g_got = 0U;
			return;
		}
		if (byte == 0xF7U)
		{
			g_inSysex = 0U;
			return;
		}
		if (g_inSysex)
		{
			return;
		}

		g_runningStatus = byte;
		g_needed = MidiDataBytes(byte);
		g_got = 0U;
		if (g_needed == 0U)
		{
			MidiComplete(byte, 0U, 0U);
			g_runningStatus = 0U;
		}
		return;
	}

	if (g_inSysex)
	{
		return;
	}

	if (g_needed == 0U)
	{
		if (g_runningStatus == 0U)
		{
			return;
		}
		g_needed = MidiDataBytes(g_runningStatus);
		g_got = 0U;
	}

	if (g_got < 2U)
	{
		g_data[g_got] = byte;
	}
	g_got++;

	if (g_got >= g_needed)
	{
		status = g_runningStatus;
		MidiComplete(status, g_data[0], (g_needed > 1U) ? g_data[1] : 0U);
		g_needed = 0U;
		g_got = 0U;
		if ((status & 0xF0U) == 0xF0U)
		{
			g_runningStatus = 0U;
		}
	}
}

int MidiUartInit(void)
{
	XUartPs_Config *cfg;
	int status;
	u32 base;

	cfg = XUartPs_LookupConfig(MIDI_UART_DEVICE_ID);
	if (cfg == NULL)
	{
		return XST_FAILURE;
	}

	status = XUartPs_CfgInitialize(&MidiUart, cfg, cfg->BaseAddress);
	if (status != XST_SUCCESS)
	{
		return status;
	}

	XUartPs_SetOperMode(&MidiUart, XUARTPS_OPER_MODE_NORMAL);
	status = XUartPs_SetBaudRate(&MidiUart, MIDI_UART_BAUD);
	if (status != XST_SUCCESS)
	{
		return status;
	}

	base = MidiUart.Config.BaseAddress;
	while (XUartPs_IsReceiveData(base) != 0)
	{
		(void)XUartPs_ReadReg(base, XUARTPS_FIFO_OFFSET);
	}

	g_runningStatus = 0U;
	g_needed = 0U;
	g_got = 0U;
	g_inSysex = 0U;
	g_msgCount = 0U;
	g_lastStatus = 0U;
	g_lastData1 = 0U;
	g_lastData2 = 0U;

	MidiMapSeed();

	return XST_SUCCESS;
}

void MidiUartPoll(void)
{
	u32 base;

	if (MidiUart.IsReady != XIL_COMPONENT_IS_READY)
	{
		return;
	}

	base = MidiUart.Config.BaseAddress;
	while (XUartPs_IsReceiveData(base) != 0)
	{
		MidiByte((u8)XUartPs_ReadReg(base, XUARTPS_FIFO_OFFSET));
	}
}

u32 MidiUartMsgCount(void)
{
	return g_msgCount;
}

u8 MidiUartLastStatus(void)
{
	return g_lastStatus;
}

u8 MidiUartLastData1(void)
{
	return g_lastData1;
}

u8 MidiUartLastData2(void)
{
	return g_lastData2;
}
