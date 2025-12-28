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

    // Internal signals to connect to encoder_mmio
    reg [31:0] bus_addr;
    reg        bus_we;
    reg        bus_re;
    reg [31:0] bus_wdata;
    wire [31:0] bus_rdata;

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


endmodule