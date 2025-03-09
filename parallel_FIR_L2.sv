module parallel_FIR_L2 #(
    parameter TAPS       = 100,  
    parameter DATA_WIDTH = 16, 
    parameter COEF_WIDTH = 16,   
    parameter ACC_WIDTH  = 40   
)(
    input  logic                             clk,
    input  logic                             rst, 
    input  logic signed [DATA_WIDTH-1:0]     x0,
    input  logic signed [DATA_WIDTH-1:0]     x1,
    input  logic signed [COEF_WIDTH-1:0]     coef [0:TAPS-1],
    output logic signed [DATA_WIDTH-1:0]     y0,
    output logic signed [DATA_WIDTH-1:0]     y1
);


    localparam SHIFT_LEN = TAPS + 1; 

    logic signed [DATA_WIDTH-1:0] shift_reg [0:SHIFT_LEN-1];
	 
	 integer j;
	 integer i;
    always_ff @(posedge clk) begin
        if (rst) begin
            
            for (j = 0; j < SHIFT_LEN; j++) begin
                shift_reg[j] <= '0;
            end
        end
        else begin
            shift_reg[0] <= x1;   
            shift_reg[1] <= x0;   
            
            for (i = 2; i < SHIFT_LEN; i++) begin
                shift_reg[i] <= shift_reg[i-2];
            end
        end
    end

    logic signed [ACC_WIDTH-1:0] sum0;
    logic signed [ACC_WIDTH-1:0] sum1;

    always_comb begin
        sum0 = '0;
        sum1 = '0;
  
        for (int i = 0; i < TAPS; i++) begin
            logic signed [DATA_WIDTH+COEF_WIDTH-1:0] product0, product1;
            product0 = shift_reg[i]   * coef[i];
            product1 = shift_reg[i+1] * coef[i]; 
            sum0 += product0;
            sum1 += product1;
        end
    end

    logic signed [ACC_WIDTH-1:0] sum0_scaled, sum1_scaled;
    logic signed [DATA_WIDTH-1:0] y0_sat,      y1_sat;

    localparam logic signed [DATA_WIDTH-1:0] MAX_Q15 = 16'sh7FFF; 
    localparam logic signed [DATA_WIDTH-1:0] MIN_Q15 = 16'sh8000; 

    always_comb begin
        sum0_scaled = sum0 >>> 15;
        sum1_scaled = sum1 >>> 15;

        if (sum0_scaled > MAX_Q15) begin
            y0_sat = MAX_Q15;
        end
        else if (sum0_scaled < MIN_Q15) begin
            y0_sat = MIN_Q15;
        end
        else begin
            y0_sat = sum0_scaled[DATA_WIDTH-1:0];
        end

        if (sum1_scaled > MAX_Q15) begin
            y1_sat = MAX_Q15;
        end
        else if (sum1_scaled < MIN_Q15) begin
            y1_sat = MIN_Q15;
        end
        else begin
            y1_sat = sum1_scaled[DATA_WIDTH-1:0];
        end
    end

    always_ff @(posedge clk) begin
        if (rst) begin
            y0 <= '0;
            y1 <= '0;
        end
        else begin
            y0 <= y0_sat;
            y1 <= y1_sat;
        end
    end

endmodule
