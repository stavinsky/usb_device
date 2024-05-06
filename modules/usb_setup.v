module usb_setup(rst, clk, status, setup_data_ready, setup_data_toggle, usb_recv_queue_r_en, transaction_active, usb_recv_queue_data_out, usb_recv_queue_empty, usb_send_queue_w_en, usb_send_queue_data_in, usb_send_queue_empty, control_transaction_finished, usb_addr_temp);

    input rst ;
    input clk;
    input [1:0]status;
    input transaction_active;
    output setup_data_ready; // TODO: get rid of it
    output setup_data_toggle;
    output usb_recv_queue_r_en;
    input [7:0]usb_recv_queue_data_out;
    input usb_recv_queue_empty;
    output usb_send_queue_w_en;
    output [7:0]usb_send_queue_data_in;
    input usb_send_queue_empty;
    input control_transaction_finished;
    output [6:0] usb_addr_temp;
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


    reg [7:0] configuration [0:200];
    initial begin
        $readmemh("/home/dev/dev/fpga/usb_device/constants.txt", configuration );
    end
    reg [7:0]config_offset = 0;

    reg [7:0] expected_bytes = 0;
    reg [7:0] bytes_counter = 0;
    reg [7:0] bytes_in [0:128];
    reg [7:0] got_bytes = 0;

    reg [1:0]setup_handshake = hs_ack;
    reg setup_data_ready = 0;
    reg setup_data_toggle = 0;
    reg r_usb_recv_queue_r_en = 1'b0;
    assign usb_recv_queue_r_en = r_usb_recv_queue_r_en;
    reg r_usb_send_queue_w_en = 0;
    assign usb_send_queue_w_en = r_usb_send_queue_w_en;
    reg [7:0]r_usb_send_queue_data_in;
    assign usb_send_queue_data_in = r_usb_send_queue_data_in;
    reg [6:0]r_usb_addr_temp = 0;
    assign usb_addr_temp = r_usb_addr_temp;
    always @(posedge clk) begin
        if (rst ) begin
            r_usb_recv_queue_r_en <= 1'b0;
            r_usb_addr_temp <= 0;
            // handshake <= hs_ack;
            setup_data_toggle <= 1'b0;
            got_bytes <= 0;
            setup_data_ready <= 1'b0;
        end

        case (status)
            st_idle: begin
                if (setup_data_ready && transaction_active) begin
                    setup_data_toggle <= ~setup_data_toggle;
                end
                bytes_in[got_bytes] <= usb_recv_queue_data_out;
                if (!setup_data_ready && !usb_recv_queue_empty) begin // collect setup data
                    if (!r_usb_recv_queue_r_en) begin
                        r_usb_recv_queue_r_en <= 1'b1 ;
                    end
                    else begin
                        
                        got_bytes <= got_bytes + 1'b1;
                    end
                
                end
                else if (!setup_data_ready && got_bytes == 8 ) begin
                    // setup_in <= bytes_in[0][7];
                    setup_response();
                    setup_data_ready <= 1'b1;
                    bytes_counter <= 8'h00;
                    r_usb_recv_queue_r_en <= 1'b0;
                end
                if (bytes_counter < expected_bytes) begin
                    if (~r_usb_send_queue_w_en) begin
                        r_usb_send_queue_w_en <= 1'b1;
                    end
                    bytes_counter <= bytes_counter + 1'b1;
                    if (bytes_counter + 1'b1 == expected_bytes) begin
                    end

                end
                else if (bytes_counter >= expected_bytes) begin
                    
                        r_usb_send_queue_w_en <= 1'b0;
                end
                r_usb_send_queue_data_in <= configuration[config_offset+bytes_counter];
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

            end
        endcase
        if (control_transaction_finished ) begin
            setup_data_ready <= 0;
            setup_data_toggle <= 1'b0;
            got_bytes <= 0;
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
                end
                8'h31: begin
                    expected_bytes <= bytes_in[6];
                    config_offset <= 47;
                end
                8'h00: begin // get status
                    config_offset <= 137;
                    expected_bytes <= 2;
                end
                8'h05: begin //set address

                    r_usb_addr_temp <= bytes_in[2][6:0];
                    expected_bytes <= 0;
                end
                8'h06: begin // get  descriptor
                    {expected_bytes, config_offset} <= get_descriptor_offset(bytes_in[03], bytes_in[02], bytes_in[6]);

                end
                default: begin
                    expected_bytes <= 0;
                end
            endcase
        end
    endtask

endmodule
