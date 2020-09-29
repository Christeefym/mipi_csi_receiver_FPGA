`timescale 1ns/1ns

/*
MIPI CSI RX to Parallel Bridge (c) by Gaurav Singh www.CircuitValley.com

MIPI CSI RX to Parallel Bridge is licensed under a
Creative Commons Attribution 3.0 Unported License.

You should have received a copy of the license along with this
work.  If not, see <http://creativecommons.org/licenses/by/3.0/>.
*/

/*
Receives 4 lane raw mipi bytes from packet decoder, rearrange bytes to output 4 pixel either 10bit each  or 12bit each
output is one clock cycle delayed, because the way , MIPI RAW10 and RAW12 are packed 
for raw10 output comes in group of 5x48bit chunks , output_valid_o remains active only while 20 pixel chunk is outputted
for raw12 output comes in group of 2x48bit chunks 
*/

module mipi_rx_raw_depacker(	clk_i,
								data_valid_i,
								data_i,
								packet_type_i,
								output_valid_o,
								output_o);

localparam [7:0]MIPI_CSI_PACKET_10bRAW = 8'h2B;
localparam [7:0]MIPI_CSI_PACKET_12bRAW = 8'h2C;

input clk_i;
input data_valid_i;
input [31:0]data_i;
input [2:0]packet_type_i;

output reg output_valid_o;
output reg [47:0]output_o; 

reg [7:0]offset;

reg [7:0]offset_7;
reg [7:0]offset_15;
reg [7:0]offset_23;
reg [7:0]offset_31;
reg [7:0]offset_33;
reg [7:0]offset_35;
reg [7:0]offset_37;
reg [7:0]offset_39;
reg [7:0]offset_43;
reg [7:0]offset_47;

			
			
reg [2:0]byte_count;
reg [31:0]last_data_i[3:0];
reg [1:0]idle_count;

reg data_valid_reg;
reg [31:0]data_reg;
reg [7:0]offset_factor_reg;
reg [2:0]burst_length_reg;
reg [1:0]idle_length_reg;
reg [2:0]packet_type_reg;

wire [7:0]offset_factor;
wire [2:0]burst_length;
wire [1:0]idle_length;
wire [127:0]word;

reg [47:0]output_10b;
reg [47:0]output_12b;

reg output_valid_reg;
reg output_valid_reg_2;
				//{127 96}{95 64} {63 32} {31 0}
assign word = {last_data_i[0], last_data_i[1]}; 		//would need last bytes as well as current data to get full 4 pixel

assign offset_factor = (packet_type_i == (MIPI_CSI_PACKET_10bRAW & 8'h07))? 8'd8 : 8'd16;		
					   
assign burst_length =  (packet_type_i == (MIPI_CSI_PACKET_10bRAW & 8'h07))? 8'd5: 8'd3;		//10bit raw , 5 pixel per 4 clock + 1 clock idle, 12bit per pixel 2 pixel per 2 clock + 1 idle 
						
assign idle_length = 2'd1;

reg [15:0]pixel_counter_depacker;

always @(posedge clk_i)
begin
	output_10b[47:36] <= 	{word [(offset_7) -:8], 	word [(offset_39) -:2]} << 6; 		//lane 1 	TODO:Reverify 
	output_10b[35:24] <= 	{word [(offset_15) -:8], 	word [(offset_37) -:2]} << 6;		
	output_10b[23:12] <= 	{word [(offset_23) -:8], 	word [(offset_35) -:2]} << 6;
	output_10b[11:0]  <= 	{word [(offset_31) -:8], 	word [(offset_33) -:2]} << 6;		//lane 4
	
	output_12b[47:36] <= 	{word [(offset_7) -:8], 	word [(offset_47) -:4]} << 4; 		//lane 1
	output_12b[35:24] <= 	{word [(offset_15) -:8], 	word [(offset_43) -:4]} << 4;
	output_12b[23:12] <= 	{word [(offset_23) -:8], 	word [(offset_39) -:4]} << 4;
	output_12b[11:0]  <= 	{word [(offset_31) -:8], 	word [(offset_35) -:4]} << 4;		//lane 4
	
	
	if (packet_type_reg == (MIPI_CSI_PACKET_10bRAW & 8'h07))
	begin
		output_o <= output_10b;
	end
	else //or 12bRAW
	begin		
		output_o <= output_12b;
	end
	
end


always @(posedge clk_i)
begin
	

		
		if (output_valid_reg)
		begin
			offset_7  <= offset_7 + offset_factor_reg;
			offset_15 <= offset_15 + offset_factor_reg;
			offset_23 <= offset_23 + offset_factor_reg;
			offset_31 <= offset_31 + offset_factor_reg;
			offset_33 <= offset_33 + offset_factor_reg;
			offset_35 <= offset_35 + offset_factor_reg;
			offset_37 <= offset_37 + offset_factor_reg;
			offset_39 <= offset_39 + offset_factor_reg;
			offset_43 <= offset_43 + offset_factor_reg;
			offset_47 <= offset_47 + offset_factor_reg;
			
		end
		else
		begin
			offset_7  <= 8'd7;
			offset_15 <= 8'd15;
			offset_23 <= 8'd23;
			offset_31 <= 8'd31;
			offset_33 <= 8'd33;
			offset_35 <= 8'd35;
			offset_37 <= 8'd37;
			offset_39 <= 8'd39;
			offset_43 <= 8'd43;
			offset_47 <= 8'd47;
		end
end

always @(posedge clk_i )//or negedge data_valid_reg)
begin
	
	if (data_valid_reg)
	begin

		
		last_data_i[0] <= data_reg;
		last_data_i[1] <= last_data_i[0];

		pixel_counter_depacker <= pixel_counter_depacker + 1'b1;
		//RAW 10 , Byte1 -> Byte2 -> Byte3 -> Byte4 -> [ LSbB1[1:0] LSbB2[1:0] LSbB3[1:0] LSbB4[1:0] ]
		

		if (byte_count < (burst_length_reg))
		begin
			byte_count <= byte_count + 1'd1;
			idle_count <= idle_length_reg - 1'b1;			
			
			output_valid_reg <= 1'b1;
			
		end
		else
		begin
			idle_count <= idle_count - 1'b1;
			if (!idle_count)
			begin
				byte_count <= 4'b1;		//set to 1 to enable output_valid_o with next edge
			end

			output_valid_reg <= 1'h0;
		end


	end
	else
	begin
		pixel_counter_depacker <= 0; 
		last_data_i[0] <= 32'h0;
		last_data_i[1] <= 32'h0;
		last_data_i[2] <= 32'h0;
		last_data_i[3] <= 32'h0;

		
		byte_count <= 3'b0; 

		idle_count <= 3'b0;	//need to be zero to wait for 1 sample after data become valid	

		
		output_valid_reg <= 1'h0;
		offset_factor_reg <= offset_factor;
		burst_length_reg <= burst_length;
		idle_length_reg <= idle_length;
		packet_type_reg <= packet_type_i;
	end
end

always @(posedge clk_i)
begin
		data_valid_reg <= data_valid_i;
		output_valid_reg_2 <= output_valid_reg;
		output_valid_o <= output_valid_reg_2;
		
		data_reg <= data_i;

end
endmodule
