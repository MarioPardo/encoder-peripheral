//Simple AXI4-Lite wrapper for the encoder peripheral
//this acts as the slave in axi communications

//I take the convention of output signals and paremeters being CAPITAL
// and internal signals being lowercase. 
// this convention was taken from "FPGAs for Beginners" by on Youtube

module encoder_axi(
    input  wire        aclk,
    input  wire        aresetn,

    input  wire        enc_a,
    input  wire        enc_b,

    //Write Address Channel
    input  wire [31:0] aw_addr, //address master wants to write to
    input  wire        aw_valid, //"I have a valid write address", from master
    output reg         AW_READY, //"I can accept write address", from slave

    //Write Data Channel
    input  wire [31:0] w_data, //data from master to write
    input  wire [3:0]  w_strb, //which byte lanes are valid (1=valid, 0=ignore)
    input  wire        w_valid, //"I have valid write data", from master
    output reg         W_READY, //"I can accept write data", from slave

    // Write Response Channel
    output reg  [1:0]  B_RESP, //write response (00=OKAY, 10=SLVERR)
        // 2'b00 = OKAY , 2'b01 = EXOKAY: exclusive access okay 
        // 2'b10 = SLVERR:slave error", 2'b11 = DECERR - decode error
    output reg         B_VALID, //"I have a write response", from slave
    input  wire        b_ready, //"I can accept write response", from master

    // Read Address Channel
    input  wire [31:0] ar_addr, //address master wants to read from
    input  wire        ar_valid, //"I have a valid read address", from master
    output reg         AR_READY, //"I can accept read address", from slave

    // Read Data Channel
    output reg  [31:0] R_DATA, //data from slave to master
    output reg  [1:0]  R_RESP, //read response (00=OKAY, 10=SLVERR)
    output reg         R_VALID, //"I have valid read data", from slave
    input  wire        r_ready //"I can accept read data", from master
);

    // AXI Response Codes
    localparam [1:0] RESP_OKAY   = 2'b00;  // Successful transaction
    localparam [1:0] RESP_EXOKAY = 2'b01;  // Exclusive access okay (not used in AXI4-Lite)
    localparam [1:0] RESP_SLVERR = 2'b10;  // Slave error (invalid address, etc.)
    localparam [1:0] RESP_DECERR = 2'b11;  // Decode error (not typically used)

    // Internal signals to connect to encoder_mmio
    wire [31:0] bus_addr;  // Driven by mux
    reg        bus_we;
    reg        bus_re;
    reg [31:0] bus_wdata;
    wire [31:0] bus_rdata;
    
    // Internal address signals from FSMs
    reg [31:0] w_bus_addr;  // Write FSM's address
    reg [31:0] r_bus_addr;  // Read FSM's address
    
    // Combinational mux for bus_addr based on active operation
    assign bus_addr = bus_we ? w_bus_addr : 
                      bus_re ? r_bus_addr : 
                      32'h0;

   
    // Instantiate encoder_mmio
    encoder_mmio mmio_inst (
        .clk(aclk),
        .reset(~aresetn),  // AXI uses active-low reset, convert to active-high
        .bus_addr(bus_addr),
        .bus_we(bus_we),
        .bus_re(bus_re),
        .bus_wdata(bus_wdata),
        .bus_rdata(bus_rdata),
        .enc_a(enc_a),
        .enc_b(enc_b)
    );


                             /////Write FSM /////
        //states
    localparam [1:0] w_s_idle     = 2'b00;
    localparam [1:0] w_s_write    = 2'b01;
    localparam [1:0] w_s_response = 2'b10;

        //signals
    reg [1:0] write_state;
    reg [1:0] write_state_next;
    reg [31:0] w_addr_latched;  // Captured write address
    reg [31:0] w_data_latched;  // Captured write data

    // Busy flags for arbitration
    wire write_busy;
    wire read_busy;

    assign write_busy = (write_state != w_s_idle);
    assign read_busy = (read_state != r_s_idle);


    // State register (sequential logic)
    always @(posedge aclk) begin
         if (~aresetn)
             write_state <= w_s_idle;
         else
             write_state <= write_state_next;
    end

    // Next state logic (combinational)
    always @(*) begin
         write_state_next = write_state;  // Default: stay in current state
         
         case (write_state)
             w_s_idle: begin
                 if (aw_valid && w_valid && ~read_busy)
                    write_state_next = w_s_write;
             end
         
             w_s_write: begin
                 // Spend one cycle writing to bus
                 write_state_next = w_s_response;
             end
             
             w_s_response: begin
                 if (b_ready)  // Master accepted response
                write_state_next = w_s_idle;
             end
         
                 default: write_state_next = w_s_idle;
         endcase
     end

    // Output logic 
    always @(posedge aclk) begin
        if (~aresetn) begin
            AW_READY <= 1'b0;
            W_READY <= 1'b0;
            B_VALID <= 1'b0;
            B_RESP <= RESP_OKAY;
            bus_we <= 1'b0;
            w_addr_latched <= 32'h0;
            w_data_latched <= 32'h0;
            w_bus_addr <= 32'h0;
        end 
        else begin
            // Default values
            AW_READY <= 1'b0;
            W_READY <= 1'b0;
            bus_we <= 1'b0;
            
            case (write_state)
                w_s_idle: begin
                    if (aw_valid && w_valid) begin
                        // save address and data
                        w_addr_latched <= aw_addr;
                        w_data_latched <= w_data;
                        // send acknowledgement to master
                        AW_READY <= 1'b1;
                        W_READY <= 1'b1;
                    end
                    B_VALID <= 1'b0;  // to be safe
                end
                
                w_s_write: begin
                    // Drive bus signals for one cycle
                    w_bus_addr <= w_addr_latched;
                    bus_wdata <= w_data_latched;
                    bus_we <= 1'b1;
                    
                    // only CTRL register at 0x00 is writable
                    if (w_addr_latched[7:0] == 8'h00)
                        B_RESP <= RESP_OKAY;
                    else
                        B_RESP <= RESP_SLVERR;
                end
                
                w_s_response: begin
                    // Assert response valid
                    B_VALID <= 1'b1;
                
                end
            endcase
        end
    end
    

                            //////Read FSM/////

        //states
    localparam [1:0] r_s_idle  = 2'b00;
    localparam [1:0] r_s_issue_read = 2'b01;
    localparam [1:0] r_s_wait_data  = 2'b10;
    localparam [1:0] r_s_resp  = 2'b11;

        //signals
    reg [1:0] read_state;
    reg [1:0] read_state_next;
    reg [31:0] r_addr_latched;  // Captured read address
    reg [31:0] r_data_latched;  // Captured read data

    // State register (sequential logic)
    always @(posedge aclk) begin
            if (~aresetn)
                read_state <= r_s_idle;
            else
                read_state <= read_state_next;
        end

    // Next state logic (combinational)
    always @(*) begin
            read_state_next = read_state;  // Default: stay in current state
            case (read_state)
                r_s_idle: begin
                    if (ar_valid && ~write_busy)
                        read_state_next = r_s_issue_read;
                end

                r_s_issue_read: begin
                    read_state_next = r_s_wait_data;
                end

                r_s_wait_data: begin
                    // Wait one more cycle for bus_rdata to be valid
                    read_state_next = r_s_resp;
                end

                r_s_resp: begin
                    if (r_ready)  // Master accepted read data
                        read_state_next = r_s_idle;
                end

                default: read_state_next = r_s_idle;
    
            endcase
    end

    // Output logic
    always @(posedge aclk) begin
        if (~aresetn) begin
            AR_READY <= 1'b0;
            R_VALID <= 1'b0;
            R_DATA <= 32'h0;
            R_RESP <= RESP_OKAY;
            bus_re <= 1'b0;
            r_addr_latched <= 32'h0;
            r_data_latched <= 32'h0;
            r_bus_addr <= 32'h0;
        end 
        else begin
            // Defaults
            AR_READY <= 1'b0;
            bus_re <= 1'b0;
            case (read_state)
                r_s_idle: begin
                    if (ar_valid && ~write_busy) begin
                        r_addr_latched <= ar_addr;
                        AR_READY <= 1'b1;
                    end
                    R_VALID <= 1'b0;
                end

                r_s_issue_read: begin
                    r_bus_addr <= r_addr_latched;
                    bus_re <= 1'b1;
                
                    // All registers are readable
                    if ( (r_addr_latched[7:0] == 8'h00) ||
                         (r_addr_latched[7:0] == 8'h04) || 
                         (r_addr_latched[7:0] == 8'h08) || 
                         (r_addr_latched[7:0] == 8'h0C) )
                        R_RESP <= RESP_OKAY;
                    else
                        R_RESP <= RESP_SLVERR;
                end

                r_s_wait_data: begin
                    // Don't latch yet, bus_rdata updates at end of this cycle
                end

                r_s_resp: begin
                    r_data_latched <= bus_rdata;
                    R_DATA <= bus_rdata;
                    R_VALID <= 1'b1;
                end
            endcase
        end
    end 



endmodule