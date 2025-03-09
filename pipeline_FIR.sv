module pipeline_FIR #(
    parameter TAPS        = 100,
    parameter DATA_WIDTH  = 16,
    parameter COEF_WIDTH  = 16,   
    parameter ACC_WIDTH   = 40    
)(
    input  logic                       clk,
    input  logic                       rst, 
    input  logic signed [DATA_WIDTH-1:0] x, 
    input  logic signed [COEF_WIDTH-1:0] coef [0:TAPS-1], 
    output logic signed [DATA_WIDTH-1:0] y
);

    //  Shift Register for Input Samples

    logic signed [DATA_WIDTH-1:0] x_shift_reg [0:TAPS-1];
    integer j;

    always_ff @(posedge clk) begin
        if (rst) begin
            for (j = 0; j < TAPS; j++) begin
                x_shift_reg[j] <= '0;
            end
        end
        else begin
            x_shift_reg[0] <= x;
            for (j = 1; j < TAPS; j++) begin
                x_shift_reg[j] <= x_shift_reg[j-1];
            end
        end
    end

    //  Multiply Stage: Multiply each stored sample by its corresponding coefficient.
    logic signed [DATA_WIDTH+COEF_WIDTH-1:0] mult_result [0:TAPS-1];
    genvar i;

    generate
        for (i = 0; i < TAPS; i = i + 1) begin : mult_stage
            always_ff @(posedge clk) begin
                if (rst) begin
                    mult_result[i] <= '0;
                end
                else begin
                    mult_result[i] <= x_shift_reg[i] * coef[i];
                end
            end
        end
    endgenerate

    //  Accumulation Stage (Pipelined)
    logic signed [ACC_WIDTH-1:0] acc [0:TAPS-1];

    // First accumulation stage
    always_ff @(posedge clk) begin
        if (rst) begin
            acc[0] <= '0;
        end
        else begin
            acc[0] <= mult_result[0];
        end
    end

    generate
        for (i = 1; i < TAPS; i = i + 1) begin : acc_pipeline
            always_ff @(posedge clk) begin
                if (rst) begin
                    acc[i] <= '0;
                end
                else begin
                    acc[i] <= acc[i-1] + mult_result[i];
                end
            end
        end
    endgenerate
    logic signed [ACC_WIDTH-1:0] scaled_acc;
    logic signed [DATA_WIDTH-1:0] y_sat;
    logic signed [DATA_WIDTH-1:0] max_val, min_val;
    
    always_comb begin

        scaled_acc = acc[TAPS-1] + (1 <<< 14); 
        scaled_acc = scaled_acc >>> 15;  

        max_val = 16'h7FFF; 
        min_val = 16'h8000;  

        if (scaled_acc > $signed(max_val)) begin
            y_sat = max_val;
        end
        else if (scaled_acc < $signed(min_val)) begin
            y_sat = min_val;
        end
        else begin

            y_sat = scaled_acc[DATA_WIDTH-1:0];
        end
    end
    //  Register final output to complete the pipeline
    always_ff @(posedge clk) begin
        if (rst) begin
            y <= '0;
        end
        else begin
            y <= y_sat;
        end
    end

endmodule
