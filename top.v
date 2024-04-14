`include "usbcorev/usb.v"


module top(
    input clk27mhz,
    inout usb_dp,
    inout usb_dn,
    input rst,
    output usb_dp_pull,
    output [4:0]ledrow,
    output clk_tst,
    output clk_tst1, 
    output probe_3
);

wire clk48mhz;
wire clk_locked;

assign usb_dp_pull = rst;

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

reg [6:0] usb_address;
wire usb_rst; // set to 1 if usb device got reset from the host
reg[3:0] endpoint;  
reg transaction_active;
reg direction_in;
reg setup;
reg data_toggle;
reg [1:0] handshake;
reg [7:0] data_in;
reg [7:0] data_out;
reg data_in_valid;
reg data_strobe;
reg success; // crc is valid
reg usb_dp_sync;
reg usb_dn_sync;

always @(posedge clk48mhz) begin
    if (!usb_tx_en) begin
        usb_dp_sync <= 1'b1 ? usb_dp : 1'bz;
        usb_dn_sync <=  1'b1 ? usb_dn : 1'bz;;
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
// assign clk_tst = transaction_active ;
// assign clk_tst1 = data_in_valid;
// assign probe_3 = data_toggle ;
reg [2:0] control_point;
assign {clk_tst, clk_tst1, probe_3} = control_point;


localparam 
    st_idle = 0,
    st_get_data_from_host = 1,
    st_prepare_response = 2,
    st_send_data = 3,
    st_wait_host = 4,
    st_data_out_finish = 5,
    st_start_transaction = 6,
    st_success_transaction = 7,
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
always @(posedge clk48mhz ) begin
    data_strobe_loc <= data_strobe;
    transaction_loc <= transaction_active;
    if (control_point>0) control_point = 0;

    case (status)
        st_idle: begin 
            if (transaction_active && !transaction_loc) begin
                status <= st_get_data_from_host;
                // got_bytes <= 0;
            end
        end

        st_get_data_from_host: begin
            if (success) begin 
                status <= st_prepare_response;
            end 
            if (data_strobe && !data_strobe_loc) begin 
                    
                    got_bytes <= got_bytes + 1 ;
                    bytes_in[got_bytes] <= data_out;
            end

        end
        st_prepare_response: begin
            if (setup && got_bytes >= 7 && !direction_in) begin
                    control_point <= 1; 
                case (bytes_in[1])
                    8'h05: begin //set address
                        r_ledrow[1] <= 1; 
                        usb_addr_temp <= bytes_in[2][6:0];
                        expected_bytes <= 0;
                        // bytes_counter <= 0;
                        control_point <= 2;
                    end 
                    8'h06: begin // get  descriptor
                       control_point <= 3; 
                        case (bytes_in[3])
                            8'h01: begin //get device descriptor
                                config_offset <= 0; 
                                r_ledrow[0] <= 1;
                                bytes_counter <= 0;      
                                expected_bytes <= bytes_in[6]; 
                            end
                            8'h02: begin // get configuration descriptor
                                config_offset <= 18; 
                                bytes_counter <= 0;
                                r_ledrow[2] <= 1;
                                expected_bytes <= bytes_in[6];
                            end
                            8'h03: begin
                                case (bytes_in[2])
                                    8'h00: begin
                                        config_offset <= 36;
                                        bytes_counter <= 0;
                                        expected_bytes <= 4; 
                                    end
                                    8'haa: begin // manufacturer
                                        config_offset <= 40;
                                        bytes_counter <= 0;
                                        expected_bytes <= 26; 
                                    end
                                    8'hab: begin // device name
                                        config_offset <= 66;
                                        bytes_counter <= 0;
                                        expected_bytes <= 28; 
                                    end
                                    8'hac: begin // serial number
                                        config_offset <= 40;
                                        bytes_counter <= 0;
                                        expected_bytes <= 26; 
                                    end
                                    8'had: begin // serial number
                                        config_offset <= 94;
                                        bytes_counter <= 0;
                                        expected_bytes <= 36; 
                                    end
                                    default: begin
                                        expected_bytes <= 0;
                                    end
                                endcase
                            end
                            default: begin
                                expected_bytes <= 0;
                            end
                        endcase

                    end
                    default: begin
                        expected_bytes <= 0;
                        
                    end 
                endcase
            end 
            else begin
            end

            status <= st_send_data;
        end
        st_send_data: begin
            if (direction_in) begin
                data_toggle <= 1;
            end

            if (success) begin 
                status <= st_wait_host;
                data_in_valid <= 1'b0;
            end 
            if (bytes_counter <= expected_bytes) begin
                if ( bytes_counter == 0 || (data_strobe && !data_strobe_loc)) begin
                    data_in_valid <= 1'b1;
                    data_in <= configuration[config_offset + bytes_counter[6:0]];
                    bytes_counter <= bytes_counter + 1;
                end
            end else begin
                data_in_valid <= 1'b0; 
                // status <= st_wait_host;
            end
        end 
        st_wait_host: begin
            data_toggle <= 0;
            got_bytes <= 0;
            if (usb_address == 0 && usb_addr_temp > 0) usb_address <= usb_addr_temp;
            if (bytes_counter == 0 ) begin // nothing to wait for 
                status <= st_idle;
            end
            if (!transaction_active ) begin
                status <= st_idle;
            end

        end

        default: begin
            status <= st_idle;

        end
        
    endcase
        
    if (!rst || usb_rst) begin
        // r_ledrow <= 5'b0; 
        r_ledrow <= 5'b00000; 
        uart_counter <= 0;
        bytes_out_counter <= 0;
        status <= st_idle;
        usb_address <= 0; 
        usb_addr_temp <= 0;
        handshake <= hs_ack; 
        data_toggle <= 0;
        got_bytes <= 0;

    end

    
end

endmodule