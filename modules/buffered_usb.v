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
    reg [7:0] bytes_counter = 0;
    reg [7:0] uart_counter = 0;
    reg [7:0] got_bytes = 0;
    reg [6:0] bytes_out_counter = 0;
    reg [7:0] bytes_in [0:128];
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
    reg [7:0] expected_bytes = 0;
    wire [7:0] data_out;
    wire uart1_tx_dv;
    reg [7:0]uart_tx1_data;
    always @* begin
        uart_tx1_data = (direction_in) ? data_in : data_out;
    end

    reg [7:0]config_offset = 0;
    reg [7:0] configuration [0:200];
    initial begin
        $readmemh("/home/dev/dev/fpga/usb_device/constants.txt", configuration );
    end

    wire usb_recv_queue_w_clk;
    wire usb_recv_queue_empty;
    wire [7:0]usb_recv_queue_data_out;
    reg  usb_recv_queue_r_clk ;
    reg usb_recv_queue_r_en = 1'b0;
    always @* begin
        usb_recv_queue_r_clk = (usb_recv_queue_r_en)? clk : 1'b0;
    end
    assign usb_recv_queue_w_clk = (direction_in) ?  1'b0 : data_strobe_loc;

    queue usb_recv_queue ( .r_clk(usb_recv_queue_r_clk), .data_out(usb_recv_queue_data_out), .w_clk(usb_recv_queue_w_clk), .data_in(data_out), .empty(usb_recv_queue_empty), .full(), .rst(rst));
    buffered_uart_tx uart_tx1 ( .uart_tx(uart_tx), .clk(clk), .data(uart_tx1_data), .data_valid(data_strobe), .full(), .rst(rst));

    wire usb_send_queue_r_clk;
    reg usb_send_queue_w_clk;
    reg usb_send_queue_w_en=0;
    wire usb_send_queue_empty;
    reg [7:0]usb_send_queue_data_in;
    reg write_first_byte = 0;
    assign usb_send_queue_r_clk = (direction_in) ? (data_strobe_loc  | write_first_byte): 1'b0;
    always @* begin
        usb_send_queue_w_clk = (usb_send_queue_w_en)? clk : 1'b0;
    end

    queue usb_send_queue (.r_clk(usb_send_queue_r_clk), .data_out(data_in), .w_clk(usb_send_queue_w_clk), .data_in(usb_send_queue_data_in), .empty(usb_send_queue_empty), .full(), .rst(rst));



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
    reg [6:0] usb_addr_temp = 0;
    reg setup_in = 0;
    reg [1:0]setup_handshake = hs_ack;
    reg setup_data_ready = 0;
    reg setup_data_toggle = 0;
    always @(posedge clk) begin
        if (!rst | usb_rst ) begin
            usb_recv_queue_r_en <= 1'b0;
            setup_in <= 0;
            usb_addr_temp <= 0;
            handshake <= hs_ack;
            setup_data_toggle <= 1'b0;
            got_bytes <= 0;
        end

        usb_send_queue_w_en <= 1'b0;
        case (status)
            st_idle: begin
                
                

                if (handshake != hs_ack)
                    handshake <= hs_ack;
                if (!setup_data_ready && !usb_recv_queue_empty) begin // collect setup data
                    usb_recv_queue_r_en <= 1'b1 ;
                    bytes_in[got_bytes] <= usb_recv_queue_data_out;
                    got_bytes <= got_bytes + 1'b1;
                        
                end
                else if (!setup_data_ready && got_bytes == 7 ) begin
                    setup_in <= bytes_in[0][7];
                    setup_response();
                    setup_data_ready <= 1'b1;
                    bytes_counter <= 8'h00;
                end
                if (bytes_counter < expected_bytes) begin
                    if (~usb_send_queue_w_en) begin
                        usb_send_queue_w_en <= 1'b1;
                    end
                    usb_send_queue_data_in <= configuration[config_offset+bytes_counter];
                    bytes_counter <= bytes_counter + 1'b1;

                end
            end
            st_get_setup_data: begin

            end
            st_get_data: begin
                //TODO: ? data toggle
            end
            st_send_data: begin
                if (usb_send_queue_empty) begin
                    setup_data_toggle <= 1'b1;
                end
                if (!transaction_active) begin
                    setup_data_toggle <= ~setup_data_toggle;
                end

            end
        endcase
        if (control_transaction_finished ) begin
            setup_data_ready <= 0;
            setup_data_toggle <= 1'b1;
            got_bytes <= 0;
        end
    end

    ////// /setup recv
    always @(posedge clk) begin

        data_strobe_loc <= data_strobe;
        transaction_loc <= transaction_active;
    end
    reg control_transaction_finished = 1'b1;
    reg [7:0]counter = 0;
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
                if (!usb_send_queue_empty)begin
                    if (!write_first_byte && !data_in_valid ) begin
                        write_first_byte <= 1'b1;
                        data_in_valid <= 1'b1;
                    end
                end
                else if (data_in_valid && usb_send_queue_empty && data_strobe_loc) begin
                    data_in_valid <= 1'b0;
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
        end
    end



    function automatic [15:0] get_descriptor_offset;
        input [7:0] descriptor_type;
        input [7:0] requested_offset;
        input [7:0] requested_size;

        begin
            setup_handshake = hs_ack;
            case (descriptor_type) //wValue [1]
                8'h01: begin //get device descriptor
                    get_descriptor_offset = {configuration[0], 8'h00};
                end
                8'h02: begin // get configuration descriptor
                    get_descriptor_offset = {requested_size, 8'd18};

                end
                8'h03: begin // string descriptors
                    get_descriptor_offset = string_offset(requested_offset);
                end
                default: begin
                    get_descriptor_offset = {8'h00, 8'h00};
                    // setup_handshake = hs_stall;
                end
            endcase
        end
    endfunction
    function automatic [15:0] string_offset;
        input [7:0] requested_offset;

        begin
            case (requested_offset) //wValue [0]
                8'h00:begin //string configuration
                    string_offset = {configuration[43], 8'd43};
                end
                8'haa:begin // manufacturer
                    string_offset = {configuration[47], 8'd47};
                end
                8'hab:begin // device name
                    string_offset = {configuration[73], 8'd73};
                end
                8'hac:begin // serial number
                    string_offset = {configuration[47], 8'd47};
                end
                8'had:begin // interface 0 str
                    string_offset = {configuration[101], 8'd101};
                end
                default:begin
                    string_offset = {8'd0, 8'd0};
                end
            endcase
        end
    endfunction
    task setup_response();
        begin

            case (bytes_in[1]) // bRequest
                8'h30: begin
                    expected_bytes <= 0;
                    from_descriptor <= 0;
                end
                8'h31: begin
                    expected_bytes <= bytes_in[6];
                    config_offset <= 47;
                    from_descriptor <= 0;
                end
                8'h00: begin // get status
                    config_offset <= 137;
                    expected_bytes <= 2;
                    from_descriptor <= 1;
                end
                8'h05: begin //set address

                    usb_addr_temp <= bytes_in[2][6:0];
                    expected_bytes <= 0;
                    from_descriptor <= 1;
                end
                8'h06: begin // get  descriptor
                    {expected_bytes, config_offset} <= get_descriptor_offset(bytes_in[03], bytes_in[02], bytes_in[6]);
                    from_descriptor <= 1;

                end
                default: begin
                    expected_bytes <= 0;
                    from_descriptor <= 1;
                end
            endcase
        end
    endtask

endmodule
