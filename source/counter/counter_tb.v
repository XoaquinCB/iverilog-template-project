`timescale 1ns/1ns
`include "counter.v"

module counter_tb;

  reg reset = 0;
  reg clk = 0;
  wire [7:0] value;
  counter c1 (value, clk, reset);

  initial begin
     $dumpfile(`DUMP_FILE);
     $dumpvars();

     $monitor("At time %t, value = %h (%0d)", $time, value, value);

     #17 reset = 1;
     #11 reset = 0;
     #29 reset = 1;
     #11 reset = 0;
     #100;

    $finish();
  end

  always begin
    #5 clk = !clk;
  end

endmodule // counter_tb
