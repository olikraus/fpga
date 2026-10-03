#include <stdio.h>
#include <stdlib.h>
#include <stdint.h>
#include <string.h>
#include <fcntl.h>
#include <termios.h>
#include <unistd.h>

// Bitwise rotation and logic macros
#define ROTRIGHT(word, bits) (((word) >> (bits)) | ((word) << (32 - (bits))))

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

uint32_t ch_sw(uint32_t x, uint32_t y, uint32_t z) {
    return (x & y) ^ (~x & z);
}

uint32_t ep0_sw(uint32_t x) {
    return ROTRIGHT(x, 2) ^ ROTRIGHT(x, 13) ^ ROTRIGHT(x, 22);
}

uint32_t ep1_sw(uint32_t x) {
    return ROTRIGHT(x, 6) ^ ROTRIGHT(x, 11) ^ ROTRIGHT(x, 25);
}

uint32_t fpga_ep1(uint32_t x) {
    write_reg(x);
    send_cmd("s 4"); // Store to 'e'
    send_cmd("e");   // Trigger EP1
    send_cmd("l 4"); // Load from 'e'
    uint32_t res = read_reg();
    uint32_t sw = ep1_sw(x);
    if (res != sw) {
        printf("\nEP1 Mismatch! Input: %08x, Hardware: %08x, Software: %08x\n", x, res, sw);
        exit(1);
    }
    return res;
}

uint32_t fpga_ep0(uint32_t x) {
    write_reg(x);
    send_cmd("s 0"); // Store to 'a'
    send_cmd("d");   // Trigger EP0
    send_cmd("l 0"); // Load from 'a'
    uint32_t res = read_reg();
    uint32_t sw = ep0_sw(x);
    if (res != sw) {
        printf("\nEP0 Mismatch! Input: %08x, Hardware: %08x, Software: %08x\n", x, res, sw);
        exit(1);
    }
    return res;
}

uint32_t fpga_ch(uint32_t e, uint32_t f, uint32_t g) {
    write_reg(e); send_cmd("s 4");
    write_reg(f); send_cmd("s 5");
    write_reg(g); send_cmd("s 6");
    send_cmd("c");   // Trigger CH
    send_cmd("l 4"); // Load from 'e' (result)
    uint32_t res = read_reg();
    uint32_t sw = ch_sw(e, f, g);
    if (res != sw) {
        printf("\nCH Mismatch! Input: %08x, %08x, %08x, Hardware: %08x, Software: %08x\n", e, f, g, res, sw);
        exit(1);
    }
    return res;
}

#define EP0(x)       fpga_ep0(x)
#define EP1(x)       fpga_ep1(x)
#define CH(x, y, z)  fpga_ch(x, y, z)
#define MAJ(x, y, z) (((x) & (y)) ^ ((x) & (z)) ^ ((y) & (z)))
#define SIG0(x)      (ROTRIGHT(x, 7) ^ ROTRIGHT(x, 18) ^ ((x) >> 3))
#define SIG1(x)      (ROTRIGHT(x, 17) ^ ROTRIGHT(x, 19) ^ ((x) >> 10))

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

typedef struct {
    uint8_t  block[64];
    uint32_t state[8];
    uint64_t count;
} SHA256_CTX;

void sha256_transform(uint32_t state[8], const uint8_t data[64]) {
    uint32_t a, b, c, d, e, f, g, h, t1, t2, m[64];
    int i, j;

    for (i = 0, j = 0; i < 16; ++i, j += 4)
        m[i] = (data[j] << 24) | (data[j + 1] << 16) | (data[j + 2] << 8) | (data[j + 3]);
    for (; i < 64; ++i)
        m[i] = SIG1(m[i - 2]) + m[i - 7] + SIG0(m[i - 15]) + m[i - 16];

    a = state[0];
    b = state[1];
    c = state[2];
    d = state[3];
    e = state[4];
    f = state[5];
    g = state[6];
    h = state[7];

    for (i = 0; i < 64; ++i) {
        t1 = h + EP1(e) + CH(e, f, g) + k[i] + m[i];
        t2 = EP0(a) + MAJ(a, b, c);
        h = g;
        g = f;
        f = e;
        e = d + t1;
        d = c;
        c = b;
        b = a;
        a = t1 + t2;
    }

    state[0] += a;
    state[1] += b;
    state[2] += c;
    state[3] += d;
    state[4] += e;
    state[5] += f;
    state[6] += g;
    state[7] += h;
}

void sha256_init(SHA256_CTX *ctx) {
    ctx->state[0] = 0x6a09e667;
    ctx->state[1] = 0xbb67ae85;
    ctx->state[2] = 0x3c6ef372;
    ctx->state[3] = 0xa54ff53a;
    ctx->state[4] = 0x510e527f;
    ctx->state[5] = 0x9b05688c;
    ctx->state[6] = 0x1f83d9ab;
    ctx->state[7] = 0x5be0cd19;
    ctx->count = 0;
}

void sha256_update(SHA256_CTX *ctx, const uint8_t *data, size_t len) {
    uint32_t i;
    for (i = 0; i < len; ++i) {
        ctx->block[ctx->count & 63] = data[i];
        ctx->count++;
        if ((ctx->count & 63) == 0)
            sha256_transform(ctx->state, ctx->block);
    }
}

void sha256_final(SHA256_CTX *ctx, uint8_t hash[32]) {
    uint64_t i = ctx->count;
    uint8_t pad = 0x80;
    sha256_update(ctx, &pad, 1);
    while ((ctx->count & 63) != 56) {
        pad = 0x00;
        sha256_update(ctx, &pad, 1);
    }
    i <<= 3;
    for (int j = 0; j < 8; j++) {
        uint8_t b = (i >> (56 - j * 8)) & 0xFF;
        sha256_update(ctx, &b, 1);
    }
    for (int j = 0; j < 8; j++) {
        hash[j * 4]     = (ctx->state[j] >> 24) & 0xFF;
        hash[j * 4 + 1] = (ctx->state[j] >> 16) & 0xFF;
        hash[j * 4 + 2] = (ctx->state[j] >> 8) & 0xFF;
        hash[j * 4 + 3] = (ctx->state[j]) & 0xFF;
    }
}

int main(int argc, char *argv[]) {
    const char *port = "/dev/ttyACM0";
    if (argc > 1) port = argv[1];

    serial_init(port);

    printf("Verifying FPGA Primitives...\n");
    EP0(0x12345678);
    printf("EP0 OK\n");
    EP1(0x87654321);
    printf("EP1 OK\n");
    CH(0x12345678, 0x9ABCDEF0, 0x0FEDCBA9);
    printf("CH OK\n");

    // Hardcoded target file name
    const char *filename = "test_4k.b64";

    FILE *f = fopen(filename, "rb");
    if (!f) {
        perror("Error opening file");
        return 1;
    }

    uint8_t buffer[64];
    uint8_t hash[32];
    size_t bytesRead;
    SHA256_CTX ctx;
    sha256_init(&ctx);

    while ((bytesRead = fread(buffer, 1, sizeof(buffer), f)) > 0) {
        sha256_update(&ctx, buffer, bytesRead);
        printf("\rProcessing block %lu...", (unsigned long)(ctx.count / 64));
        fflush(stdout);
    }
    fclose(f);

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
