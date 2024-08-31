/*----------------------------------------------------------------------------*/
/*                        Programmable buzzer inspired by one in STUMP board  */
/*                            16 bit input                                    */
/*                        [3:0]  - Note
/*                        [7:4]  - Ocave
/*                        [13:8] - Duration in terms of 1/8 of a second
/*                        [14]   - Play
/*                        [15]   - Buzzer in busy state
/*                                                                            */
/*                                J.U. Georgis                                */
/*                                 May 2024                                   */
/*----------------------------------------------------------------------------*/

`timescale 100ns/1ns
`define NOTE 3:0
`define OCTAVE 7:4
`define DURATION 11:8
`define PLAY 14
`define BUSY 15

`define IDLE_STATE 0
`define BUSY_STATE 1

`define C  4'b0000
`define CS 4'b0001
`define D  4'b0010
`define DS 4'b0011
`define E  4'b0100
`define F  4'b0101
`define FS 4'b0110
`define G  4'b0111
`define GS 4'b1000
`define A  4'b1001
`define AS 4'b1010
`define B  4'b1011


module ProgrammableBuzzer (
    input  wire        clk,                 /* Clock                            */
    input  wire[15:0]  buzzer_input,        /* Data input (whole port)          */
    input  wire        bus_address_i,       /* Bus addresses                    */
    output wire[7:0]   buzzer_data_out,     /* Data-out for buzzer              */
    output wire[7:0]   bus_data_out,        /* Data-out to display              */
    output reg         IRQ_o                /* Interrupt signal                 */
  );

  reg [3:0]   note;
  reg [3:0]   octave;
  reg [3:0]   duration;
  reg         state, next_state;
  reg         old_play, play;
  wire        play_pulse;
  wire        clk_note_master;

  reg [15:0] divider;           // Divider for the sound frequency
  reg [31:0] duration_counter;  // Signifier on when to switch state back to IDLE

  initial
  begin
    state    <= 0;
    next_state <= 0;
    note     <= 4'h0;
    octave   <= 4'h0;
    duration <= 6'h0;
    play     <= 0;
    IRQ_o    <= 0;
    duration_counter  <= 32'b0;
  end



  // Frequency of 1_000_000Hz
  clk_div note_master_driver (
            .clk(clk),
            .clk_1(clk_note_master)
          );

  // Drives the buzzer output bzz bzz
  Divider buzzer_driver (
            .clk_i(clk_note_master),
            .en_i(state),
            .count_i(divider),
            .freq_o(buzzer_data_out[0])
          );

  assign buzzer_data_out[7:2] = 7'b1;
  assign buzzer_data_out[1] = ~buzzer_data_out[0];    // Complement the 0th bit with the 1st one
  assign play_pulse = (old_play == 1 && play == 0);   // Negedge play
  assign bus_data_out = (bus_address_i)? {octave, note} : {state, play, 2'b00, duration};

  always @ (*)
  begin
    // Clamp notes from 0 - 11
    case (buzzer_input[`NOTE])
      4'b1100, 4'b1101, 4'b1110, 4'b1111:
        note = 4'b1011;
      default:
        note = buzzer_input[`NOTE];
    endcase

    octave = buzzer_input[`OCTAVE];

    // Duration between [0, 15/8]
    duration = buzzer_input[`DURATION];
    divider = FrequencyConverter(note, octave);


    // If negedge play, transition to busy
    if(play_pulse)
    begin
      next_state = `BUSY_STATE;
    end
    else if(state == `BUSY_STATE)
    begin
      // Once the duration has finished, return to IDLE and trigger interrupt
      if(duration_counter == 0)
      begin
        next_state = `IDLE_STATE;
        IRQ_o = 1;
      end
    end
  end


  always @ (posedge clk)
  begin
    state <= next_state;

    if(state == `IDLE_STATE)
      duration_counter <= duration * 6250000;   // 6_250_000 = 1/8 * 50MHz
    else
      duration_counter <= duration_counter - 1;

    play <= buzzer_input[`PLAY];
    old_play <= play;
  end



  // Converts note and octave to frequency divider
  function [15:0] FrequencyConverter; 		
    input [3:0] note;
    input [3:0] octave;


    reg [15:0] divider_t;
    begin
      // LUT for the divider of 1_000_000Hz to desired frequency at octave 0
      // Octave 0 chosen as accuracy more important for lower frequencies
      case (note)
        `C  :
          divider_t = 30581;
        `CS :
          divider_t = 28868;
        `D  :
          divider_t = 27248;
        `DS :
          divider_t = 25707;
        `E  :
          divider_t = 24272;
        `F  :
          divider_t = 22904;
        `FS :
          divider_t = 21626;
        `G  :
          divider_t = 20408;
        `GS :
          divider_t = 19260;
        `A  :
          divider_t = 18182;
        `AS :
          divider_t = 17159;
        `B  :
          divider_t = 16197;
      endcase

      if (octave == 0)
        divider_t = 1;  // If octave = 0, silence
      else
        divider_t = (divider_t >> octave); // Shift divider according to octave to play higher pitches


      FrequencyConverter = divider_t-1; // Divider = (1MHz / (2 * input)) - 1
    end
  endfunction


endmodule


