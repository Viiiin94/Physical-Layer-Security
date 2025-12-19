`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 12/19/2025 03:59:33 PM
// Design Name: 
// Module Name: project_top
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: 
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////


module prototype_top(
    input clk,
    input reset_p,
    input [2:0] button, // push 버튼
    output[5:0] led_bar_out 
);

bar_led led_bar_module(
    clk,
    reset_p,
    button,   // push 버튼
    led_bar_out 
);

endmodule
