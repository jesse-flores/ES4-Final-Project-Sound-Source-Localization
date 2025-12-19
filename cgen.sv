module cgen (
    input logic clk, // 12 MHz
    output logic bclk, // 3 MHz
    output logic lrclk // 46.875 KHz
);

    // 10-bit counter
    logic [9:0] div;

    always_ff @(posedge clk) begin
        div <= div + 1;
    end

    assign bclk = div[1]; // divides clock by 4 (12MHz -> 3MHz)
    assign lrclk = div[7]; // divides clock by 256 (12MHz -> 46.875kHz)

endmodule