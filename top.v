`include "usbcorev/usb.v"


module top(
    input clk27mhz,
    inout usb_dp,
    inout usb_dn,
    input rst,
    output usb_dp_pull,
    output [4:0]ledrow,
    output clk_tst,
    output clk_tst1
);

wire clk48mhz;
wire clk_locked;

assign usb_dp_pull = rst;

pll48MHz_module usb_clk(
    .clk27mhz(clk27mhz),
    .clk48mhz(clk48mhz),
    .clk_locked(clk_locked)
);


initial begin
    
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

// reg uart_data_ready = 0;
// reg [7:0] uart_tx_tyte ;
// wire uart_tx_done;
// wire uart_busy;
// uart_tx  uart_tx_01(
//     .i_Clock(clk48mhz), 
//     .i_Tx_DV(uart_data_ready),
//     .i_Tx_Byte(uart_tx_tyte),
//     .o_Tx_Active(uart_busy),
//     .o_Tx_Serial(clk_tst1),
//     .o_Tx_Done(uart_tx_done)

// );

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
reg start_trans_probe = 1;
assign clk_tst = start_trans_probe;
assign clk_tst1 = data_toggle;
localparam 
    st_idle = 0,
    st_setup_get_status = 1,
    st_data = 2,
    st_data_finish = 3,
    st_data_out = 4,
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

    case (status)
        st_idle: begin 
            
            if (transaction_active && !transaction_loc) begin
                status <= st_start_transaction;
                if (!direction_in) begin 
                    got_bytes <= 0;

                end
                else begin 
                    data_toggle <= 1;
                end

            end
            if (!transaction_active) begin
                data_toggle <= 0;
            end
        end
        st_start_transaction: begin
            if (usb_addr_temp >0 ) begin 
                usb_address <= usb_addr_temp;
                usb_addr_temp <= 0; 
            end 
            if (!direction_in) begin // direction_in means direction in host, so this branch for receive
                if (success) begin 
                    status <= st_success_transaction;
                end 
                if (data_strobe && !data_strobe_loc) begin 
                        
                        got_bytes <= got_bytes + 1 ;
                        bytes_in[got_bytes] <= data_out;
                end
        
            end
            else begin
                if (success) begin 
                    status <= st_success_transaction;
                end 
                if (bytes_counter <= expected_bytes) begin
                    if ( bytes_counter == 0 || (data_strobe && !data_strobe_loc)) begin
                        data_toggle <= 1'b1;
                        data_in_valid <= 1'b1;
                        data_in <= bytes_in[bytes_counter];
                        bytes_counter <= bytes_counter + 1;
                    end
                end else begin
                    status <= st_success_transaction;
                    data_in_valid <= 1'b0;
                    
                end

            end

        end
        st_success_transaction: begin
            start_trans_probe <= 0;
            if (setup && got_bytes > 0) begin
                case (bytes_in[1])
                    8'h05: begin //set address
                        r_ledrow[1] <= 1; 
                        usb_addr_temp <= bytes_in[2][6:0];
                    end 
                    8'h06: begin // get  descriptor
                        case (bytes_in[3])
                            8'h01: begin //get device descriptor
                                
                                start_trans_probe <= 1;
                                bytes_in[0] <= 8'h12; 
                                bytes_in[1] <= 8'h01; 
                                bytes_in[2] <= 8'h00; 
                                bytes_in[3] <= 8'h02; 
                                bytes_in[4] <= 8'hff; 
                                bytes_in[5] <= 8'hff; 
                                bytes_in[6] <= 8'hff; 
                                bytes_in[7] <= 8'h40; 
                                bytes_in[8] <= 8'h05;
                                bytes_in[9] <= 8'h06;
                                bytes_in[10] <= 8'h07; 
                                bytes_in[11] <= 8'h08; 
                                bytes_in[12] <= 8'h02; 
                                bytes_in[13] <= 8'h00; 
                                bytes_in[14] <= 8'hAA; // iManufacturer 
                                bytes_in[15] <= 8'hAB; // iProduct
                                bytes_in[16] <= 8'hAC;  // 	iSerialNumber
                                bytes_in[17] <= 8'h01;  // num configurations
                                r_ledrow[0] <= 1;
                                bytes_counter <= 0;      
                                expected_bytes <= bytes_in[6]; 
                            end
                            8'h02: begin // get configuration descriptor
                                bytes_in[0] <= 8'h09; // length
                                bytes_in[1] <= 8'h02; // descriptor id 
                                bytes_in[2] <= 8'h09; // total length
                                bytes_in[3] <= 8'h00; // total length
                                bytes_in[4] <= 8'h01; // number of interfaces 
                                bytes_in[5] <= 8'hbc; // bConfigurationValue
                                bytes_in[6] <= 8'h00; //  iConfiguration	Index of String Descriptor describing this configuration
                                bytes_in[7] <= 8'b11000000; //bmAttributes  
                                bytes_in[8] <= 8'h09; // bMaxPower in units 2ma per unit
                                bytes_counter <= 0;
                                expected_bytes <= bytes_in[6];
                                r_ledrow[2] <= 1;
                            end
                        endcase

                    end
                    default: begin
                        start_trans_probe <= 0;
                    end 
                endcase
            end 

            status <= st_idle;
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
        handshake <= hs_ack; 
        data_toggle <= 0;
        start_trans_probe <= 0;
        got_bytes <= 0;

    end

    
end

endmodule