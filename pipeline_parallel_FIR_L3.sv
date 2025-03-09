module pipeline_parallel_FIR_L3 #(
    parameter TAPS       = 100, 
    parameter DATA_WIDTH = 16,   
    parameter COEF_WIDTH = 16,   
    parameter ACC_WIDTH  = 40    
)(
    input  logic                             clk,
    input  logic                             rst,  

    input  logic signed [DATA_WIDTH-1:0]     x0,
    input  logic signed [DATA_WIDTH-1:0]     x1,
    input  logic signed [DATA_WIDTH-1:0]     x2,

    input  logic signed [COEF_WIDTH-1:0]     coef [0:TAPS-1],

    output logic signed [DATA_WIDTH-1:0]     y0,
    output logic signed [DATA_WIDTH-1:0]     y1,
    output logic signed [DATA_WIDTH-1:0]     y2
);

    localparam SHIFT_LEN = TAPS + 2;
    logic signed [DATA_WIDTH-1:0] shift_reg [0:SHIFT_LEN-1];
    integer i;

    always_ff @(posedge clk) begin
        if (rst) begin
            for (i = 0; i < SHIFT_LEN; i++) begin
                shift_reg[i] <= '0;
            end
        end
        else begin
            shift_reg[0] <= x2;
            shift_reg[1] <= x1;
            shift_reg[2] <= x0;

            for (i = 3; i < SHIFT_LEN; i++) begin
                shift_reg[i] <= shift_reg[i-3];
            end
        end
    end

    logic signed [DATA_WIDTH+COEF_WIDTH-1:0] mult0 [0:TAPS-1];
    logic signed [DATA_WIDTH+COEF_WIDTH-1:0] mult1 [0:TAPS-1];
    logic signed [DATA_WIDTH+COEF_WIDTH-1:0] mult2 [0:TAPS-1];

    genvar gv;
    generate
        for (gv = 0; gv < TAPS; gv++) begin : multiply_stage
            always_ff @(posedge clk) begin
                if (rst) begin
                    mult0[gv] <= '0;
                    mult1[gv] <= '0;
                    mult2[gv] <= '0;
                end
                else begin
                    mult0[gv] <= shift_reg[gv]   * coef[gv];
                    mult1[gv] <= shift_reg[gv+1] * coef[gv];
                    mult2[gv] <= shift_reg[gv+2] * coef[gv];
                end
            end
        end
    endgenerate

    logic signed [ACC_WIDTH-1:0] accum0 [0:TAPS-1];
    logic signed [ACC_WIDTH-1:0] accum1 [0:TAPS-1];
    logic signed [ACC_WIDTH-1:0] accum2 [0:TAPS-1];

    always_ff @(posedge clk) begin
        if (rst) begin
            accum0[0] <= '0;
            accum1[0] <= '0;
            accum2[0] <= '0;
        end
        else begin
            accum0[0] <= mult0[0];
            accum1[0] <= mult1[0];
            accum2[0] <= mult2[0];
        end
    end

    generate
        for (gv = 1; gv < TAPS; gv++) begin : accum_stage
            always_ff @(posedge clk) begin
                if (rst) begin
                    accum0[gv] <= '0;
                    accum1[gv] <= '0;
                    accum2[gv] <= '0;
                end
                else begin
                    accum0[gv] <= accum0[gv-1] + mult0[gv];
                    accum1[gv] <= accum1[gv-1] + mult1[gv];
                    accum2[gv] <= accum2[gv-1] + mult2[gv];
                end
            end
        end
    endgenerate

    logic signed [ACC_WIDTH-1:0] scaled0, scaled1, scaled2;
    logic signed [DATA_WIDTH-1:0] sat0, sat1, sat2;

    localparam logic signed [DATA_WIDTH-1:0] MAX_Q15 = 16'sh7FFF;
    localparam logic signed [DATA_WIDTH-1:0] MIN_Q15 = 16'sh8000;

    always_comb begin

        scaled0 = accum0[TAPS-1] + (1 <<< 14);
        scaled1 = accum1[TAPS-1] + (1 <<< 14);
        scaled2 = accum2[TAPS-1] + (1 <<< 14);

        scaled0 = scaled0 >>> 15;
        scaled1 = scaled1 >>> 15;
        scaled2 = scaled2 >>> 15;

        if (scaled0 > MAX_Q15) begin
            sat0 = MAX_Q15;
        end
        else if (scaled0 < MIN_Q15) begin
            sat0 = MIN_Q15;
        end
        else begin
            sat0 = scaled0[DATA_WIDTH-1:0];
        end

        // y1
        if (scaled1 > MAX_Q15) begin
            sat1 = MAX_Q15;
        end
        else if (scaled1 < MIN_Q15) begin
            sat1 = MIN_Q15;
        end
        else begin
            sat1 = scaled1[DATA_WIDTH-1:0];
        end

        // y2
        if (scaled2 > MAX_Q15) begin
            sat2 = MAX_Q15;
        end
        else if (scaled2 < MIN_Q15) begin
            sat2 = MIN_Q15;
        end
        else begin
            sat2 = scaled2[DATA_WIDTH-1:0];
        end
    end

    always_ff @(posedge clk) begin
        if (rst) begin
            y0 <= '0;
            y1 <= '0;
            y2 <= '0;
        end
        else begin
            y0 <= sat0;
            y1 <= sat1;
            y2 <= sat2;
        end
    end

endmodule
