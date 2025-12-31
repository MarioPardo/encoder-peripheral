`timescale 1ns/1ps

module tb_encoder_axi;

    // Clock and reset
    reg aclk;
    reg aresetn;

    // AXI Write Address Channel
    reg [31:0] aw_addr;
    reg        aw_valid;
    wire       aw_ready;

    // AXI Write Data Channel
    reg [31:0] w_data;
    reg [3:0]  w_strb;
    reg        w_valid;
    wire       w_ready;

    // AXI Write Response Channel
    wire [1:0] b_resp;
    wire       b_valid;
    reg        b_ready;

    // AXI Read Address Channel
    reg [31:0] ar_addr;
    reg        ar_valid;
    wire       ar_ready;

    // AXI Read Data Channel
    wire [31:0] r_data;
    wire [1:0]  r_resp;
    wire        r_valid;
    reg         r_ready;

    // Encoder signals
    reg enc_a;
    reg enc_b;

    // Instantiate DUT
    encoder_axi dut (
        .s_axi_aclk(aclk),
        .s_axi_aresetn(aresetn),
        .aw_addr(aw_addr),
        .aw_valid(aw_valid),
        .AW_READY(aw_ready),
        .w_data(w_data),
        .w_strb(w_strb),
        .w_valid(w_valid),
        .W_READY(w_ready),
        .B_RESP(b_resp),
        .B_VALID(b_valid),
        .b_ready(b_ready),
        .ar_addr(ar_addr),
        .ar_valid(ar_valid),
        .AR_READY(ar_ready),
        .R_DATA(r_data),
        .R_RESP(r_resp),
        .R_VALID(r_valid),
        .r_ready(r_ready),
        .enc_a(enc_a),
        .enc_b(enc_b)
    );

    // 100 MHz clock (10 ns period)
    always #5 aclk = ~aclk;

    // AXI Task: Write transaction
    task axi_write;
        input [31:0] addr;
        input [31:0] data;
        begin
            @(posedge aclk);
            #1;
            aw_addr = addr;
            aw_valid = 1'b1;
            w_data = data;
            w_strb = 4'b1111;
            w_valid = 1'b1;
            
            // Wait for address and data acceptance
            wait(aw_ready && w_ready);
            @(posedge aclk);
            #1;
            aw_valid = 1'b0;
            w_valid = 1'b0;
            
            // Wait for write response
            b_ready = 1'b1;
            wait(b_valid);
            @(posedge aclk);
            #1;
            b_ready = 1'b0;
            
            $display("AXI WRITE: addr=0x%h, data=0x%h, resp=%s", 
                     addr, data, (b_resp == 2'b00) ? "OKAY" : "SLVERR");
        end
    endtask

    // AXI Task: Read transaction
    task axi_read;
    input [31:0] addr;
    reg [31:0] data_captured;
    reg [1:0]  resp_captured;
    begin
        // Drive AR
        @(posedge aclk);
        #1;
        ar_addr  = addr;
        ar_valid = 1'b1;

        // Wait for AR handshake
        while (!(ar_valid && ar_ready)) @(posedge aclk);
        #1;
        ar_valid = 1'b0;

        // Be ready for R before it comes
        r_ready = 1'b1;

        // Wait for R handshake and sample on that clock edge
        while (!(r_valid && r_ready)) @(posedge aclk);
        data_captured = r_data;
        resp_captured = r_resp;

        // Drop RREADY next cycle (optional)
        @(posedge aclk);
        r_ready = 1'b0;

        $display("AXI READ: addr=0x%h, data=0x%h, resp=%s",
                 addr, data_captured, (resp_captured == 2'b00) ? "OKAY" : "SLVERR");
    end
endtask


    initial begin
        $dumpfile("sims/encoder_axi_wave.vcd");
        $dumpvars(0, tb_encoder_axi);

        // Initialize signals
        aclk = 0;
        aresetn = 0;
        aw_addr = 0;
        aw_valid = 0;
        w_data = 0;
        w_strb = 0;
        w_valid = 0;
        b_ready = 0;
        ar_addr = 0;
        ar_valid = 0;
        r_ready = 0;
        enc_a = 0;
        enc_b = 0;

        // Hold reset
        #20;
        aresetn = 1;
        #20;

        @(posedge aclk);
        $display("\n=== Test 1: Read STATUS register (initial) ===");
        axi_read(32'h04);
        @(posedge aclk);

        $display("\n=== Test 2: Read POSITION register (initial) ===");
        axi_read(32'h08);
        @(posedge aclk);

        $display("\n=== Test 3: Read CTRL register (initial) ===");
        axi_read(32'h00);
        @(posedge aclk);

        $display("\n=== Test 4: Write to CTRL to enable encoder ===");
        axi_write(32'h00, 32'h00000001);  // Enable bit = 1
        @(posedge aclk);

        $display("\n=== Test 5: Read back CTRL register ===");
        axi_read(32'h00);
        @(posedge aclk);

        $display("\n=== Test 6: Generate forward encoder movement ===");
        repeat(5) begin
            @(posedge aclk); #1 {enc_a, enc_b} = 2'b01;
            @(posedge aclk); #1 {enc_a, enc_b} = 2'b11;
            @(posedge aclk); #1 {enc_a, enc_b} = 2'b10;
            @(posedge aclk); #1 {enc_a, enc_b} = 2'b00;
        end
        
        // Wait for synchronizer pipeline
        @(posedge aclk);
        @(posedge aclk);

        $display("\n=== Test 7: Read POSITION (should be 20 decimal) ===");
        axi_read(32'h08);
        @(posedge aclk);

        $display("\n=== Test 8: Read STATUS/direction (should be forward=1) ===");
        axi_read(32'h04);
        @(posedge aclk);

        $display("\n=== Test 9: Generate backward encoder movement ===");
        repeat(10) begin
            @(posedge aclk); #1 {enc_a, enc_b} = 2'b10;
            @(posedge aclk); #1 {enc_a, enc_b} = 2'b11;
            @(posedge aclk); #1 {enc_a, enc_b} = 2'b01;
            @(posedge aclk); #1 {enc_a, enc_b} = 2'b00;
        end
        
        @(posedge aclk);
        @(posedge aclk);

        $display("\n=== Test 10: Read POSITION (should be -20 decimal) ===");
        axi_read(32'h08);
        @(posedge aclk);

        $display("\n=== Test 11: Read STATUS/direction (should be backward=0) ===");
        axi_read(32'h04);
        @(posedge aclk);

        $display("\n=== Test 12: Write to clear position ===");
        axi_write(32'h00, 32'h00000003);  // CLR_POS=1, ENABLE=1
        @(posedge aclk);

        $display("\n=== Test 13: Read POSITION (should be 0 after clear) ===");
        axi_read(32'h08);
        @(posedge aclk);

        $display("\n=== Test 14: Try to write to read-only STATUS register (should get SLVERR) ===");
        axi_write(32'h04, 32'h04);
        @(posedge aclk);

        $display("\n=== Test 15: Try to read from invalid address (should get SLVERR) ===");
        axi_read(32'hFF);
        @(posedge aclk);

        $display("\n=== Test 17: ARBITRATION - Attempt simultaneous read and write ===");
        @(posedge aclk);
        #1;
        // Assert both read and write requests at the same time
        aw_addr = 32'h00;
        aw_valid = 1'b1;
        w_data = 32'h00000001;
        w_strb = 4'b1111;
        w_valid = 1'b1;
        
        ar_addr = 32'h08;
        ar_valid = 1'b1;
        
        $display("Simultaneous requests issued:");
        $display("  Write request: addr=0x00, data=0x00000001");
        $display("  Read request: addr=0x08");
        
        // Wait and see which one gets accepted first
        @(posedge aclk);
        if (aw_ready && w_ready && !ar_ready) begin
            $display("  -> Write accepted first, read waiting (CORRECT - arbitration working)");
        end else if (ar_ready && !(aw_ready && w_ready)) begin
            $display("  -> Read accepted first, write waiting (CORRECT - arbitration working)");
        end else if (aw_ready && w_ready && ar_ready) begin
            $display("  -> BOTH accepted simultaneously (ERROR - arbitration failed!)");
        end
        
        #1;
        aw_valid = 1'b0;
        w_valid = 1'b0;
        ar_valid = 1'b0;
        
        // Complete any pending transactions
        b_ready = 1'b1;
        r_ready = 1'b1;
        #100;
        b_ready = 1'b0;
        r_ready = 1'b0;

        $display("\n=== All tests complete ===");
        #100;
        $finish;
    end

endmodule
