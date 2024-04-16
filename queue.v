module queue(
    input clk,
    input [7:0]data_in,
    output [7:0]data_out,
    input dir,
    input read_success,
    output empty,
    input rst 
    
);

reg [7:0] mem [0:1240];
reg [10:0]write_address = 0;
reg [10:0]read_address = 0;
reg [7:0] r_data_out;
assign data_out = r_data_out;
reg [10:0] cnt = 0;
assign empty = cnt == 0;
reg dir_latch;
reg rs_latch;
always @(posedge clk ) begin
    dir_latch <= dir;
    rs_latch <= read_success;
    if (!rst) begin
        cnt <= 0;
        write_address <=0;
        read_address <=0;
        r_data_out <= 0;
    end
    if (dir && read_success && !dir_latch && !rs_latch)begin
        mem[write_address] <= data_in;
        write_address <= write_address + 1;
        r_data_out <= mem[read_address];
        read_address <= read_address + 1;
    end 
    else if (dir && !dir_latch) begin
        if (cnt < 1240) cnt <= cnt + 1;
        mem[write_address] <= data_in;
        write_address <= write_address + 1;
    end
    else if (read_success && !rs_latch) begin
        if (cnt > 0) cnt <= cnt - 1;
        r_data_out <= mem[read_address];
        // r_data_out <= write_address;
        read_address <= read_address + 1;
    end 
    else if (empty) begin
        read_address <= 0;
        write_address <= 0;
    end

end


endmodule