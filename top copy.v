`include "usbcorev/usb.v"
`include "rpll.v"
`include "uart_tx.v"
module pll48MHz_module (
    input clk27mhz,
    output clk48mhz,
    output clk_locked
);

Gowin_rPLL pll48mhz (
    .clkout(clk48mhz), 
    .clkin(clk27mhz), 
    .lock_o(clk_locked), 
    .reset(1'b0), 
    .reset_p(1'b0),
    .clkfb(1'b0), 
    .clkoutd_o(),
    .fdiv(6'b0), 
    .idiv(6'b0)
);
	defparam pll48mhz.DEVICE = "GW1NR-9";
	defparam pll48mhz.FCLKIN = "27";
	defparam pll48mhz.IDIV_SEL = 8;
	defparam pll48mhz.FBDIV_SEL = 15;
	defparam pll48mhz.ODIV_SEL = 16;
	defparam pll48mhz.DYN_FBDIV_SEL="false";
	defparam pll48mhz.DYN_IDIV_SEL="false";
	defparam pll48mhz.DYN_ODIV_SEL="false";
	defparam pll48mhz.DYN_SDIV_SEL=124;
	defparam pll48mhz.PSDA_SEL="0000";


endmodule

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
        usb_dp_sync <= usb_dp;
        usb_dn_sync <= usb_dn;
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
    .tx_en(usb_tx_en));

// reg [7:0] device_desc [0:17];
// assign device_desc[0] = 8'h12;
// assign device_desc[1] = 8'h01;
// assign device_desc[2] = 8'h02;
// assign device_desc[3] = 8'h00;
// assign device_desc[4] = 8'hff;
// assign device_desc[5] = 8'hff;
// assign device_desc[6] = 8'hff;
// assign device_desc[7] = 8'h40;
// assign device_desc[8] = 8'h05;
// assign device_desc[9] = 8'h06;
// assign device_desc[10] = 8'h07;
// assign device_desc[11] = 8'h08;
// assign device_desc[12] = 8'h02;
// assign device_desc[13] = 8'h00;
// assign device_desc[14] = 8'h01;
// assign device_desc[15] = 8'h02;
// assign device_desc[16] = 8'h03;
// assign device_desc[17] = 8'h01;

assign usb_dp = usb_tx_en? (usb_tx_se0? 1'b0: usb_tx_j): 1'bz;
assign usb_dn = usb_tx_en? (usb_tx_se0? 1'b0: !usb_tx_j): 1'bz;

reg [5:0] bytes_counter = 0;
reg [7:0] uart_counter = 0;
reg [6:0] bytes_out_counter = 0;
reg [7:0] bytes_in [0:63];
reg [7:0] bytes_out [0:63];
reg [6:0] bytes_out_number = 0;
assign clk_tst = data_strobe || success;
assign clk_tst1 = start_trans_probe;
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
reg [5:0] expected_bytes = 0;

localparam
    hs_ack = 2'b00,
    hs_none = 2'b01,
    hs_nak = 2'b10,
    hs_stall = 2'b11;
reg data_strobe_loc = 0;
reg transaction_loc = 0;
reg start_trans_probe = 0;
always @(posedge clk48mhz ) begin
    if (start_trans_probe == 1) begin 
        start_trans_probe <= 1'b0;
    end
    transaction_loc <= transaction_active;
    data_strobe_loc <= data_strobe;
    if (data_toggle) begin
        data_toggle <= 0;
    end
    // if (handshake == hs_ack) begin
    //     handshake <= hs_none;
    // end
    case (status)
        st_idle: begin 
            if (transaction_active && !transaction_loc) begin
                handshake <= hs_ack;
                // data_toggle <= 1'b1;
                status = st_start_transaction;
                bytes_counter <= 0;
            end
        end
        st_start_transaction: begin
            
            if (!direction_in) begin
                  
                if (success) begin 
                    status <= st_success_transaction;
                    start_trans_probe <= 1'b1;
                end 
                if (data_strobe && !data_strobe_loc) begin 
                       
                        bytes_counter <= bytes_counter + 1 ;
                        bytes_in[bytes_counter] <= data_out;
                    end
        
            end
            else begin
                if (bytes_counter < expected_bytes) begin
                    if (bytes_counter == 0 || (data_strobe && !data_strobe_loc)) begin
                        data_in <= bytes_in[0];
                        bytes_counter <= bytes_counter + 1;
                        data_toggle <= 1'b1;
                        data_in_valid = 1'b1;
                    end
                end else begin
                    status <= st_success_transaction;
                    data_in_valid = 1'b0;
                end

            end

        end
        st_success_transaction: begin
             
            handshake <= hs_ack;
            data_toggle = 1'b1;
            r_ledrow[0] <= 1;
            // if (setup && bytes_counter > 0 && bytes_in[1] == 8'h06) begin
            //     r_ledrow[0] <= 1;
            //     handshake <= hs_ack;
            //     
                
            //     // expected_bytes <= 18;
            //     // bytes_in[0:17] <= {8'h12, 8'h01, 8'h02, 8'h00, 8'hff, 8'hff, 8'hff, 8'h40, 8'h05, 8'h06, 8'h07, 8'h08, 8'h02, 8'h00, 8'h01, 8'h02, 8'h03, 8'h01}; 
                

            // end  
            // status <= st_idle;
        end
            
        default: begin
            status <= st_idle;

        end
    endcase
        
    if (!rst) begin
        r_ledrow <= 5'b00000; 
        uart_counter <= 0;
        bytes_out_counter <= 0;
        status <= st_idle;
        start_trans_probe <= 1'b0;
    end

    
end

endmodule