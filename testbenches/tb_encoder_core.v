`timescale 1ns/1ps

module tb_encoder_core;

    reg clk;
    reg reset;
    reg enable;
    reg enc_a;
    reg enc_b;

    wire signed [31:0] position;
    wire direction;

    encoder_core dut (
        .clk(clk),
        .reset(reset),
        .enable(enable),
        .enc_a(enc_a),
        .enc_b(enc_b),
        .position(position),
        .direction(direction)
    );

    // 100 MHz (10 ns )
    always #5 clk = ~clk;

    initial begin
        $dumpfile("sims/encoder_wave.vcd");
        $dumpvars(0, tb_encoder_core);

        // Initialize
        clk     = 0;
        reset   = 1;
        enable  = 0;
        enc_a   = 0;
        enc_b   = 0;

        // Hold reset
        #20;
        reset  = 0;
        enable = 1;

        // Forward sequence: 00 → 01 → 11 → 10 → 00
        #10 {enc_a, enc_b} = 2'b01;
        #10 {enc_a, enc_b} = 2'b11;
        #10 {enc_a, enc_b} = 2'b10;
        #10 {enc_a, enc_b} = 2'b00;

        // Stop simulation
        #20;
        $finish;
    end

endmodule
