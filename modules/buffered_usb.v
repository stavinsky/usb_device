module buffered_usb(clk, usb_dp, usb_dn, rst, uart_tx);
    input clk;
    inout usb_dp;
    inout usb_dn;
    input rst;
    output uart_tx;


    wire success; // crc is valid
    wire transaction_active;
    reg data_toggle = 0;
    wire data_strobe;
    wire usb_tx_se0, usb_tx_j, usb_tx_en;
    reg usb_dp_sync;
    reg usb_dn_sync;
    wire usb_rst; // set to 1 if usb device got reset from the host
    reg [6:0] usb_address;
    reg [1:0] handshake = 2'b00;
    wire [7:0] data_in;
    reg data_in_valid = 0;
    reg [7:0] uart_counter = 0;
    reg [6:0] bytes_out_counter = 0;
    reg data_strobe_loc = 0;
    reg transaction_loc = 0;
    reg setup_toggle = 0;

    reg from_descriptor = 0;
    wire [3:0] endpoint ;
    wire direction_in;
    wire setup;
    assign usb_dp = usb_tx_en? (usb_tx_se0? 1'b0: usb_tx_j): 1'bz;
    assign usb_dn = usb_tx_en? (usb_tx_se0? 1'b0: !usb_tx_j): 1'bz;
    localparam
        hs_ack = 2'b00,
        hs_none = 2'b01,
        hs_nak = 2'b10,
        hs_stall = 2'b11;
    localparam
        st_idle = 0,
        st_get_setup_data = 1,
        st_get_data = 2,
        st_send_data = 3;


    reg [1:0] status = st_idle;
    wire [7:0] data_out;
    wire uart1_tx_dv;
    reg [7:0]uart_tx1_data;
    always @* begin
        uart_tx1_data = (direction_in) ? data_in : data_out;
    end



    wire usb_recv_queue_w_clk;
    wire usb_recv_queue_empty;
    wire [7:0]usb_recv_queue_data_out;
    reg  usb_recv_queue_r_clk ;
    wire usb_recv_queue_r_en;
    always @* begin
        usb_recv_queue_r_clk = (usb_recv_queue_r_en)? clk : 1'b0;
    end
    assign usb_recv_queue_w_clk = (direction_in) ?  1'b0 : data_strobe_loc;

    queue usb_recv_queue ( .r_clk(usb_recv_queue_r_clk), .data_out(usb_recv_queue_data_out), .w_clk(usb_recv_queue_w_clk), .data_in(data_out), .empty(usb_recv_queue_empty), .full(), .rst(rst));
    buffered_uart_tx uart_tx1 ( .uart_tx(uart_tx), .clk(clk), .data(uart_tx1_data), .data_valid(data_strobe), .full(), .rst(rst));

    wire usb_send_queue_r_clk;
    reg usb_send_queue_w_clk;
    wire usb_send_queue_w_en;
    wire usb_send_queue_empty;
    wire [7:0]usb_send_queue_data_in;
    reg write_first_byte = 0;
    assign usb_send_queue_r_clk = (direction_in) ? (data_strobe_loc  | write_first_byte): 1'b0;
    always @* begin
        usb_send_queue_w_clk = (usb_send_queue_w_en)? clk : 1'b0;
    end

   


    wire setup_data_ready;
    wire setup_data_toggle;
    wire [6:0] usb_addr_temp;
    reg control_transaction_finished = 1'b1;
    usb_setup usb_setup1(
        .rst(rst), 
        .usb_rst(usb_rst), 
        .clk(clk), 
        .status(status), 
        .setup_data_ready(setup_data_ready), 
        .setup_data_toggle(setup_data_toggle), 
        .usb_recv_queue_r_en(usb_recv_queue_r_en), 
        .transaction_active(transaction_active), 
        .usb_recv_queue_data_out(usb_recv_queue_data_out), 
        .usb_recv_queue_empty(usb_recv_queue_empty), 
        .usb_send_queue_w_en(usb_send_queue_w_en), 
        .usb_send_queue_data_in(usb_send_queue_data_in), 
        .usb_send_queue_empty(usb_send_queue_empty), 
        .control_transaction_finished(control_transaction_finished), 
        .usb_addr_temp(usb_addr_temp)
    );

    always @(posedge clk) begin
        if (!usb_tx_en) begin
            usb_dp_sync <= 1'b1 ? usb_dp : 1'bz;
            usb_dn_sync <=  1'b1 ? usb_dn : 1'bz;
        end
    end

    usb usb0( .rst_n(rst),
              .usb_address(usb_address),
              .usb_rst(usb_rst),
              .endpoint(endpoint),
              .transaction_active(transaction_active),
              .direction_in(direction_in),
              .setup(setup),
              .data_toggle(data_toggle),
              .handshake(handshake),
              .data_in(data_in),
              .data_in_valid(data_in_valid),
              .data_strobe(data_strobe),
              .success(success),
              .data_out(data_out),

              .clk_48(clk),
              .rx_j(usb_dp_sync),
              .rx_se0(!usb_dp_sync && !usb_dn_sync),

              .tx_se0(usb_tx_se0),
              .tx_j(usb_tx_j),
              .tx_en(usb_tx_en)
            );
    ///// setup recv
    queue usb_send_queue (.r_clk(usb_send_queue_r_clk), .data_out(data_in), .w_clk(usb_send_queue_w_clk), .data_in(usb_send_queue_data_in), .empty(usb_send_queue_empty), .full(), .rst(rst));
    ////// /setup recv
    always @(posedge clk) begin

        data_strobe_loc <= data_strobe;
        transaction_loc <= transaction_active;
    end
    
    reg [7:0]counter = 0;
    reg write_last_byte = 0;
    always @(posedge clk) begin
        data_toggle <= setup_data_toggle;
        case (status)
            st_idle: begin
                data_in_valid <= 0;
                if (transaction_active) begin
                    counter <= 0;
                    if (~setup_data_ready) begin
                        status <= st_get_setup_data;
                    end
                    else if (direction_in) begin
                        status <= st_send_data;
                    end
                    else begin
                        status <= st_get_data;
                    end
                end
            end
            st_get_setup_data: begin
                if (~transaction_active) begin
                    status <= st_idle;
                    control_transaction_finished <= 0;
                end
            end
            st_send_data: begin
                write_first_byte <= 1'b0; // TODO fix me
                if (!usb_send_queue_empty)begin
                    if (!write_first_byte && !data_in_valid ) begin
                        write_first_byte <= 1'b1;
                        data_in_valid <= 1'b1;
                    end
                end
                else if (!write_last_byte && data_strobe_loc) begin  // TODO: Fix ME
                    write_last_byte <= 1'b1;
                end
                else if (data_in_valid &&  data_strobe_loc) begin
                    data_in_valid <= 1'b0;
                    write_last_byte <= 1'b0;
                end
                if (data_strobe_loc) begin
                    counter <= counter + 1'b1;
                end
                if (~transaction_active) begin
                    status <= st_idle;
                    if (counter == 0) begin
                        control_transaction_finished <= 1'b1;
                        usb_address <= usb_addr_temp;
                    end
                end
            end
            st_get_data: begin
                if (data_strobe_loc) begin
                    counter <= counter + 1'b1;
                end
                if (~transaction_active) begin
                    status <= st_idle;
                    if (counter == 0) begin
                        control_transaction_finished <= 1;
                        usb_address <= usb_addr_temp;
                    end
                end
            end

        endcase
        if (!rst | usb_rst ) begin
            status <= st_idle;
            usb_address <= 0;
            data_toggle <= 0;
            setup_toggle <= 0;
            write_first_byte <= 0;
            counter <= 0;
            handshake <= hs_ack;
        end
    end

endmodule
