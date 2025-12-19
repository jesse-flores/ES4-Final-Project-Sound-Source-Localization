module mic_level_pwm (
    input logic clk,
    input logic sample_valid,
    input logic signed [23:0] sample,
    output logic led
);

    // Audio Level Processing
    logic [23:0] abs_sample; // Absolute value of audio sample
    logic [15:0] level; // Current level (peak detector output)
    logic [7:0] pwm_cnt; // PWM counter (0-255)

    // Free-running counter for PWM generation
    always_ff @(posedge clk)
        pwm_cnt <= pwm_cnt + 1;

    always_ff @(posedge clk) begin
        if (sample_valid) begin
            // Compute absolute value
            abs_sample <= sample[23] ? -sample : sample;

            // Peak detector logic
            if (abs_sample[23:8] > level) begin
                // Immediately follow rising peaks
                level <= abs_sample[23:8];
            end else begin
                // Gadually decrease level
                level <= level - (level >> 4); // Divide by 16 decay
            end
            // 
        end
    end

    // PWM Output
    assign led = (pwm_cnt < level[15:8]);

endmodule