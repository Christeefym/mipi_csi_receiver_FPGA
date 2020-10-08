`timescale 1ns/1ns


module byte_aligner_reset_generator(clk_i,
									reset_i,
									aligner_reset_o);
input clk_i;
input reset_i;
output reg aligner_reset_o;

reg [3:0]clk_count;

always @(negedge clk_i)
begin
	if (reset_i)
	begin
		aligner_reset_o <= 1;
		clk_count  <=4'h0;
	end
	else
	begin
		clk_count <= clk_count + 1'b1;
		
		if (clk_count == 4'd4)
		begin
			aligner_reset_o <= 1'b0;
		end

	end
end

endmodule