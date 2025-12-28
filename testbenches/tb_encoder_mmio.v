`timescale 1ns/1ps

module tb_encoder_mmio;

    reg clk;
    reg reset;

    // bus signals
    reg [31:0] bus_addr;
    reg        bus_we;
    reg        bus_re;
    reg [31:0] bus_wdata;
    wire [31:0] bus_rdata;

    // encoder signals
    reg enc_a;
    reg enc_b;

    
    encoder_mmio dut (
        .clk(clk),
        .reset(reset),
        .bus_addr(bus_addr),
        .bus_we(bus_we),
        .bus_re(bus_re),
        .bus_wdata(bus_wdata),
        .bus_rdata(bus_rdata),
        .enc_a(enc_a),
        .enc_b(enc_b)
    );

    // 100 MHz (10 ns )
    always #5 clk = ~clk;

    initial begin
        $dumpfile("sims/encoder_mmio_wave.vcd");
        $dumpvars(0, tb_encoder_mmio);

        // Initialize signals
        clk = 0;
        reset = 1;
        bus_addr = 0;
        bus_we = 0;
        bus_re = 0;
        bus_wdata = 0;
        enc_a = 0;
        enc_b = 0;

        // Release reset
        #20;
        reset = 0;
        #10;

        // Test 1: Read STATUS register (should be 0 initially)
        bus_re = 1'b1; //set what we want to read
        bus_addr = 32'h04;
        
        @(posedge clk);  // Wait for clock edge
        @(posedge clk); 
        $display("STATUS = 0x%h (expected 0x0)", bus_rdata);
        
        bus_re = 1'b0; //clear
        bus_addr = 32'h00; 
        #10;


        // Test 2: Read POSITION register (should be 0 initially)
        bus_re = 1'b1; //set what we want to read
        bus_addr = 32'h08;
        
        @(posedge clk);  // Wait for clock edge
        @(posedge clk); 
        $display("STATUS = 0x%h (expected 0x0)", bus_rdata);
        
        bus_re = 1'b0; //clear
        bus_addr = 32'h00; 
        #10;

        // Test 3: Write to CTRL register to enable encoder
        bus_we = 1'b1;
        bus_addr = 32'h00;
        bus_wdata = {30'b0, 1'b0, 1'b1}; // CLR=0, ENABLE=1
        @(posedge clk); // Register the write
        @(posedge clk);
        bus_we = 1'b0;  // Clear write signal
        bus_wdata = 32'h0;
        @(posedge clk); // Let enable propagate
        #10;


        // Test 4: Generate forward encoder movement
        repeat(5) begin
        {enc_a, enc_b} = 2'b01;
        #1;@(posedge clk);
        {enc_a, enc_b} = 2'b11;
        #1;@(posedge clk);
        {enc_a, enc_b} = 2'b10;
        #1;@(posedge clk);
        {enc_a, enc_b} = 2'b00;
        #1;@(posedge clk);
        end
        // Wait for synchronizer pipeline to flush
        @(posedge clk);
        @(posedge clk);

        // Test 5: Read POSITION register (should be positive)
        bus_re = 1'b1;
        bus_addr = 32'h08;

        @(posedge clk);  // Wait for clock edge
        @(posedge clk);
        $display("POSITION = 0x%h (expected 00000014)", bus_rdata);

        //Test 6: Read Direction
        bus_re = 1'b1;
        bus_addr = 32'h04;
        @(posedge clk);  // Wait for clock edge
        @(posedge clk);
        $display("DIRECTION = 0x%h (expected 0x1)", bus_rdata);


        // Test 7: backward encoder movement
        repeat(2) begin
        {enc_a, enc_b} = 2'b10;
        #1;@(posedge clk);
        {enc_a, enc_b} = 2'b11;
        #1;@(posedge clk);
        {enc_a, enc_b} = 2'b01;
        #1;@(posedge clk);
        {enc_a, enc_b} = 2'b00;
        #1;@(posedge clk);
        end
        // Wait for synchronizer pipeline to flush
        @(posedge clk);
        @(posedge clk);

        // Test 8: Read POSITION register (should be 12 decimal)
        bus_re = 1'b1;
        bus_addr = 32'h08;

        @(posedge clk);  // Wait for clock edge
        @(posedge clk);
        $display("POSITION = 0x%h (expected 0000000C)", bus_rdata);

        // Test 9: Read STATUS/direction register (should show backward = 0)
        bus_re = 1'b1;
        bus_addr = 32'h04;
        @(posedge clk);  // Wait for clock edge
        @(posedge clk);
        $display("DIRECTION = 0x%h (expected 0x0)", bus_rdata);

        // Test 10: Write to CTRL to clear position
        bus_we = 1'b1;
        bus_addr = 32'h00;
        bus_wdata = {30'b0, 1'b1, 1'b1}; // clr_pos = 1, enable = 1
        @(posedge clk); // Register the write
        @(posedge clk);
      
        // Test 11: Read POSITION register (should be 0 after clear)
        bus_re = 1'b1;
        bus_addr = 32'h08;
        @(posedge clk);  // Wait for clock edge
        @(posedge clk);
        $display("POSITION = 0x%h (expected 00000000)", bus_rdata);


        // Test 12: Disable encoder
        bus_we = 1'b1;
        bus_addr = 32'h00;
        bus_wdata = {30'b0, 1'b0, 1'b0}; // clr_pos = 0, enable = 0
        @(posedge clk); // Register the write
        @(posedge clk); 

        // Test 13: Generate movement while disabled (position shouldn't change)
        repeat(5) begin
        {enc_a, enc_b} = 2'b01;
        #1;@(posedge clk);
        {enc_a, enc_b} = 2'b11;
        #1;@(posedge clk);
        {enc_a, enc_b} = 2'b10;
        #1;@(posedge clk);
        {enc_a, enc_b} = 2'b00;
        #1;@(posedge clk);
        end
        // Wait for synchronizer pipeline to flush
        @(posedge clk);
        @(posedge clk);

        // Test 14: Read POSITION register (should still be 0)
        bus_re = 1'b1;
        bus_addr = 32'h08;
        @(posedge clk);  // Wait for clock edge
        @(posedge clk);
        $display("POSITION = 0x%h (expected 00000000)", bus_rdata);


        // End simulation
        #20;
        $finish;
    end

endmodule
