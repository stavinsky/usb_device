module buffered_uart_tx(uart_tx, clk, data, data_valid, full, rst );

    output uart_tx;
    input clk;
    input [7:0] data;
    input data_valid;
    output full;
    input rst;

    wire uart_dv;
    wire [7:0] uart_tx_data;
    wire uart_active;
    reg q_r_clk;
    wire q_empty;

    reg data_valid_loc ;

    uart_tx uart_tx1(
                .i_Clock(clk),
                .i_Tx_DV(uart_dv),
                .i_Tx_Byte(uart_tx_data),
                .o_Tx_Active(uart_active),
                .o_Tx_Serial(uart_tx),
                .o_Tx_Done()
            );

    queue queue1(
              .empty(q_empty),
              .data_in(data),
              .data_out(uart_tx_data),
              .r_clk(q_r_clk),
              .w_clk(data_valid_loc),
              .full(full),
              .rst(rst)

          );

    assign uart_dv = q_r_clk; 


    always @(posedge clk) begin 
        data_valid_loc <= data_valid;
    end

    always @(posedge clk) begin 
        q_r_clk <= 1'b0;
        if (~q_empty & ~uart_active ) begin
            q_r_clk <= 1'b1;
        end

    end


endmodule
