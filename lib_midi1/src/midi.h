/*
 * midi.h
 * First implementation of a MIDI communication by channels...
 *
 *  Created on: 2015.05.28.
 *      Author: Barna
 *  Copyright (c) 2013-2015, MYND-ideal Ltd, All rights reserved
 */


#ifndef MIDI_H_
#define MIDI_H_
/*
 MIDI OUT not available on CIRCLE slot!

 #define SLOT_TRIANGEL 2
 #define CARD_AUDIO SLOT_TRIANGLE

 #if (CARD_AUDIO == SLOT_TRIANGLE)
 #define TILEAUDIO  on tile[0]:
 TILEAUDIO SkMidiUartOutPinDef_T g_MidiUartOutPin={
        XS1_PORT_8D,0,(1<<7),0, //P8D7,P16B15 X0D43 triangle.
        3200                    //Midi Clk div
 };
 TILEAUDIO clock SkMidiClk = XS1_CLKBLK_REF;
 TILEAUDIO SkMidiUartInPinDef_T g_MidiUartInPin={
        XS1_PORT_1J,         1, //P1j0 X1D25 triangle, circle
        3200                    //Midi Clk div
 };
 TILEAUDIO out port g_ledOnAudioCard = XS1_PORT_4E; //P4E3

    streaming chan c_min;
    streaming chan  c_mout;
    sk_midi_port_init_rx(g_MidiUartInPin);
    sk_midi_port_init_tx(g_MidiUartOutPin);
    par{
        sk_midi_port_rx(g_MidiUartInPin , c_min);
        sk_midi_port_tx(g_MidiUartOutPin , c_mout);
        produce(c_mout, c_int, c_intp, c_msg);
        consume(c_min, c_int);
    };
#endif
*/

/**Midi Uart Input pin def
 * Must be separated from output pin def struct. Because of resource locking.
 */
typedef struct SkMidiUartInPinDef_S{
 in port mPortIn;
 int mEnabledIn;
 int mClkDiv;
} SkMidiUartInPinDef_T;

/**Midi Uart Output pin def
 * Must be separated from input pin def struct. Because of resource locking.
 */
typedef struct SkMidiUartOutPinDef_S{
 out port mPortOut;
 unsigned int mLo;
 unsigned int mHi;
 int mEnabledOut;
 int mClkDiv;
} SkMidiUartOutPinDef_T;


//Must be definied a global clock in main
extern clock SkMidiClk;// = XS1_CLKBLK_REF;

/* this bitmask macros used for multibit general output port
 */
#define P_GPIO_SS_EN_CTRL       0x01    /* SPI Slave Select Enable. 0 - SPI SS Enabled, 1 - SPI SS Disabled. */
#define P_GPIO_MCLK_SEL         0x02    /* MCLK frequency select. 0 - 22.5792MHz, 1 - 24.576MHz. */
#define P_GPIO_COD_RST_N        0x04    /* CODEC RESET. Active low. */
#define P_GPIO_LED              0x08    /* LED. Active high. */

//Layer 1
void sk_midi_port_init_tx(SkMidiUartOutPinDef_T &dOut);
void sk_midi_port_init_rx(SkMidiUartInPinDef_T &dIn);
void sk_midi_port_tx(SkMidiUartOutPinDef_T &dOut, streaming chanend cIn);
void sk_midi_port_rx(SkMidiUartInPinDef_T &dIn, streaming chanend cOut);


//Layer2

/** MIDI struct
 *
 */
typedef struct Midi_S{
    unsigned char h;
    unsigned char n;
    unsigned char v;
} Midi_T;

/**
 * MIDI raw packet
 * internal datas and packet repr.
 */
typedef struct MidiRawPacket_S{
    unsigned char mLen;
    union{
        unsigned char byte[4];
        Midi_T midi;
    } data;
    int ts;
} MidiRawPacket_T;

enum{
    CM_NoteOff,
    CM_NoteOn,
    CM_KeyAfter,
    CM_CC,
    CM_PC,
    CM_ChanAfter,
    CM_Pitch,
    CM_Other
};
#define SETCMD_CH(p, c1, c2) p.data.midi.h=0x80|(c2-1)|((c1&7)<<4)
#define GETCMD(p) ((p.data.midi.h& 0x70)>>4)
#define GETCH(p) ((p.data.midi.h& 0x0F)+1)


/**
 * midiReadRawMore()
 * First byte comes from the state machine, so the packet first byte was already get from the serial port.
 */
int  midiReadRawMore(streaming chanend cIn, unsigned char firstByte, MidiRawPacket_T&packet);
/**
 * midiReadInternal()
 * this reader used for an internal input channel and stores packet in the spec. argument ref.
 */
void midiReadInternal(streaming chanend cIn, unsigned char len, MidiRawPacket_T&packet);
/**
 * midiReadInternalSendRaw()
 * Reads from internal channel, then sends to output channel and stores in argument ref. (MIDI trough :P)
 */
void midiReadInternalSendRaw(streaming chanend cIn, unsigned char len, MidiRawPacket_T&packet, streaming chanend cOut);
/**
 * midiSendRaw
 * sends the packet out.
 */
void midiSendRaw(MidiRawPacket_T& packet, streaming chanend cOut);
/**
 * midiSendInternal
 * sends the packet internally. (same)
 */
void midiSendInternal(MidiRawPacket_T& packet, streaming chanend cOut);

#endif /* MIDI_H_ */
