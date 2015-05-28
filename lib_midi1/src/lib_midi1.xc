/*
 * lib_midi1.xc
 *
 *  Created on: 2015.05.28.
 *      Author: Barna Faragó
 *  Copyright (c) 2013-2015, MYND-ideal Ltd, All rights reserved
 */




#include <xs1.h>
#include "midi.h"

void sk_midi_port_init_rx(SkMidiUartInPinDef_T &dIn){
    if (dIn.mEnabledIn){
        configure_in_port_no_ready(dIn.mPortIn, SkMidiClk);
        clearbuf(dIn.mPortIn);
    }
}
void sk_midi_port_init_tx(SkMidiUartOutPinDef_T &dOut){
    timer t;
    int time;
    if (dOut.mEnabledOut){

    }
    configure_out_port_no_ready(dOut.mPortOut, SkMidiClk, 1);

    dOut.mPortOut <: 0x80; //Send one to DFF
    t:>time;
    t when timerafter(time+1000) :> time;
    dOut.mPortOut <: 0xc0;  //Latch one into DFF to disable SPI but enable ports
    dOut.mLo|=0x40;
    dOut.mHi|=0x40;

}

void sk_midi_port_tx(SkMidiUartOutPinDef_T &dOut, streaming chanend cIn){
    int t;
    unsigned char b;
    unsigned char vLo=dOut.mLo;
    unsigned char vHi=dOut.mHi;

    int clocks=dOut.mClkDiv;
    while (1) {
        cIn :> b;
        if (dOut.mEnabledOut){
            dOut.mPortOut <: vLo @ t;
            t += clocks;
//#pragma loop unroll(8)
            for(int i = 0; i < 8; i++) {
                unsigned char v=(b&1)?vHi:vLo;
                dOut.mPortOut @ t <: v;
                b>>=1;
                t += clocks;
            }
            dOut.mPortOut @ t <: vHi;
            t += clocks;
            dOut.mPortOut @ t <: vHi;
        }
    }
}

void sk_midi_port_rx(SkMidiUartInPinDef_T &dIn, streaming chanend cOut){
    int clocks= dIn.mClkDiv;
    int dt2 = (clocks * 3)>>1;
    int dt = clocks;
    int t;
    unsigned int data = 0;
    while (1) {
        if (dIn.mEnabledIn){
            dIn.mPortIn when pinseq(0) :> int _ @ t;
            t += dt2;
//#pragma loop unroll(8)
            for(int i = 0; i < 8; i++) {
                dIn.mPortIn  @ t :> >> data;
                t += dt;
            }
            data >>= 24;
            cOut <: (unsigned char) data;
            dIn.mPortIn  @ t :> int _;
            data = 0;
        }
    }
}

int midiReadRawMore(streaming chanend cIn, unsigned char firstByte, MidiRawPacket_T&packet){
    int ret=0;
    packet.mLen=1;
    packet.data.byte[0]=firstByte;
    if (!(firstByte& 0x80)) return 0;//This is not a midi frame start.
    switch (GETCMD(packet)){
    case CM_NoteOff: //8x Note off
    case CM_NoteOn: //9x Note on
    case CM_KeyAfter: //ax Key Aftertouch
    case CM_CC: //bx Control Change
    case CM_Pitch: //ex Pitch wheel change
        cIn:> packet.data.byte[1];
        cIn:> packet.data.byte[2];
        packet.mLen=3;
        ret= 2;
        break;
    case CM_PC: //cx Program (patch) change
    case CM_ChanAfter: //dx Channel Aftertouch change
        cIn:> packet.data.byte[1];
        packet.data.byte[2]=0;
        packet.mLen=2;
        ret= 1;
        break;
    }
    return ret;
}
void midiReadInternal(streaming chanend cIn, unsigned char len, MidiRawPacket_T&packet){
    packet.mLen=len;
    for (int i=0; i<len; i++){
        cIn:> packet.data.byte[i];
    }
}
void midiReadInternalSendRaw(streaming chanend cIn, unsigned char len, MidiRawPacket_T&packet, streaming chanend cOut){
    packet.mLen=len;
    for (int i=0; i<len; i++){
        unsigned data;
        cIn:> data;
        cOut<: data; //BUGBUG: wrong sync for cIn ???!!!
        packet.data.byte[i]=data;
    }
}
void midiSendRaw(MidiRawPacket_T& packet, streaming chanend cOut){
    if (packet.mLen<2) return;
    if (packet.mLen>3) return;
    for (int i=0; i<packet.mLen; i++){
        cOut<: packet.data.byte[i];
    }
}
void midiSendInternal(MidiRawPacket_T& packet, streaming chanend cOut){
    if (packet.mLen<2) return;
    if (packet.mLen>3) return;
    cOut<: packet.mLen;
    for (int i=0; i<packet.mLen; i++){
        cOut<: packet.data.byte[i];
    }
}
