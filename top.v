module top(
    input clk27mhz,
    inout usb_dp,
    inout usb_dn,
    input rst,
    output usb_dp_pull,
    output [4:0]ledrow,
    output probe1,
    output probe2, 
    output probe3,
    output uart,
    output [2:0]probe_code
);

wire clk48mhz;
wire clk_locked;


reg uart_dir=0;
reg [7:0] uart_data_in;
wire uart_busy;
wire uart_done;
uart_tx uart_tx0 (
    .i_Clock(clk48mhz),
    .i_Tx_DV(uart_dir),
    .i_Tx_Byte(uart_data_in),
    .o_Tx_Active(uart_busy),
    .o_Tx_Serial(uart),
    .o_Tx_Done(uart_done)
);

reg r_uart_done;
always @(posedge clk48mhz ) begin
    r_uart_done <= uart_done;
    if (uart_dir) uart_dir <= 0; 
    if (q_read_success) q_read_success <= 0;

    if (!q_empty && ~uart_busy) begin
        uart_data_in <= q_data_out;
        uart_dir <= 1;
        q_read_success <= 1;
    end
end

assign usb_dp_pull = rst;
wire q_empty;
reg [7:0] q_data_in = 8'h0;
wire [7:0] q_data_out;
reg q_read_success;
reg q_data_in_ready = 0;

queue queue1(
    .empty(q_empty),
    .data_in(q_data_in),
    .data_out(q_data_out),
    .read_success(q_read_success),
    .dir(q_data_in_ready),
    .clk(clk48mhz),
    .rst(rst)

);


pll48MHz_module usb_clk(
    .clk27mhz(clk27mhz),
    .clk48mhz(clk48mhz),
    .clk_locked(clk_locked)
);

reg [7:0]config_offset = 0;
reg [7:0] configuration [0:200];
initial begin
   $readmemh("constants.txt", configuration ); 
end
reg [4:0]r_ledrow = 5'b00000;
assign ledrow = ~r_ledrow;

wire [6:0] usb_address;
reg[6:0] r_usb_address = 0;
assign usb_address = r_usb_address;
wire usb_rst; // set to 1 if usb device got reset from the host
wire [3:0] endpoint ;  
wire transaction_active;
wire direction_in;
wire setup;
reg data_toggle = 0;
reg [1:0] handshake = 2'b00;
reg [7:0] data_in = 8'h00;
wire [7:0] data_out;
reg data_in_valid = 0;
wire data_strobe;
wire success; // crc is valid
reg usb_dp_sync;
reg usb_dn_sync;

always @(posedge clk48mhz) begin
    if (!usb_tx_en) begin
        usb_dp_sync <= 1'b1 ? usb_dp : 1'bz;
        usb_dn_sync <=  1'b1 ? usb_dn : 1'bz;
    end

    
end

wire usb_tx_se0, usb_tx_j, usb_tx_en;
usb usb0(
    .rst_n(rst),
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

    .clk_48(clk48mhz),
    .rx_j(usb_dp_sync),
    .rx_se0(!usb_dp_sync && !usb_dn_sync),

    .tx_se0(usb_tx_se0),
    .tx_j(usb_tx_j),
    .tx_en(usb_tx_en)
);



assign usb_dp = usb_tx_en? (usb_tx_se0? 1'b0: usb_tx_j): 1'bz;
assign usb_dn = usb_tx_en? (usb_tx_se0? 1'b0: !usb_tx_j): 1'bz;

reg [7:0] bytes_counter = 0;
reg [7:0] uart_counter = 0;
reg [7:0] got_bytes = 0;
reg [6:0] bytes_out_counter = 0;
reg [7:0] bytes_in [0:128];
// assign r_probe_code[2] = direction_in;
// assign r_probe_code[1] =  setup;
// assign r_probe_code[0] = transaction_active;
assign {probe1, probe2, probe3} = status[2:0];


localparam 
    st_idle = 0,
    st_get_data_from_host = 1,
    st_prepare_response = 2,
    st_send_data = 3,
    st_setup = 5,

    st_do_nothing = 254;

reg [7:0] status = st_idle;
reg [7:0] expected_bytes = 0;

localparam
    hs_ack = 2'b00,
    hs_none = 2'b01,
    hs_nak = 2'b10,
    hs_stall = 2'b11;
reg data_strobe_loc = 0;
reg transaction_loc = 0;
reg [6:0] usb_addr_temp = 0;
reg endpoint02_data_out = 0;
reg endpoint00_data_in = 0;
reg endpoint00_data_out = 0;
localparam 
    setup_stage_idle=0,
    setup_stage_data=1,
    setup_stage_status=2;
reg [2:0] setup_stage =setup_stage_idle;

reg [2:0] r_probe_code = 0;
assign probe_code = r_probe_code;
reg setup_in = 0;
reg setup_toggle = 0;

// always @(posedge clk48mhz) begin
//     case(status)
//         st_idle: begin
//             if (transaction_active && !transaction_loc) begin
//                 if (setup) begin
//                     status <= st_get_setup_data;
//                 end
//             end
//         end
//         st_get_setup_data: begin
//             if (success) begin 
//                 status <= st_prepare_response;
//             end 
//             if (data_strobe && !data_strobe_loc) begin 
//                     got_bytes <= got_bytes + 1 ;
//                     bytes_in[got_bytes] <= data_out;
//             end 
//         end
//         get_data: begin
//         end
//         send_data: begin
//         end
//         check_status: begin
//         end

//     endcase
// end 
// function [16:0] descriptor_offset();

// endfunction
always @(posedge clk48mhz ) begin
    
    data_strobe_loc <= data_strobe;
    transaction_loc <= transaction_active;


    r_probe_code <= setup_stage;
    case (status)
    
        st_idle: begin 
            if (transaction_active && !transaction_loc) begin
                if (setup || setup_stage == setup_stage_data) begin
                    status <= st_setup;
                end
            end
            
        end
        st_setup: begin
            if (transaction_active) begin 
                case (setup_stage)
                    setup_stage_idle: begin
                        status <= st_get_data_from_host;
                        data_toggle <= 0;
                        got_bytes <= 0;
                        setup_toggle <= 0;
                    end
                    setup_stage_data: begin
                        
                        if (setup_in && direction_in) begin
                            if (expected_bytes > 0) begin
                                status <= st_send_data;
                                bytes_counter <= 0;
                                setup_toggle <= ~setup_toggle;
                            end
                        end 
                        else if (setup_in && ~direction_in) begin
                            setup_stage <= setup_stage_status;
                            data_toggle <= 1;
                        end
                        else if (~setup_in && direction_in) begin
                            setup_stage <= setup_stage_status;
                            data_toggle <= 1;
                        end
                    end
                endcase
            end 
            else if (setup_stage == setup_stage_status) begin
                setup_stage <= setup_stage_idle;
                status <= st_idle; 
                r_usb_address <= usb_addr_temp;
                
            end
            else begin
                if (handshake != hs_ack) handshake <= hs_ack;
                status <= st_idle; 
                setup_stage <= setup_stage_idle;
            end 

        end
        st_get_data_from_host: begin
            if (success) begin 
                status <= st_prepare_response;
            end 
            if (data_strobe && !data_strobe_loc) begin 
                    got_bytes <= got_bytes + 1'h01 ;
                    bytes_in[got_bytes] <= data_out;
            end
        end
        st_prepare_response: begin
            status <= st_idle;
            setup_stage <= setup_stage_data;
            setup_in <= bytes_in[0][7];
            case (bytes_in[1]) // bRequest
                8'h05: begin //set address
                    
                    usb_addr_temp <= bytes_in[2][6:0];
                    expected_bytes <= 0;
                end 
                8'h06: begin // get  descriptor
                    case (bytes_in[3]) //wValue [1] 
                        8'h01: begin //get device descriptor
                            config_offset <= 0; 
                            expected_bytes <= bytes_in[6]; 
                        end
                        8'h02: begin // get configuration descriptor
                            config_offset <= 18; 
                            
                            expected_bytes <= bytes_in[6];
                        end
                        8'h03: begin
                            case (bytes_in[2]) //wValue [0] 
                                8'h00: begin //string configuration 
                                    config_offset <= 43;
                                    expected_bytes <= 4; 
                                end
                                8'haa: begin // manufacturer
                                    config_offset <= 47;
                                    expected_bytes <= 26; 
                                end
                                8'hab: begin // device name
                                    config_offset <= 73;
                                    expected_bytes <= 28; 
                                end
                                8'hac: begin // serial number
                                    config_offset <= 47;
                                    expected_bytes <= 26; 
                                end
                                8'had: begin // interface 0 str
                                    config_offset <= 101;
                                    expected_bytes <= 36; 
                                end
                                default: begin
                                    expected_bytes <= 0;
                                end
                            endcase
                        end
                        default: begin
                            expected_bytes <= 0;
                            handshake <= hs_stall;
                        end
                    endcase

                end
                default: begin
                    expected_bytes <= 0;
                end 
            endcase
        end 

        st_send_data: begin
            data_toggle <= setup_toggle;
            if (transaction_active) begin
                if (success) begin 
                    status <= st_idle;
                end 
                if (bytes_counter <= expected_bytes) begin
                    if ( bytes_counter == 0 || (data_strobe && !data_strobe_loc)) begin
                        data_in_valid <= 1'b1;
                        data_in <= configuration[config_offset + bytes_counter[6:0]];
                        bytes_counter <= bytes_counter + 1'b1;
                    end
                end else begin
                    data_in_valid <= 1'b0; 
                end
            end
            else begin
                status <= st_idle;
            end
        end 

    endcase
        
    if (!rst || usb_rst) begin
        // r_ledrow <= 5'b0; 
        r_ledrow <= 5'b00000; 
        uart_counter <= 0;
        bytes_out_counter <= 0;
        status <= st_idle;
        r_usb_address <= 0; 
        usb_addr_temp <= 0;
        handshake <= hs_ack; 
        data_toggle <= 0;
        got_bytes <= 0;
        endpoint02_data_out <= 0;
        endpoint00_data_in <= 0;
        endpoint00_data_out <= 0;
        setup_stage <= setup_stage_idle;
        setup_in <= 0;
        setup_toggle <= 0;


    end

    
end

endmodule