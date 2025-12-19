module i2s_mic_rx (
    input logic clk,
    input logic bclk,
    input logic lrclk,
    input logic data_pin, // input from mic
    input logic expect_left, // 0 for left, 1 for right channel (easiest alt. to duplicate module)

    output logic signed [15:0] audio_out, // Audio sample
    output logic sample_valid // high for 1 tick when new sample is ready
);

    // I2S Deserialization
    logic [5:0] bit_counter;
    logic [31:0] shift_reg;
    logic signed [23:0] raw_sample;

    // Deserializer FSM
    // Shifts in 32 bits of I2S data, extracts 24-bit sample (discards 8 LSBs)
    always_ff @(posedge bclk) begin
        // Check if in correct channel (lrclk polarity determines left/right)
        if (lrclk == ~expect_left) begin
            // Shift in new bit from microphone
            shift_reg <= {shift_reg[30:0], data_pin};
            bit_counter <= bit_counter + 1;

            if (bit_counter == 31) begin
                // Full 32-bit frame received, extract 24-bit sample
                raw_sample <= shift_reg[31:8]; // Discard first 8 bits (padding)
                sample_valid <= 1'b1;
                bit_counter <= 0;
            end else begin
                sample_valid <= 1'b0;
            end
        // Wrong channel - reset counters
        end else begin
            bit_counter <= 0;
            sample_valid <= 0;
        end
    end

    // DC Removal Filter
    // High-pass filter to remove DC bias that can be injected into the signal
    logic signed [23:0] dc_est; // DC estimate (running average)
    logic signed [23:0] sample_dc; // DC-removed sample

    always_ff @(posedge clk) begin
        if (sample_valid) begin
            // dc_est = dc_est + (raw_sample - dc_est) / 65536
            // This slowly tracks the DC component
            dc_est <= dc_est + ((raw_sample - dc_est) >>> 16);

            // Remove DC component from sample
            sample_dc <= raw_sample - dc_est;

            // Output 16 MSBs of 24-bit DC-removed sample
            audio_out <= sample_dc[23:8];
        end
    end
endmodule