module top (
    // Microphone clocks
    output logic mic_bclk,
    output logic mic_lrclk,

    // Microphone data
    input logic micA_dout,
    input logic micB_dout,
    input logic micC_dout,

    // 8 LEDs for Compass (N, NE, E, SE, S, SW, W, NW)
    output logic led_N,
    output logic led_NE,
    output logic led_E,
    output logic led_SE,
    output logic led_S,
    output logic led_SW,
    output logic led_W,
    output logic led_NW
);

    // Clock Generation
    logic clk;
    // Had to keep cutting down on clock's frequency due to hardware constrainst
    SB_HFOSC #(
        .CLKHF_DIV("0b10")
    )
    osc (
        .CLKHFPU(1'b1),
        .CLKHFEN(1'b1),
        .CLKHF(clk)
    );

    // I2S Clock Generation for Microphones
    cgen cgen (
        .clk(clk),
        .bclk(mic_bclk),
        .lrclk(mic_lrclk)
    );

    // Audio Data Reception
    logic signed [15:0] audio_A, audio_B, audio_C;
    logic vA, vB, vC; 

    // SYNC LOGIC FIX (Latching the valid signals)
    logic sync_A, sync_B, sync_C;
    logic sample_sync; 

    always_ff @(posedge clk) begin
        // Capture valid flags as they arrive
        if (vA) sync_A <= 1'b1;
        if (vB) sync_B <= 1'b1;
        if (vC) sync_C <= 1'b1;

        // When all 3 are present, fire sync and clear flags
        if (sync_A && sync_B && sync_C) begin
            sample_sync <= 1'b1;
            sync_A <= 0;
            sync_B <= 0;
            sync_C <= 0;
        end else begin
            sample_sync <= 1'b0;
        end
    end

    // Compute time delays
    logic signed [5:0] dAB, dAC;
    logic vAB, vAC;

    tdoa_stream tdoa_AB (.clk(clk), .sample_valid(sample_sync), .mic_A_in(audio_A), .mic_B_in(audio_B), .delay_out(dAB), .result_ready(vAB));
    tdoa_stream tdoa_AC (.clk(clk), .sample_valid(sample_sync), .mic_A_in(audio_A), .mic_B_in(audio_C), .delay_out(dAC), .result_ready(vAC));

    // I2S Receivers
    i2s_mic_rx rx_A (.clk(clk), .bclk(mic_bclk), .lrclk(mic_lrclk), .data_pin(micA_dout), .expect_left(1'b1), .audio_out(audio_A), .sample_valid(vA));
    i2s_mic_rx rx_B (.clk(clk), .bclk(mic_bclk), .lrclk(mic_lrclk), .data_pin(micB_dout), .expect_left(1'b0), .audio_out(audio_B), .sample_valid(vB));
    i2s_mic_rx rx_C (.clk(clk), .bclk(mic_bclk), .lrclk(mic_lrclk), .data_pin(micC_dout), .expect_left(1'b1), .audio_out(audio_C), .sample_valid(vC));

    // TDOA Result Latching
    logic signed [5:0] dAB_latched;
    logic signed [5:0] dAC_latched;
    logic have_AB, have_AC;
    logic trigger_solver;

    always_ff @(posedge clk) begin
        if (vAB) begin
            dAB_latched <= dAB;
            have_AB <= 1;
        end
        if (vAC) begin
            dAC_latched <= dAC;
            have_AC <= 1;
        end

        trigger_solver <= 0;
        if (have_AB && have_AC) begin
            trigger_solver <= 1;
            have_AB <= 0;
            have_AC <= 0;
        end
    end

    // Compass Solver
    logic [7:0] compass_out;
    compass_solver solver (
        .clk(clk),
        .trigger(trigger_solver),
        .dAB(dAB_latched),
        .dAC(dAC_latched),
        .leds(compass_out)
    );

    // Map LEDs
    assign {led_NW, led_W, led_SW, led_S, led_SE, led_E, led_NE, led_N} = compass_out;

endmodule