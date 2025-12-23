`timescale 1ns/1ps

module tb_encoder_core;

    reg clk;
    reg reset;
    reg enable;
    reg enc_a;
    reg enc_b;

    wire signed [31:0] position;
    wire signed [31:0] velocity;
    wire direction;

    encoder_core #(
        .WINDOW_CYCLES(10) // testing
    ) dut (
        .clk(clk),
        .reset(reset),
        .enable(enable),
        .enc_a(enc_a),
        .enc_b(enc_b),
        .position(position),
        .velocity(velocity),
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

        //forward movement 
        repeat(500) begin  
            #10 {enc_a, enc_b} = 2'b01;
            #10 {enc_a, enc_b} = 2'b11;
            #10 {enc_a, enc_b} = 2'b10;
            #10 {enc_a, enc_b} = 2'b00;
        end

        // backward movement (reverse quadrature sequence)
        repeat(250) begin 
            #10 {enc_a, enc_b} = 2'b10;
            #10 {enc_a, enc_b} = 2'b11;
            #10 {enc_a, enc_b} = 2'b01;
            #10 {enc_a, enc_b} = 2'b00;
        end

        // Stop sim
        #20;
        $finish;
    end

endmodule
