/*
 * app_midi1_test.xc
 *
 *  Created on: 2015.05.28.
 *      Author: Barna
 */

#define SLOT_STAR 1
#define SLOT_TRIANGEL 2
#define SLOT_SQUARE 3
#define SLOT_CIRCLE 4
#define SLOT_STARTKIT 5

#define CARD_GPIO SLOT_STAR
#define CARD_AUDIO SLOT_TRIANGEL

#include <platform.h>
#include <xs1.h>
#include <midi.h>

#if (CARD_AUDIO == SLOT_TRIANGEL)
#define TILEAUDIO  on tile[0]:
TILEAUDIO SkMidiUartOutPinDef_T g_MidiUartOutPin={
        XS1_PORT_8D,0,(1<<7),1, //P8D7,P16B15 X0D43 triangle.
        3200                    //Midi Clk div
};
#elif (CARD_AUDIO == SLOT_CIRCLE)
#error MIDI OUT PORT UNAVAILABLE
#define TILEAUDIO on tile[1]:
TILEAUDIO SkMidiUartOutPinDef_T g_MidiUartOutPin={
        XS1_PORT_8D,0,(1<<7),0, //P8D7,P16B15 X0D43 triangle. tx unavailable on circle port :(
        3200                    //Midi Clk div
};
#endif


TILEAUDIO clock SkMidiClk = XS1_CLKBLK_REF;
TILEAUDIO out port g_ledOnAudioCard = XS1_PORT_4E; //P4E3
TILEAUDIO SkMidiUartInPinDef_T g_MidiUartInPin={
        XS1_PORT_1J,         1, //P1j0 X1D25 triangle, circle
        3200                    //Midi Clk div
};
void processInternal(streaming chanend c, unsigned short icmd){
    //MidiRawPacket_T packet;
    //SETCMD_CH(packet, cmd, channel);
    //packet.mLen=3;
    //packet.data.midi.v= velo;
    //packet.data.midi.n= note;
    //midiSendRaw(packet, c);
}
#define TIME_DIV 5000
void produce(streaming chanend c, streaming chanend cim, streaming chanend cip) {
    MidiRawPacket_T packet;
    unsigned char len=0;
    unsigned short icmd=0;
    char volume7=127;
    unsigned timeout;
    timer tmr;
    while(1){
        select{
            case cim :> len:
                { //MIDI Input handler
                    if ((len>=2)&(len<=3)){ //valid length?
                        midiReadInternal(cim, len, packet);
                        midiSendRaw(packet, c);
                        unsigned cmd=GETCMD(packet);
                        switch (cmd){
                            case  CM_NoteOn: //packet.data.midi.n, packet.data.midi.v
                            break;
                            case CM_CC: if (packet.data.midi.n == 7) volume7= packet.data.midi.v;
                            break;
                        }
                    }
                }
                break; //cim
            case cip :> icmd:
                { //other source (not a real midi input)
                    int id=icmd>>8;
                    processInternal(c, icmd); //this can send midi out too
                }
                break;
            case tmr when timerafter(timeout) :> timeout:
                {
                    timeout += TIME_DIV;
                    unsigned short dcmd=0xf00d;  //some internal cmd for noteoff / timeout;
                    processInternal(c, dcmd);   //this can send midi out too
                }
                break;

        }
    }
}
void consume( streaming chanend c, streaming chanend co) {
    MidiRawPacket_T packet;
    while(1){
        unsigned char d=0;
        do{
            c:> d;
        }while (!midiReadRawMore(c,d,packet)); //this will parse the packet because of the unknown length
        midiSendInternal(packet, co);
    }
}
void mainAudioIn(streaming chanend c_int){
    streaming chan c_min;
    sk_midi_port_init_rx(g_MidiUartInPin);
    par{
        sk_midi_port_rx(g_MidiUartInPin , c_min);
        consume(c_min, c_int);
    };
}
void mainAudioOut(streaming chanend c_intp, streaming chanend c_int){
    streaming chan  c_mout;
    sk_midi_port_init_tx(g_MidiUartOutPin);
    par{
        sk_midi_port_tx(g_MidiUartOutPin , c_mout);
        produce(c_mout, c_int, c_intp);
    };
}
void generateInternal(streaming chanend c_intp)
{
    int time;
    timer t;
    while(1){
        t:>time;
        //procSomething(time);
        //int noteid;
        //while (procNotesOn(time, noteid)) playInternalSound(c_intp, noteid, 255);
    }
}
int main(){
    streaming chan c_intp;
    streaming chan c_int;
    par {
        TILEAUDIO mainAudioIn(c_int);
        TILEAUDIO mainAudioOut(c_intp, c_int);
        TILEAUDIO generateInternal(c_intp);
    }
    return 0;
}
