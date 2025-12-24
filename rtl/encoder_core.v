module encoder_core #(
    parameter integer WINDOW_CYCLES = 100_000_000) //represents 1second at 100MHz clock
  (
    input  wire        clk,
    input  wire        reset,   
    input  wire        clr_pos,
    input  wire        enable,
    input  wire        enc_a,
    input  wire        enc_b,

    output reg  signed [31:0] position,
    output reg signed [31:0] velocity,
    output reg               direction
);

// Internal signals
reg signed [1:0] step;
reg [1:0] ab_prev;
reg [1:0] ab_curr;

reg [31:0] window_ctr;
reg signed [31:0] position_prev_window;




// Combinatorial Logic to determine step
always @(*) begin
    step = 0;
    case ({ab_prev, ab_curr})
        4'b0001: step = 1;
        4'b0111: step = 1;
        4'b1110: step = 1;
        4'b1000: step = 1;
        4'b0010: step = -1;
        4'b1011: step = -1;
        4'b1101: step = -1;
        4'b0100: step = -1;
        default: step = 0;
    endcase
end

// Clocked logic: sample encoder state and velocity window
always @(posedge clk) begin
    if (reset) begin
        ab_prev <= 2'b00;
        ab_curr <= 2'b00;

        window_ctr           <= 0;
        position_prev_window <= 0;
        velocity             <= 0;
    end 
    
    else begin   
        ab_prev <= ab_curr;
        ab_curr <= {enc_a, enc_b};

        // velocity
        if (enable) begin
            if (window_ctr == WINDOW_CYCLES-1) begin
                velocity <= position - position_prev_window;
                position_prev_window <= position;
                window_ctr <= 0;
            end 
            else begin
                window_ctr <= window_ctr + 1;
            end
        end
        // do not update velocity if not enabled
    end
end


// Clocked logic to update registers
always @(posedge clk) begin
    if (reset) begin
        position  <= 0;
        direction <= 0;
    end 
    else if (clr_pos) begin
        position  <= 0;
        direction <= 0;
        velocity  <= 0;
        window_ctr <=0;
    end
    else if (enable) begin
        position  <= position + step;
        if (step == 1)
            direction <= 1'b1;
        else if (step == -1)
            direction <= 1'b0;

    end
end





endmodule