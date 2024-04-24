module queue #(parameter size = 256) (r_clk, data_out, w_clk, data_in, empty, full, rst);
    input r_clk;
    output [7:0]data_out;

    input w_clk;
    input [7:0]data_in;

    output empty;
    output full;
    input rst;

    parameter adr_size = $clog2(size) -1 ;
    (* ram_style = "block" *)
    reg [7:0] mem [0:size-1];
    reg [adr_size:0] r_address = 0;
    reg [adr_size:0] w_address = 0;
    reg [7:0]r_data_out = 0;
    
    assign data_out = r_data_out;

    always @(posedge r_clk) begin
        // if (~rst) r_address <= '0;
        if (~empty) begin
            r_data_out <= mem[r_address];
            r_address <= r_address + 1'b1;
        end
    end

    always @(posedge w_clk ) begin
        // if (~rst) w_address <= '0;
        if (~full) begin
            mem[w_address] <= data_in;
            w_address <= w_address + 1'b1;
        end
    end

    assign empty = r_address == w_address;
    assign full = (w_address + 1'b1) == r_address;
endmodule
