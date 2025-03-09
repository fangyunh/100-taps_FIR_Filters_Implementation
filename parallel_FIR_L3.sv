module parallel_FIR_L3 #(
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

    integer i, j;

    always_ff @(posedge clk) begin
        if (rst) begin
            for (j = 0; j < SHIFT_LEN; j++) begin
                shift_reg[j] <= '0;
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

    logic signed [ACC_WIDTH-1:0] sum0;
    logic signed [ACC_WIDTH-1:0] sum1;
    logic signed [ACC_WIDTH-1:0] sum2;

    always_comb begin
        sum0 = '0;
        sum1 = '0;
        sum2 = '0;
        for (int k = 0; k < TAPS; k++) begin
            logic signed [DATA_WIDTH+COEF_WIDTH-1:0] prod0, prod1, prod2;
            prod0 = shift_reg[k]   * coef[k];   
            prod1 = shift_reg[k+1] * coef[k];
            prod2 = shift_reg[k+2] * coef[k];    

            sum0 += prod0;
            sum1 += prod1;
            sum2 += prod2;
        end
    end

    logic signed [ACC_WIDTH-1:0] sum0_scaled, sum1_scaled, sum2_scaled;
    logic signed [DATA_WIDTH-1:0] y0_sat, y1_sat, y2_sat;

    localparam logic signed [DATA_WIDTH-1:0] MAX_Q15 = 16'sh7FFF; 
    localparam logic signed [DATA_WIDTH-1:0] MIN_Q15 = 16'sh8000; 

    always_comb begin
        sum0_scaled = sum0 >>> 15;
        sum1_scaled = sum1 >>> 15;
        sum2_scaled = sum2 >>> 15;

        if (sum0_scaled > MAX_Q15)
            y0_sat = MAX_Q15;
        else if (sum0_scaled < MIN_Q15)
            y0_sat = MIN_Q15;
        else
            y0_sat = sum0_scaled[DATA_WIDTH-1:0];

        if (sum1_scaled > MAX_Q15)
            y1_sat = MAX_Q15;
        else if (sum1_scaled < MIN_Q15)
            y1_sat = MIN_Q15;
        else
            y1_sat = sum1_scaled[DATA_WIDTH-1:0];

        if (sum2_scaled > MAX_Q15)
            y2_sat = MAX_Q15;
        else if (sum2_scaled < MIN_Q15)
            y2_sat = MIN_Q15;
        else
            y2_sat = sum2_scaled[DATA_WIDTH-1:0];
    end

    always_ff @(posedge clk) begin
        if (rst) begin
            y0 <= '0;
            y1 <= '0;
            y2 <= '0;
        end
        else begin
            y0 <= y0_sat;
            y1 <= y1_sat;
            y2 <= y2_sat;
        end
    end

endmodule
