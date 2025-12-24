module encoder_mmio (
    input  wire        clk,
    input  wire        reset,

    // MMIO bus
    input  wire [31:0] bus_addr,
    input  wire        bus_we,
    input  wire        bus_re,
    input  wire [31:0] bus_wdata,
    output reg  [31:0] bus_rdata,

    // Encoder pins
    input  wire        enc_a,
    input  wire        enc_b
);

    // Register offsets
    localparam [31:0] REG_CTRL     = 32'h00; //CLR,ENABLE
    localparam [31:0] REG_STATUS   = 32'h04;
    localparam [31:0] REG_POSITION = 32'h08;
    localparam [31:0] REG_VELOCITY = 32'h0C;

    // CTRL bits
    localparam integer CTRL_ENABLE  = 0;
    localparam integer CTRL_CLR_POS = 1;

    // Internal control regs
    reg enable_reg;
    reg clr_pos_pulse;

    // Encoder Core outputs
    wire signed [31:0] position;
    wire signed [31:0] velocity;
    wire direction;

    // Instantiate core
    encoder_core dut (
        .clk(clk),
        .reset(reset),
        .enable(enable_reg),
        .clr_pos(clr_pos_pulse),
        .enc_a(enc_a),
        .enc_b(enc_b),
        .position(position),
        .direction(direction),
        .velocity(velocity)
    );

    // Write logic (CTRL only)
    always @(posedge clk) begin
        if (reset) begin
            enable_reg   <= 1'b0;
            clr_pos_pulse <= 1'b0;
        end else begin
            // default: clr_pos is a 1-cycle pulse
            clr_pos_pulse <= 1'b0;

            if (bus_we) begin
                if (bus_addr[7:0] == REG_CTRL[7:0]) begin
                    enable_reg <= bus_wdata[CTRL_ENABLE];
                    if (bus_wdata[CTRL_CLR_POS])
                        clr_pos_pulse <= 1'b1;
                end
            end
        end
    end

    // Read logic 
    always @(posedge clk) begin
        if (reset) begin
            bus_rdata <= 32'h0;
        end else if (bus_re) begin
            case (bus_addr[7:0])
                REG_CTRL[7:0]: begin
                    bus_rdata <= {30'b0, 1'b0 , enable_reg}; //CLR_POS is write-only
                end
                REG_STATUS[7:0]: begin
                    bus_rdata <= {31'b0, direction};
                end
                REG_POSITION[7:0]: begin
                    bus_rdata <= position;
                end
                REG_VELOCITY[7:0]: begin
                    bus_rdata <= velocity;
                end
                default: begin
                    bus_rdata <= 32'h0;
                end
            endcase
        end
    end

endmodule
