module queue_tb;

    // Parameters
    parameter CLK_PERIOD = 10; // Clock period in time units
    
    reg r_clk = 0;
    wire [7:0] data_out;
    reg w_clk = 0;
    reg [7:0] data_in;
    wire empty;
    wire full;
    reg [7:0]test_data=0;
    reg rst = 1;
    parameter size = 8;
    queue #(.size(256)) q1 (
              .r_clk(r_clk),
              .data_out(data_out),
              .w_clk(w_clk),
              .data_in(data_in),
              .empty(empty),
              .full(full),
              .rst(rst)
          );


    integer  i;

    initial begin
        // Dump waves
        $dumpfile("dump.vcd");
        $dumpvars(0, queue_tb);

        $display("start");

        for (i =1; i<10; i=i+1) begin
            #1; 
            if (~full) begin
                data_in = i;
                #1;
                w_clk = 1;
                #1;
                w_clk = 0;
                #1;
            end
        end
        $display("mem[7] %d", q1.mem[6]);
        #1;
        for (i =1; i<10; i=i+1) begin
            #1;
            if (~empty) begin
                r_clk = 1;
                #1;
                test_data = data_out;
                #1;
                $display("test data %d", test_data);
                r_clk = 0;
                #1;
            end
        end
        #1;
        for (i =1; i<10; i=i+1) begin
            #1;
            if (~full) begin
                data_in = i;
                #1;
                w_clk = 1;
                #1;
                w_clk = 0;
            end
        end
        #1;
        rst <= 1;
        #1;
        rst <= 0;
        for (i =0; i<=9; i=i+1) begin
            #1;
            if (~empty) begin
                r_clk = 1;
                #1;
                test_data = data_out;
                #1;
                $display("test data %d", test_data);
                r_clk = 0;
            end
        end
        #1;
    end

endmodule
