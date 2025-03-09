module testbench_pipeline();

    localparam TAPS        = 100;
    localparam DATA_WIDTH  = 16;
    localparam COEF_WIDTH  = 16;
    localparam FIR_VERSION = 0; 
    
    localparam CLK_PERIOD  = 10; 
    localparam RUN_CYCLES  = 4000; 


    logic                       clk;
    logic                       rst;
    logic signed [DATA_WIDTH-1:0] x0, x1, x2;  
    logic signed [DATA_WIDTH-1:0] y0, y1, y2;  
  
    fir_top #(
		 .FIR_VERSION(1), // L=2
		 .TAPS(100),
		 .DATA_WIDTH(16),
		 .COEF_WIDTH(16)
	) dut (
		 .clk(clk),
		 .rst(rst),
		 .x0(x0),
		 .x1(x1),
		 .x2(x2),    
		 .y0(y0),
		 .y1(y1),
		 .y2(y2)
	);

  
    initial begin
        clk = 1'b0;
        forever #(CLK_PERIOD/2) clk = ~clk;
    end


    integer logFile;

 
    task zero_input_test;
        integer i;
        begin
            $display("=== Starting ZERO INPUT TEST ==="); //
            $fwrite(logFile, "\n==============================\n");
            $fwrite(logFile, "Zero Input Test\n");
            $fwrite(logFile, "==============================\n");

            for (i = 0; i < 2*TAPS; i++) begin
                x0 = 16'sh0000;
                @(posedge clk);
                $fwrite(logFile, "[ZeroTest] cycle=%0t, x=%d, y=%d\n",
                                $time, x0, y0);
            end

            $display("Zero Input Test: DONE!");
        end
    endtask

    task impulse_test;
        integer i;
        begin
            $display("=== Starting IMPULSE RESPONSE TEST ==="); 
            $fwrite(logFile, "\n==============================\n");
            $fwrite(logFile, "Impulse Response Test\n");
            $fwrite(logFile, "==============================\n");

            x0 = 16'sh7FFF; 
            @(posedge clk);
            $fwrite(logFile,"[Impulse] cycle=%0t, x=%d, y=%d\n",
                             $time, x0, y0);

            x0 = 16'sh0000;
            for (i = 0; i < TAPS+20; i++) begin
                @(posedge clk);
                $fwrite(logFile,"[Impulse] cycle=%0t, x=%d, y=%d\n",
                                 $time, x0, y0);
            end

            $display("Impulse Response Test: DONE!");
        end
    endtask

    task step_test;
        integer i;
        begin
            $display("=== Starting STEP INPUT TEST ==="); 
            $fwrite(logFile, "\n==============================\n");
            $fwrite(logFile, "Step Input Test\n");
            $fwrite(logFile, "==============================\n");

    
            x0 = 16'sh7FFF;
            for (i = 0; i < 3*TAPS; i++) begin
                @(posedge clk);
                $fwrite(logFile,"[Step] cycle=%0t, x=%d, y=%d\n",
                                 $time, x0, y0);
            end

   
            x0 = 16'sh0000;
            for (i = 0; i < TAPS+20; i++) begin
                @(posedge clk);
                $fwrite(logFile,"[Step->0] cycle=%0t, x=%d, y=%d\n",
                                 $time, x0, y0);
            end

            $display("Step Input Test: DONE!");
        end
    endtask

    task sine_wave_test;
        integer i;
        real freq, amplitude, radians;
        integer sin_val;
        begin
            $display("=== Starting SINE WAVE TEST ==="); 
            $fwrite(logFile, "\n==============================\n");
            $fwrite(logFile, "Sine Wave Test\n");
            $fwrite(logFile, "==============================\n");

            freq      = 1.0/16.0;  
            amplitude = 0.5;      

            for (i = 0; i < 4*TAPS; i++) begin
                radians  = 2.0 * 3.1415926535 * freq * i;
                sin_val = $rtoi(amplitude*32767.0*$sin(radians));
                x0       = sin_val;
                @(posedge clk);
                $fwrite(logFile,"[Sine] cycle=%0t, x=%d, y=%d\n",
                                 $time, x0, y0);
            end

            x0 = 16'sh0000;
            for (i = 0; i < TAPS+20; i++) begin
                @(posedge clk);
                $fwrite(logFile,"[Sine->0] cycle=%0t, x=%d, y=%d\n",
                                 $time, x0, y0);
            end

            $display("Sine Wave Test: DONE!");
        end
    endtask


    initial begin
        // Open the log file
        logFile = $fopen("pipeline.txt", "w");
        if (!logFile) begin
            $display("ERROR: Could not open pipeline.txt for writing!");
            $finish;
        end

        $display("============================================");
        $display(" Testbench for Pipeline FIR (Version=0) ");
        $display(" - Detailed output is in pipeline.txt");
        $display("============================================");

        // Reset
        rst = 1'b1;
        x0  = 16'sh0000;
        x1  = 16'sh0000;
        x2  = 16'sh0000;
        repeat (10) @(posedge clk); 
        rst = 1'b0;
        @(posedge clk);

        // Run each test in sequence
        zero_input_test();
        impulse_test();
        step_test();
        sine_wave_test();

        repeat (20) @(posedge clk);

        // Close the file
        $fclose(logFile);

        $display("============================================");
        $display(" All Tests Completed at time=%0t ns", $time);
        $display(" See pipeline.txt for detailed waveforms/logs.");
        $display("============================================");
    end

    initial begin
        #(RUN_CYCLES * CLK_PERIOD);
        $display("ERROR: Simulation timed out at %0t ns", $time);
        $fclose(logFile);
    end

endmodule


module testbench_parallel_l2();


    localparam TAPS        = 100;
    localparam DATA_WIDTH  = 16;
    localparam COEF_WIDTH  = 16;
    localparam ACC_WIDTH   = 40;

    localparam CLK_PERIOD  = 10;    
    localparam RUN_CYCLES  = 4000;  
 
    logic                             clk;
    logic                             rst;
    logic signed [DATA_WIDTH-1:0]     x0, x1, x2;
    logic signed [DATA_WIDTH-1:0]     y0, y1, y2;

 
    logic signed [COEF_WIDTH-1:0] coef [0:TAPS-1];
    initial begin

        integer i;
        for (i=0; i < TAPS; i++) begin
            coef[i] = 0; 
        end
    end

    fir_top #(
		 .FIR_VERSION(1), // L=2
		 .TAPS(100),
		 .DATA_WIDTH(16),
		 .COEF_WIDTH(16)
	) dut (
		 .clk(clk),
		 .rst(rst),
		 .x0(x0),
		 .x1(x1),
		 .x2(x2),   
		 .y0(y0),
		 .y1(y1),
		 .y2(y2)
	);

    initial begin
        clk = 1'b0;
        forever #(CLK_PERIOD/2) clk = ~clk;
    end


    integer logFile;

  
    // 1) Zero Input Test
    task zero_input_test;
        integer i;
        begin
            $display("=== Starting ZERO INPUT TEST (L=2) ===");
            $fwrite(logFile, "\n==============================\n");
            $fwrite(logFile, "Zero Input Test (L=2)\n");
            $fwrite(logFile, "==============================\n");

            for (i = 0; i < 2*TAPS; i++) begin
               
                x0 = 16'sh0000;
                x1 = 16'sh0000;
                @(posedge clk);
                $fwrite(logFile,"[ZeroTest] cycle=%0t, x0=%d, x1=%d, y0=%d, y1=%d\n",
                                 $time, x0, x1, y0, y1);
            end

            $display("Zero Input Test (L=2): DONE!");
        end
    endtask

    
    // 2) Impulse Response Test

    task impulse_test;
        integer i;
        begin
            $display("=== Starting IMPULSE RESPONSE TEST (L=2) ===");
            $fwrite(logFile, "\n==============================\n");
            $fwrite(logFile, "Impulse Response Test (L=2)\n");
            $fwrite(logFile, "==============================\n");

         
            x0 = 16'sh7FFF;
            x1 = 16'sh0000;
            @(posedge clk);
            $fwrite(logFile,"[Impulse] cycle=%0t, x0=%d, x1=%d, y0=%d, y1=%d\n",
                             $time, x0, x1, y0, y1);

            x0 = 16'sh0000;
            x1 = 16'sh0000;
            for (i = 0; i < TAPS+20; i++) begin
                @(posedge clk);
                $fwrite(logFile,"[Impulse] cycle=%0t, x0=%d, x1=%d, y0=%d, y1=%d\n",
                                 $time, x0, x1, y0, y1);
            end

            $display("Impulse Response Test (L=2): DONE!");
        end
    endtask

    // 3) Step Input Test

    task step_test;
        integer i;
        begin
            $display("=== Starting STEP INPUT TEST (L=2) ===");
            $fwrite(logFile, "\n==============================\n");
            $fwrite(logFile, "Step Input Test (L=2)\n");
            $fwrite(logFile, "==============================\n");

    
            for (i = 0; i < 3*TAPS; i++) begin
                x0 = 16'sh7FFF;
                x1 = 16'sh7FFF;
                @(posedge clk);
                $fwrite(logFile,"[Step] cycle=%0t, x0=%d, x1=%d, y0=%d, y1=%d\n",
                                 $time, x0, x1, y0, y1);
            end

            for (i = 0; i < TAPS+20; i++) begin
                x0 = 16'sh0000;
                x1 = 16'sh0000;
                @(posedge clk);
                $fwrite(logFile,"[Step->0] cycle=%0t, x0=%d, x1=%d, y0=%d, y1=%d\n",
                                 $time, x0, x1, y0, y1);
            end

            $display("Step Input Test (L=2): DONE!");
        end
    endtask

    // 4) Sine Wave Input Test

    task sine_wave_test;
        integer i;
        real freq, amplitude;
        real phase0, phase1;
        integer sin_val0, sin_val1;
        begin
            $display("=== Starting SINE WAVE TEST (L=2) ===");
            $fwrite(logFile, "\n==============================\n");
            $fwrite(logFile, "Sine Wave Test (L=2)\n");
            $fwrite(logFile, "==============================\n");

            
            freq      = 1.0 / 16.0; 
            amplitude = 0.5;        

            phase0 = 0.0;
            phase1 = 2.0 * 3.14159265 * freq * 0.5;

            for (i = 0; i < 2*TAPS; i++) begin
                sin_val0 = $rtoi( amplitude * 32767.0 * $sin(phase0) );
                sin_val1 = $rtoi( amplitude * 32767.0 * $sin(phase1) );
                x0 = sin_val0;
                x1 = sin_val1;

                @(posedge clk);
                $fwrite(logFile,"[Sine] cycle=%0t, x0=%d, x1=%d, y0=%d, y1=%d\n",
                                 $time, x0, x1, y0, y1);

                // increment phases
                phase0 += 2.0 * 3.14159265 * freq;
                phase1 += 2.0 * 3.14159265 * freq;
            end

         
            for (i = 0; i < TAPS+20; i++) begin
                x0 = 16'sh0000;
                x1 = 16'sh0000;
                @(posedge clk);
                $fwrite(logFile,"[Sine->0] cycle=%0t, x0=%d, x1=%d, y0=%d, y1=%d\n",
                                 $time, x0, x1, y0, y1);
            end

            $display("Sine Wave Test (L=2): DONE!");
        end
    endtask


 
    initial begin
   
        logFile = $fopen("parallel_L2.txt", "w");
        if (!logFile) begin
            $display("ERROR: Could not open parallel_L2.txt for writing!");
            $finish;
        end

        $display("============================================");
        $display(" Testbench for L=2 Parallel FIR Filter ");
        $display(" - Detailed output is in parallel_L2.txt");
        $display("============================================");

        rst = 1'b1;
        x0  = 16'sh0000;
        x1  = 16'sh0000;
		  x2  = 16'sh0000;
        repeat (10) @(posedge clk);
        rst = 1'b0;
        @(posedge clk);

        zero_input_test();
        impulse_test();
        step_test();
        sine_wave_test();

        repeat (20) @(posedge clk);

        $fclose(logFile);

        $display("============================================");
        $display(" All L=2 Parallel Tests Completed at time=%0t ns", $time);
        $display(" See parallel_L2.txt for detailed waveforms/logs.");
        $display("============================================");
    end

    initial begin
        #(RUN_CYCLES * CLK_PERIOD);
        $display("ERROR: Simulation timed out at %0t ns", $time);
        $fclose(logFile);
    end

endmodule

module testbench_parallel_l3();

    
    localparam TAPS        = 100;
    localparam DATA_WIDTH  = 16;
    localparam COEF_WIDTH  = 16;
    localparam FIR_VERSION = 2;
    localparam CLK_PERIOD  = 10;
    localparam RUN_CYCLES  = 4000;

    logic clk, rst;
    logic signed [DATA_WIDTH-1:0] x0, x1, x2; 
    logic signed [DATA_WIDTH-1:0] y0, y1, y2;


    fir_top #(
        .FIR_VERSION(FIR_VERSION),
        .TAPS(TAPS),
        .DATA_WIDTH(DATA_WIDTH),
        .COEF_WIDTH(COEF_WIDTH)
    ) dut (
        .clk(clk),
        .rst(rst),

        .x0(x0),
        .x1(x1),
        .x2(x2),
  
        .y0(y0),
        .y1(y1),
        .y2(y2)
    );


    initial begin
        clk = 1'b0;
        forever #(CLK_PERIOD/2) clk = ~clk;
    end

    integer logFile;

    // 1) Zero Input Test
    
    task zero_input_test;
        integer i;
        begin
            $display("=== Starting ZERO INPUT TEST (L=3) ===");
            $fwrite(logFile, "\n==============================\n");
            $fwrite(logFile, "Zero Input Test (L=3)\n");
            $fwrite(logFile, "==============================\n");

            for (i = 0; i < 2*TAPS; i++) begin
                x0 = 16'sh0000;
                x1 = 16'sh0000;
                x2 = 16'sh0000;
                @(posedge clk);
                $fwrite(logFile,
                        "[ZeroTest] cycle=%0t, x0=%d, x1=%d, x2=%d, y0=%d, y1=%d, y2=%d\n",
                         $time, x0, x1, x2, y0, y1, y2);
            end

            $display("Zero Input Test (L=3): DONE!");
        end
    endtask

    // 2) Impulse Response Test

    task impulse_test;
        integer i;
        begin
            $display("=== Starting IMPULSE RESPONSE TEST (L=3) ===");
            $fwrite(logFile, "\n==============================\n");
            $fwrite(logFile, "Impulse Response Test (L=3)\n");
            $fwrite(logFile, "==============================\n");
            x0 = 16'sh7FFF;
            x1 = 16'sh0000;
            x2 = 16'sh0000;
            @(posedge clk);
            $fwrite(logFile,
                    "[Impulse] cycle=%0t, x0=%d, x1=%d, x2=%d, y0=%d, y1=%d, y2=%d\n",
                     $time, x0, x1, x2, y0, y1, y2);

    
            x0 = 0;
            x1 = 0;
            x2 = 0;
            for (i = 0; i < TAPS+20; i++) begin
                @(posedge clk);
                $fwrite(logFile,
                        "[Impulse] cycle=%0t, x0=%d, x1=%d, x2=%d, y0=%d, y1=%d, y2=%d\n",
                         $time, x0, x1, x2, y0, y1, y2);
            end

            $display("Impulse Response Test (L=3): DONE!");
        end
    endtask

    
    // 3) Step Input Test

    task step_test;
        integer i;
        begin
            $display("=== Starting STEP INPUT TEST (L=3) ===");
            $fwrite(logFile, "\n==============================\n");
            $fwrite(logFile, "Step Input Test (L=3)\n");
            $fwrite(logFile, "==============================\n");

          
            for (i = 0; i < 3*TAPS; i++) begin
                x0 = 16'sh7FFF;
                x1 = 16'sh7FFF;
                x2 = 16'sh7FFF;
                @(posedge clk);
                $fwrite(logFile,
                        "[Step] cycle=%0t, x0=%d, x1=%d, x2=%d, y0=%d, y1=%d, y2=%d\n",
                         $time, x0, x1, x2, y0, y1, y2);
            end

            for (i = 0; i < TAPS+20; i++) begin
                x0 = 16'sh0000;
                x1 = 16'sh0000;
                x2 = 16'sh0000;
                @(posedge clk);
                $fwrite(logFile,
                        "[Step->0] cycle=%0t, x0=%d, x1=%d, x2=%d, y0=%d, y1=%d, y2=%d\n",
                         $time, x0, x1, x2, y0, y1, y2);
            end

            $display("Step Input Test (L=3): DONE!");
        end
    endtask

    // 4) Sine Wave Input Test

    task sine_wave_test;
        integer i;
        real freq, amplitude;
        real phase0, phase1, phase2;
        integer sin_val0, sin_val1, sin_val2;
        begin
            $display("=== Starting SINE WAVE TEST (L=3) ===");
            $fwrite(logFile, "\n==============================\n");
            $fwrite(logFile, "Sine Wave Test (L=3)\n");
            $fwrite(logFile, "==============================\n");

            freq      = 1.0/16.0;  
            amplitude = 0.5;      

            phase0 = 0.0;
            phase1 = 1.0; // slight offset
            phase2 = 2.0; // bigger offset
            for (i = 0; i < 2*TAPS; i++) begin
                sin_val0 = $rtoi(amplitude * 32767.0 * $sin(2.0*3.14159265*freq*phase0));
                sin_val1 = $rtoi(amplitude * 32767.0 * $sin(2.0*3.14159265*freq*phase1));
                sin_val2 = $rtoi(amplitude * 32767.0 * $sin(2.0*3.14159265*freq*phase2));

                x0 = sin_val0;
                x1 = sin_val1;
                x2 = sin_val2;

                @(posedge clk);
                $fwrite(logFile,
                        "[Sine] cycle=%0t, x0=%d, x1=%d, x2=%d, y0=%d, y1=%d, y2=%d\n",
                         $time, x0, x1, x2, y0, y1, y2);

                phase0 += 1.0;
                phase1 += 1.0;
                phase2 += 1.0;
            end

            // Then zero for TAPS+20 to see the ringout
            for (i = 0; i < TAPS+20; i++) begin
                x0 = 16'sh0000;
                x1 = 16'sh0000;
                x2 = 16'sh0000;
                @(posedge clk);
                $fwrite(logFile,
                        "[Sine->0] cycle=%0t, x0=%d, x1=%d, x2=%d, y0=%d, y1=%d, y2=%d\n",
                         $time, x0, x1, x2, y0, y1, y2);
            end

            $display("Sine Wave Test (L=3): DONE!");
        end
    endtask


    initial begin
     
        logFile = $fopen("parallel_L3.txt", "w");
        if (!logFile) begin
            $display("ERROR: Could not open l3_fir_run.txt!");
            $finish;
        end

        $display("============================================");
        if (FIR_VERSION == 2)
            $display(" Testbench for PARALLEL L=3 FIR Filter ");
        else
            $display(" Testbench for PIPELINE+PARALLEL L=3 FIR Filter ");
        $display(" - Detailed output is in l3_fir_run.txt");
        $display("============================================");

        rst = 1;
        x0  = 16'sh0000;
        x1  = 16'sh0000;
        x2  = 16'sh0000;
        repeat (10) @(posedge clk);
        rst = 0;
        @(posedge clk);

        zero_input_test();
        impulse_test();
        step_test();
        sine_wave_test();

        repeat (20) @(posedge clk);

        $fclose(logFile);

        $display("============================================");
        if (FIR_VERSION == 2)
            $display(" All PARALLEL L=3 Tests Completed at time=%0t ns", $time);
        else
            $display(" All PIPELINE+L=3 Tests Completed at time=%0t ns", $time);
        $display(" See l3_fir_run.txt for logs.");
        $display("============================================");
        $finish;
    end

    initial begin
        #(RUN_CYCLES * CLK_PERIOD);
        $display("ERROR: Simulation timed out at %0t ns", $time);
        $fclose(logFile);
        $finish;
    end

endmodule


module testbench_pipeline_parallel_l3();

    localparam TAPS        = 100;
    localparam DATA_WIDTH  = 16;
    localparam COEF_WIDTH  = 16;
    localparam FIR_VERSION = 3;
    localparam CLK_PERIOD  = 10;
    localparam RUN_CYCLES  = 4000;
    logic clk, rst;
    logic signed [DATA_WIDTH-1:0] x0, x1, x2; 
    logic signed [DATA_WIDTH-1:0] y0, y1, y2;

    fir_top #(
        .FIR_VERSION(FIR_VERSION),
        .TAPS(TAPS),
        .DATA_WIDTH(DATA_WIDTH),
        .COEF_WIDTH(COEF_WIDTH)
    ) dut (
        .clk(clk),
        .rst(rst),
        .x0(x0),
        .x1(x1),
        .x2(x2),
        .y0(y0),
        .y1(y1),
        .y2(y2)
    );

    initial begin
        clk = 1'b0;
        forever #(CLK_PERIOD/2) clk = ~clk;
    end

    integer logFile;

    // 1) Zero Input Test

    task zero_input_test;
        integer i;
        begin
            $display("=== Starting ZERO INPUT TEST (L=3) ===");
            $fwrite(logFile, "\n==============================\n");
            $fwrite(logFile, "Zero Input Test (L=3)\n");
            $fwrite(logFile, "==============================\n");

            for (i = 0; i < 2*TAPS; i++) begin
                x0 = 16'sh0000;
                x1 = 16'sh0000;
                x2 = 16'sh0000;
                @(posedge clk);
                $fwrite(logFile,
                        "[ZeroTest] cycle=%0t, x0=%d, x1=%d, x2=%d, y0=%d, y1=%d, y2=%d\n",
                         $time, x0, x1, x2, y0, y1, y2);
            end

            $display("Zero Input Test (L=3): DONE!");
        end
    endtask

    // 2) Impulse Response Test

    task impulse_test;
        integer i;
        begin
            $display("=== Starting IMPULSE RESPONSE TEST (L=3) ===");
            $fwrite(logFile, "\n==============================\n");
            $fwrite(logFile, "Impulse Response Test (L=3)\n");
            $fwrite(logFile, "==============================\n");
            x0 = 16'sh7FFF;
            x1 = 16'sh0000;
            x2 = 16'sh0000;
            @(posedge clk);
            $fwrite(logFile,
                    "[Impulse] cycle=%0t, x0=%d, x1=%d, x2=%d, y0=%d, y1=%d, y2=%d\n",
                     $time, x0, x1, x2, y0, y1, y2);
            x0 = 0;
            x1 = 0;
            x2 = 0;
            for (i = 0; i < TAPS+20; i++) begin
                @(posedge clk);
                $fwrite(logFile,
                        "[Impulse] cycle=%0t, x0=%d, x1=%d, x2=%d, y0=%d, y1=%d, y2=%d\n",
                         $time, x0, x1, x2, y0, y1, y2);
            end

            $display("Impulse Response Test (L=3): DONE!");
        end
    endtask

    
    // 3) Step Input Test

    task step_test;
        integer i;
        begin
            $display("=== Starting STEP INPUT TEST (L=3) ===");
            $fwrite(logFile, "\n==============================\n");
            $fwrite(logFile, "Step Input Test (L=3)\n");
            $fwrite(logFile, "==============================\n");

            for (i = 0; i < 3*TAPS; i++) begin
                x0 = 16'sh7FFF;
                x1 = 16'sh7FFF;
                x2 = 16'sh7FFF;
                @(posedge clk);
                $fwrite(logFile,
                        "[Step] cycle=%0t, x0=%d, x1=%d, x2=%d, y0=%d, y1=%d, y2=%d\n",
                         $time, x0, x1, x2, y0, y1, y2);
            end

            for (i = 0; i < TAPS+20; i++) begin
                x0 = 16'sh0000;
                x1 = 16'sh0000;
                x2 = 16'sh0000;
                @(posedge clk);
                $fwrite(logFile,
                        "[Step->0] cycle=%0t, x0=%d, x1=%d, x2=%d, y0=%d, y1=%d, y2=%d\n",
                         $time, x0, x1, x2, y0, y1, y2);
            end

            $display("Step Input Test (L=3): DONE!");
        end
    endtask

    // 4) Sine Wave Input Test
   
    task sine_wave_test;
        integer i;
        real freq, amplitude;
        real phase0, phase1, phase2;
        integer sin_val0, sin_val1, sin_val2;
        begin
            $display("=== Starting SINE WAVE TEST (L=3) ===");
            $fwrite(logFile, "\n==============================\n");
            $fwrite(logFile, "Sine Wave Test (L=3)\n");
            $fwrite(logFile, "==============================\n");

            freq      = 1.0/16.0;  
            amplitude = 0.5;       

    
            phase0 = 0.0;
            phase1 = 1.0; 
            phase2 = 2.0; 
            for (i = 0; i < 2*TAPS; i++) begin
                sin_val0 = $rtoi(amplitude * 32767.0 * $sin(2.0*3.14159265*freq*phase0));
                sin_val1 = $rtoi(amplitude * 32767.0 * $sin(2.0*3.14159265*freq*phase1));
                sin_val2 = $rtoi(amplitude * 32767.0 * $sin(2.0*3.14159265*freq*phase2));

                x0 = sin_val0;
                x1 = sin_val1;
                x2 = sin_val2;

                @(posedge clk);
                $fwrite(logFile,
                        "[Sine] cycle=%0t, x0=%d, x1=%d, x2=%d, y0=%d, y1=%d, y2=%d\n",
                         $time, x0, x1, x2, y0, y1, y2);

                phase0 += 1.0;
                phase1 += 1.0;
                phase2 += 1.0;
            end
            for (i = 0; i < TAPS+20; i++) begin
                x0 = 16'sh0000;
                x1 = 16'sh0000;
                x2 = 16'sh0000;
                @(posedge clk);
                $fwrite(logFile,
                        "[Sine->0] cycle=%0t, x0=%d, x1=%d, x2=%d, y0=%d, y1=%d, y2=%d\n",
                         $time, x0, x1, x2, y0, y1, y2);
            end

            $display("Sine Wave Test (L=3): DONE!");
        end
    endtask


    initial begin
        logFile = $fopen("pipeline_parallel_L3.txt", "w");
        if (!logFile) begin
            $display("ERROR: Could not open l3_fir_run.txt!");
            $finish;
        end

        $display("============================================");
        if (FIR_VERSION == 2)
            $display(" Testbench for PARALLEL L=3 FIR Filter ");
        else
            $display(" Testbench for PIPELINE+PARALLEL L=3 FIR Filter ");
        $display(" - Detailed output is in l3_fir_run.txt");
        $display("============================================");

        rst = 1;
        x0  = 16'sh0000;
        x1  = 16'sh0000;
        x2  = 16'sh0000;
        repeat (10) @(posedge clk);
        rst = 0;
        @(posedge clk);

        zero_input_test();
        impulse_test();
        step_test();
        sine_wave_test();

        repeat (20) @(posedge clk);

        $fclose(logFile);

        $display("============================================");
        if (FIR_VERSION == 2)
            $display(" All PARALLEL L=3 Tests Completed at time=%0t ns", $time);
        else
            $display(" All PIPELINE+L=3 Tests Completed at time=%0t ns", $time);
        $display(" See l3_fir_run.txt for logs.");
        $display("============================================");
        $finish;
    end

    initial begin
        #(RUN_CYCLES * CLK_PERIOD);
        $display("ERROR: Simulation timed out at %0t ns", $time);
        $fclose(logFile);
        $finish;
    end

endmodule


module fir_top #(
    parameter FIR_VERSION = 3, 
    parameter TAPS        = 100,
    parameter DATA_WIDTH  = 16,
    parameter COEF_WIDTH  = 16
)(
    input  logic clk,
    input  logic rst,

    input  logic signed [DATA_WIDTH-1:0] x0,
    input  logic signed [DATA_WIDTH-1:0] x1,
    input  logic signed [DATA_WIDTH-1:0] x2,

    output logic signed [DATA_WIDTH-1:0] y0,
    output logic signed [DATA_WIDTH-1:0] y1,
    output logic signed [DATA_WIDTH-1:0] y2
);


    logic signed [COEF_WIDTH-1:0] coef [0:TAPS-1];
    fir_coef_rom #(
        .TAPS(TAPS), 
        .COEF_WIDTH(COEF_WIDTH)
    ) coef_rom_inst (
        .coef(coef)
    );

    generate
        if (FIR_VERSION == 0) begin : gen_pipeline
            pipeline_FIR #(
                .TAPS(TAPS),
                .DATA_WIDTH(DATA_WIDTH),
                .COEF_WIDTH(COEF_WIDTH)
            ) fir_inst (
                .clk(clk),
                .rst(rst),
                .x(x0),
                .y(y0),
                .coef(coef)
            );
            assign y1 = '0;
            assign y2 = '0;

        end else if (FIR_VERSION == 1) begin : gen_l2
            parallel_FIR_L2 #(
                .TAPS(TAPS),
                .DATA_WIDTH(DATA_WIDTH),
                .COEF_WIDTH(COEF_WIDTH)
            ) fir_inst (
                .clk(clk),
                .rst(rst),
                .x0(x0),
                .x1(x1),
                .y0(y0),
                .y1(y1),
                .coef(coef)
            );

            assign y2 = '0;

        end else if (FIR_VERSION == 2) begin : gen_l3
          
            parallel_FIR_L3 #(
                .TAPS(TAPS),
                .DATA_WIDTH(DATA_WIDTH),
                .COEF_WIDTH(COEF_WIDTH)
            ) fir_inst (
                .clk(clk),
                .rst(rst),
                // Use x0, x1, x2 => y0, y1, y2
                .x0(x0),
                .x1(x1),
                .x2(x2),
                .y0(y0),
                .y1(y1),
                .y2(y2),
                .coef(coef)
            );

        end else if (FIR_VERSION == 3) begin : gen_pipeline_l3

            pipeline_parallel_FIR_L3 #(
                .TAPS(TAPS),
                .DATA_WIDTH(DATA_WIDTH),
                .COEF_WIDTH(COEF_WIDTH)
            ) fir_inst (
                .clk(clk),
                .rst(rst),
                .x0(x0),
                .x1(x1),
                .x2(x2),
                .y0(y0),
                .y1(y1),
                .y2(y2),
                .coef(coef)
            );

        end else begin
            initial $fatal("Invalid FIR_VERSION selected!");
        end
    endgenerate

endmodule



// Load Quantized Q15 coefficients
module fir_coef_rom #(
    parameter TAPS       = 100,
    parameter COEF_WIDTH = 16
)(
    output logic signed [COEF_WIDTH-1:0] coef [0:TAPS-1]
);

    // Load the coefficients from the hex file.
    initial begin
        $readmemh("fir_coefficients.hex", coef);
    end

endmodule


