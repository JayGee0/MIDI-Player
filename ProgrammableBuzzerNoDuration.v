/*----------------------------------------------------------------------------*/
/*                        Programmable buzzer                                 */
/*                         8 bit note definition, 1 bit enable                */
/*                        [3:0]  - Note
/*                        [7:4]  - Ocave
/*                        [15]   - Enable
/*                                                                            */
/*                                J.U. Georgis                                */
/*                                 May 2024                                   */
/*----------------------------------------------------------------------------*/

`timescale 100ns/1ns
`define NOTE 3:0
`define OCTAVE 7:4
`define ENABLE 15

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


module ProgrammableBuzzerNoDuration (
    input  wire        clk,                 /* Clock                            */
    input  wire[7:0]   buzzer_input,        /* Data input (whole port)          */
    input  wire        enable,              /* Data input (whole port)          */
    input  wire        bus_address_i,       /* Bus addresses                    */
    output wire[7:0]   buzzer_data_out,     /* Data-out for buzzer              */
    output wire[7:0]   bus_data_out         /* Data-out to display              */
  );

  reg [3:0]   note;
  reg [3:0]   octave;
  reg [15:0]  divider;
  wire clk_note_master;


  initial
  begin
    note     <= 4'h0;
    octave   <= 4'h0;
  end

  // Frequency of 1_000_000Hz
  clk_div note_master_driver (
            .clk(clk),
            .clk_1(clk_note_master)
          );

  // Drives the buzzer output bzz bzz
  Divider buzzer_driver (
            .clk_i(clk_note_master),
            .en_i(enable),
            .count_i(divider),
            .freq_o(buzzer_data_out[0])
          );

  assign buzzer_data_out[7:2] = 7'b1;
  assign buzzer_data_out[1] = ~buzzer_data_out[0];
  assign bus_data_out = (bus_address_i)? {7'b0000_000, enable} : {octave, note};

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


    divider = FrequencyConverter(note, octave);

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