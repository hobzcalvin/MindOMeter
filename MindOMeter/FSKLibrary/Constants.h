#define FREQ_HIGH 8000
#define FREQ_LOW  4000

#define WL_HIGH (1000000000 / FREQ_HIGH)
#define WL_LOW  (1000000000 / FREQ_LOW)
#define HWL_HIGH (500000000 / FREQ_HIGH)
#define HWL_LOW  (500000000 / FREQ_LOW)

#define SMOOTHER_COUNT (FSK_SMOOTH * (FSK_SMOOTH + 1) / 2)

#define DISCRIMINATOR (SMOOTHER_COUNT * (WL_HIGH + WL_LOW) / 4)

#define BAUD  1300
#define BIT_PERIOD     (1000000000 / BAUD)
#define HALF_BIT_PERIOD (500000000 / BAUD)

#define SAMPLE_RATE  44100
#define SAMPLE  SInt16
#define SAMPLE_MAX  32767
#define NUM_CHANNELS  1

#define BITS_PER_CHANNEL (sizeof(SAMPLE) * 8)
#define BYTES_PER_FRAME  (NUM_CHANNELS * sizeof(SAMPLE))

#define SAMPLE_DURATION (1000000000 / SAMPLE_RATE)
#define SAMPLES_TO_NS(__samples__) (((UInt64)(__samples__) * 1000000000) / SAMPLE_RATE)
#define NS_TO_SAMPLES(__nanosec__) (unsigned)(((UInt64)(__nanosec__) * SAMPLE_RATE) / 1000000000)
#define US_TO_SAMPLES(__microsec__) (unsigned)(((UInt64)(__microsec__) * SAMPLE_RATE) / 1000000)
#define MS_TO_SAMPLES(__millisec__) (unsigned)(((UInt64)(__millisec__) * SAMPLE_RATE) / 1000)

#define SINE_TABLE_LENGTH 441

// TABLE_JUMP = phase_per_sample / phase_per_entry
// phase_per_sample = 2pi * time_per_sample / time_per_wave
// phase_per_entry = 2pi / SINE_TABLE_LENGTH
// TABLE_JUMP = time_per_sample / time_per_wave * SINE_TABLE_LENGTH
// time_per_sample = 1000000000 / SAMPLE_RATE
// time_per_wave = 1000000000 / FREQ
// TABLE_JUMP = FREQ / SAMPLE_RATE * SINE_TABLE_LENGTH
#define TABLE_JUMP_HIGH (FREQ_HIGH * SINE_TABLE_LENGTH / SAMPLE_RATE)
#define TABLE_JUMP_LOW  (FREQ_LOW  * SINE_TABLE_LENGTH / SAMPLE_RATE)
