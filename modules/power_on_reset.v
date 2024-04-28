module power_on_reset(clk, rst_in, rst_out);
    // TODO: calc time properly and add as a parameter
    input clk;
    input rst_in;
    output rst_out;
    reg started =0;

    reg [$clog2(1000)-1:0] start_counter = 0;
    always @(posedge clk) begin
        if (start_counter < 1000) begin
            start_counter <= start_counter + 1'b1;
        end
        else begin
            started <= 1;
        end
    end
    assign rst_out = rst_in & started;

endmodule
