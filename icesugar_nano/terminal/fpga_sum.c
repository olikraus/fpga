#include <stdio.h>
#include <stdlib.h>
#include <stdint.h>
#include <string.h>
#include <fcntl.h>
#include <termios.h>
#include <unistd.h>

// Bitwise rotation and logic macros
#define ROTRIGHT(word, bits) (((word) >> (bits)) | ((word) << (32 - (bits))))
#define CH(x, y, z)  (((x) & (y)) ^ (~(x) & (z)))
#define MAJ(x, y, z) (((x) & (y)) ^ ((x) & (z)) ^ ((y) & (z)))
#define EP0(x)       (ROTRIGHT(x, 2) ^ ROTRIGHT(x, 13) ^ ROTRIGHT(x, 22))
#define SIG0(x)      (ROTRIGHT(x, 7) ^ ROTRIGHT(x, 18) ^ ((x) >> 3))
#define SIG1(x)      (ROTRIGHT(x, 17) ^ ROTRIGHT(x, 19) ^ ((x) >> 10))

// Serial communication functions
int serial_fd = -1;

void serial_init(const char *port) {
    serial_fd = open(port, O_RDWR | O_NOCTTY | O_SYNC);
    if (serial_fd < 0) {
        perror("Error opening serial port");
        exit(1);
    }
    tcflush(serial_fd, TCIOFLUSH); // Flush buffer
    struct termios tty;
    if (tcgetattr(serial_fd, &tty) != 0) {
        perror("Error from tcgetattr");
        exit(1);
    }
    cfsetospeed(&tty, B115200);
    cfsetispeed(&tty, B115200);
    tty.c_cflag = (tty.c_cflag & ~CSIZE) | CS8;
    tty.c_iflag &= ~IGNBRK;
    tty.c_lflag = 0;
    tty.c_oflag = 0;
    tty.c_cc[VMIN]  = 1;
    tty.c_cc[VTIME] = 5;
    tty.c_iflag &= ~(IXON | IXOFF | IXANY);
    tty.c_cflag |= (CLOCAL | CREAD);
    tty.c_cflag &= ~(PARENB | PARODD);
    tty.c_cflag &= ~CSTOPB;
    tty.c_cflag &= ~CRTSCTS;
    if (tcsetattr(serial_fd, TCSANOW, &tty) != 0) {
        perror("Error from tcsetattr");
        exit(1);
    }
    tcflush(serial_fd, TCIOFLUSH); // Flush again
    // Give FPGA time to settle
    usleep(100000);
}

void send_char(char c) {
    if (write(serial_fd, &c, 1) != 1) {
        perror("write error");
        exit(1);
    }
    char echo;
    if (read(serial_fd, &echo, 1) != 1) {
        perror("read error (echo)");
        exit(1);
    }
    if (echo != c) {
        printf("\nEcho mismatch! Sent '%c' (0x%02x), got '%c' (0x%02x)\n", c, c, echo, echo);
        exit(1);
    }
}

void send_cmd(const char *cmd) {
    for (int i = 0; cmd[i]; i++) {
        send_char(cmd[i]);
    }
    send_char('\r');
}

uint32_t read_reg() {
    send_cmd("r");
    char buf[10];
    int n = 0;
    while (n < 9) {
        int r = read(serial_fd, &buf[n], 9 - n);
        if (r > 0) n += r;
        else if (r < 0) { perror("read error"); exit(1); }
    }
    buf[8] = 0;
    return (uint32_t)strtoul(buf, NULL, 16);
}

void write_reg(uint32_t val) {
    char cmd[20];
    sprintf(cmd, "w %08x", val);
    send_cmd(cmd);
    uint32_t check = read_reg();
    if (check != val) {
        printf("\nWrite mismatch! Sent %08x, read back %08x\n", val, check);
        exit(1);
    }
}

uint32_t ep1_sw(uint32_t x) {
    return ROTRIGHT(x, 6) ^ ROTRIGHT(x, 11) ^ ROTRIGHT(x, 25);
}

uint32_t fpga_ep1(uint32_t x) {
    write_reg(x);
    send_cmd("e");
    uint32_t res = read_reg();
    uint32_t sw = ep1_sw(x);
    if (res != sw) {
        printf("\nEP1 Mismatch! Input: %08x, Hardware: %08x, Software: %08x\n", x, res, sw);
        exit(1);
    }
    return res;
}

#define EP1(x)       fpga_ep1(x)

// SHA-256 Round Constants
static const uint32_t k[64] = {
    0x428a2f98, 0x71374491, 0xb5c0fbcf, 0xe9b5dba5, 0x3956c25b, 0x59f111f1, 0x923f82a4, 0xab1c5ed5,
    0xd807aa98, 0x12835b01, 0x243185be, 0x550c7dc3, 0x72be5d74, 0x80deb1fe, 0x9bdc06a7, 0xc19bf174,
    0xe49b69c1, 0xefbe4786, 0x0fc19dc6, 0x240ca1cc, 0x2de92c6f, 0x4a7484aa, 0x5cb0a9dc, 0x76f988da,
    0x983e5152, 0xa831c66d, 0xb00327c8, 0xbf597fc7, 0xc6e00bf3, 0xd5a79147, 0x06ca6351, 0x14292967,
    0x27b70a85, 0x2e1b2138, 0x4d2c6dfc, 0x53380d13, 0x650a7354, 0x766a0abb, 0x81c2c92e, 0x92722c85,
    0xa2bfe8a1, 0xa81a664b, 0xc24b8b70, 0xc76c51a3, 0xd192e819, 0xd6990624, 0xf40e3585, 0x106aa070,
    0x19a4c116, 0x1e376c08, 0x2748774c, 0x34b0bcb5, 0x391c0cb3, 0x4ed8aa4a, 0x5b9cca4f, 0x682e6ff3,
    0x748f82ee, 0x78a5636f, 0x84c87814, 0x8cc70208, 0x90befffa, 0xa4506ceb, 0xbef9a3f7, 0xc67178f2
};

// SHA-256 Context Structure
typedef struct {
    uint32_t state[8];
    uint64_t datalen;
    uint8_t block[64];
    size_t blocklen;
} SHA256_CTX;

void sha256_transform(uint32_t state[8], const uint8_t data[64]) {
    uint32_t a, b, c, d, e, f, g, h, i, j, t1, t2, m[64];

    for (i = 0, j = 0; i < 16; ++i, j += 4) {
        m[i] = ((uint32_t)data[j] << 24) | ((uint32_t)data[j+1] << 16) |
               ((uint32_t)data[j+2] << 8)  | ((uint32_t)data[j+3]);
    }
    for (i = 16; i < 64; ++i) {
        m[i] = SIG1(m[i - 2]) + m[i - 7] + SIG0(m[i - 15]) + m[i - 16];
    }

    a = state[0]; b = state[1]; c = state[2]; d = state[3];
    e = state[4]; f = state[5]; g = state[6]; h = state[7];

    for (i = 0; i < 64; ++i) {
        t1 = h + EP1(e) + CH(e, f, g) + k[i] + m[i];
        t2 = EP0(a) + MAJ(a, b, c);
        h = g; g = f; f = e; e = d + t1;
        d = c; c = b; b = a; a = t1 + t2;
    }

    state[0] += a; state[1] += b; state[2] += c; state[3] += d;
    state[4] += e; state[5] += f; state[6] += g; state[7] += h;
}

void sha256_init(SHA256_CTX *ctx) {
    ctx->datalen = 0;
    ctx->blocklen = 0;
    ctx->state[0] = 0x6a09e667;
    ctx->state[1] = 0xbb67ae85;
    ctx->state[2] = 0x3c6ef372;
    ctx->state[3] = 0xa54ff53a;
    ctx->state[4] = 0x510e527f;
    ctx->state[5] = 0x9b05688c;
    ctx->state[6] = 0x1f83d9ab;
    ctx->state[7] = 0x5be0cd19;
}

void sha256_update(SHA256_CTX *ctx, const uint8_t *data, size_t len) {
    static int block_count = 0;
    for (size_t i = 0; i < len; ++i) {
        ctx->block[ctx->blocklen++] = data[i];
        if (ctx->blocklen == 64) {
            printf("Processing block %d...\r", ++block_count);
            fflush(stdout);
            sha256_transform(ctx->state, ctx->block);
            ctx->datalen += 512;
            ctx->blocklen = 0;
        }
    }
}

void sha256_final(SHA256_CTX *ctx, uint8_t hash[32]) {
    size_t i = ctx->blocklen;
    uint64_t total_bits = (ctx->datalen + (uint64_t)ctx->blocklen * 8);

    // Padding append bit '1'
    ctx->block[i++] = 0x80;

    // If no room for length, pad with zeros and transform
    if (i > 56) {
        memset(&ctx->block[i], 0, 64 - i);
        sha256_transform(ctx->state, ctx->block);
        i = 0;
        memset(ctx->block, 0, 56);
    } else {
        memset(&ctx->block[i], 0, 56 - i);
    }

    // Append total bit length in big-endian format
    for (int j = 7; j >= 0; --j) {
        ctx->block[56 + j] = (uint8_t)(total_bits & 0xff);
        total_bits >>= 8;
    }
    sha256_transform(ctx->state, ctx->block);

    // Produce final hash output bytes
    for (i = 0; i < 8; ++i) {
        hash[i * 4 + 0] = (ctx->state[i] >> 24) & 0xff;
        hash[i * 4 + 1] = (ctx->state[i] >> 16) & 0xff;
        hash[i * 4 + 2] = (ctx->state[i] >> 8) & 0xff;
        hash[i * 4 + 3] = (ctx->state[i]) & 0xff;
    }
}

int main(int argc, char **argv) {
    const char *port = "/dev/ttyACM0";
    if (argc > 1) port = argv[1];

    serial_init(port);

    // Hardcoded target file name
    const char *filename = "test_4k.b64";

    FILE *f = fopen(filename, "rb");
    if (!f) {
        perror("Error opening file");
        return 1;
    }

    SHA256_CTX ctx;
    sha256_init(&ctx);

    uint8_t buffer[1024];
    size_t bytesRead;
    while ((bytesRead = fread(buffer, 1, sizeof(buffer), f)) != 0) {
        sha256_update(&ctx, buffer, bytesRead);
    }
    fclose(f);

    uint8_t hash[32];
    sha256_final(&ctx, hash);

    printf("\nDone.                                   \n");
    // Print hash matching standard sha256sum output layout
    for (int i = 0; i < 32; ++i) {
        printf("%02x", hash[i]);
    }
    printf("  %s\n", filename);

    if (serial_fd >= 0) close(serial_fd);

    return 0;
}
